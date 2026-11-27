#include "printing.h"

#include "shadow.h"

#include <KWindowShadow>

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QHash>
#include <QLocale>
#include <QMutex>
#include <QPainter>
#include <QPdfDocument>
#include <QPointer>
#include <QProcess>
#include <QQmlEngine>
#include <QQuickImageProvider>
#include <QQuickWindow>
#include <QThread>

#include <algorithm>
#include <cups/cups.h>
#include <sys/socket.h>

using namespace Qt::StringLiterals;

namespace
{
struct Paper {
    const char *name;
    const char *key; // PWG's name, which CUPS knows it by
    const char *note;
    int width, height; // hundredths of a millimetre
};
const Paper known[] = {
    {"US Letter", "na_letter_8.5x11in", "8.50 by 11.00 inches", 21590, 27940},
    {"US Legal", "na_legal_8.5x14in", "8.50 by 14.00 inches", 21590, 35560},
    {"A4", "iso_a4_210x297mm", "210 by 297 mm", 21000, 29700},
    {"A5", "iso_a5_148x210mm", "148 by 210 mm", 14800, 21000},
    {"A3", "iso_a3_297x420mm", "297 by 420 mm", 29700, 42000},
    {"JIS B5", "jis_b5_182x257mm", "182 by 257 mm", 18200, 25700},
    {"Tabloid", "na_ledger_11x17in", "11.00 by 17.00 inches", 27940, 43180},
    {"Envelope #10", "na_number-10_4.125x9.5in", "4.12 by 9.50 inches", 10477, 24130},
    {"Envelope DL", "iso_dl_110x220mm", "110 by 220 mm", 11000, 22000},
};

QVariantMap told(const Paper &paper)
{
    return {
        {u"key"_s, QLatin1String(paper.key)},
        {u"name"_s, QLatin1String(paper.name)},
        {u"note"_s, QLatin1String(paper.note)},
        {u"width"_s, paper.width * 72 / 2540.0},
        {u"height"_s, paper.height * 72 / 2540.0},
    };
}

// Is CUPS there to ask? (Its own calls wait half a minute on a server
// that isn't.)
bool answering()
{
    http_t *http = httpConnect2(cupsServer(), ippPort(), nullptr, AF_UNSPEC, cupsEncryption(), 1, 2000, nullptr);
    if (!http)
        return false;
    httpClose(http);
    return true;
}

// A printer by name with the connection to print through and what it can
// do. A printer found on the network and never added becomes a queue of
// CUPS's for the while, by the connecting.
struct Reached {
    cups_dest_t *dest = nullptr;
    http_t *http = nullptr;
    cups_dinfo_t *info = nullptr;

    explicit Reached(const QString &printer, int wait)
    {
        if (!answering())
            return;
        dest = cupsGetNamedDest(CUPS_HTTP_DEFAULT, printer.toUtf8().constData(), nullptr);
        if (!dest)
            return;
        char resource[256];
        http = cupsConnectDest(dest, CUPS_DEST_FLAGS_NONE, wait, nullptr, resource, sizeof(resource), nullptr, nullptr);
        if (http)
            info = cupsCopyDestInfo(http, dest);
    }
    ~Reached()
    {
        if (info)
            cupsFreeDestInfo(info);
        if (http)
            httpClose(http);
        if (dest)
            cupsFreeDests(1, dest);
    }
    Q_DISABLE_COPY(Reached)
};

// The PDFs being shown, and their pictures: a page on white at the size asked
// for, drawn off the main thread (as Preview's pages.cpp).
QMutex s_lock;
QHash<QString, std::shared_ptr<QPdfDocument>> s_shown;

class Printed : public QQuickImageProvider
{
public:
    Printed()
        : QQuickImageProvider(QQuickImageProvider::Image, QQmlImageProviderBase::ForceAsynchronousImageLoading)
    {
    }
    QImage requestImage(const QString &id, QSize *size, const QSize &requested) override
    {
        const qsizetype slash = id.lastIndexOf(QLatin1Char('/'));
        std::shared_ptr<QPdfDocument> document;
        {
            QMutexLocker locker(&s_lock);
            document = s_shown.value(id.left(slash));
        }
        const int page = id.mid(slash + 1).toInt();
        if (!document || page < 0 || page >= document->pageCount())
            return {};
        const QSizeF points = document->pagePointSize(page);
        if (points.isEmpty())
            return {};
        QSize want = requested;
        if (want.width() <= 0 && want.height() <= 0)
            want = points.toSize();
        else if (want.height() <= 0)
            want.setHeight(qRound(want.width() * points.height() / points.width()));
        else if (want.width() <= 0)
            want.setWidth(qRound(want.height() * points.width() / points.height()));
        const QImage drawn = document->render(page, want.boundedTo(QSize(2400, 2400)));
        if (drawn.isNull())
            return {};
        // PDFium leaves what the page doesn't paint transparent.
        QImage paper(drawn.size(), QImage::Format_RGB32);
        paper.fill(Qt::white);
        QPainter painter(&paper);
        painter.drawImage(0, 0, drawn);
        painter.end();
        if (size)
            *size = paper.size();
        return paper;
    }
};
}

Cups::Cups(QObject *parent)
    : QObject(parent)
{
}

Cups::~Cups()
{
    QMutexLocker locker(&s_lock);
    s_shown.clear();
}

Cups *Cups::create(QQmlEngine *engine, QJSEngine *)
{
    engine->addImageProvider(u"printing"_s, new Printed);
    return new Cups;
}

void Cups::look()
{
    if (m_looking)
        return;
    m_looking = true;
    QPointer<Cups> self(this);
    QThread *thread = QThread::create([self] {
        QVariantList found;
        if (answering()) {
            cups_dest_t *dests = nullptr;
            const int count = cupsGetDests2(CUPS_HTTP_DEFAULT, &dests);
            for (int i = 0; i < count; i++) {
                const cups_dest_t &dest = dests[i];
                if (dest.instance) // a saved set of options, not a printer
                    continue;
                const QString name = QString::fromUtf8(dest.name);
                const QString title = QString::fromUtf8(cupsGetOption("printer-info", dest.num_options, dest.options));
                found.append(QVariantMap{
                    {u"name"_s, name},
                    {u"title"_s, title.isEmpty() ? name : title},
                    {u"isDefault"_s, dest.is_default != 0},
                });
            }
            cupsFreeDests(count, dests);
            std::sort(found.begin(), found.end(), [](const QVariant &a, const QVariant &b) {
                return a.toMap().value(u"title"_s).toString().localeAwareCompare(b.toMap().value(u"title"_s).toString()) < 0;
            });
        }
        QMetaObject::invokeMethod(qApp, [self, found] {
            if (!self)
                return;
            self->m_looking = false;
            self->m_looked = true;
            self->m_printers = found;
            Q_EMIT self->changed();
        }, Qt::QueuedConnection);
    });
    connect(thread, &QThread::finished, thread, &QObject::deleteLater);
    thread->start();
}

QVariantList Cups::papers() const
{
    QVariantList all;
    for (const Paper &paper : known)
        all.append(::told(paper));
    return all;
}

QString Cups::usual() const
{
    return QLocale().measurementSystem() == QLocale::MetricSystem ? u"iso_a4_210x297mm"_s : u"na_letter_8.5x11in"_s;
}

void Cups::ask(const QString &printer)
{
    const QString fallback = usual();
    QPointer<Cups> self(this);
    QThread *thread = QThread::create([self, printer, fallback] {
        QVariantList takes;
        QString unlessTold;
        {
            const Reached reached(printer, 5000);
            if (reached.info) {
                QStringList keys;
                const int count = cupsGetDestMediaCount(reached.http, reached.dest, reached.info, CUPS_MEDIA_FLAGS_DEFAULT);
                cups_size_t size;
                for (int i = 0; i < count; i++) {
                    if (cupsGetDestMediaByIndex(reached.http, reached.dest, reached.info, i, CUPS_MEDIA_FLAGS_DEFAULT, &size))
                        keys.append(QString::fromUtf8(size.media).toLower());
                }
                for (const Paper &paper : known) {
                    if (keys.contains(QLatin1String(paper.key)))
                        takes.append(::told(paper));
                }
                if (cupsGetDestMediaDefault(reached.http, reached.dest, reached.info, CUPS_MEDIA_FLAGS_DEFAULT, &size))
                    unlessTold = QString::fromUtf8(size.media).toLower();
            }
        }
        // A printer that says nothing we know takes what we name.
        if (takes.isEmpty()) {
            for (const Paper &paper : known)
                takes.append(::told(paper));
        }
        const bool among = std::any_of(takes.cbegin(), takes.cend(), [&](const QVariant &each) {
            return each.toMap().value(u"key"_s).toString() == unlessTold;
        });
        if (!among) {
            const bool has = std::any_of(takes.cbegin(), takes.cend(), [&](const QVariant &each) {
                return each.toMap().value(u"key"_s).toString() == fallback;
            });
            unlessTold = has ? fallback : takes.constFirst().toMap().value(u"key"_s).toString();
        }
        QMetaObject::invokeMethod(qApp, [self, printer, takes, unlessTold] {
            if (self)
                Q_EMIT self->told(printer, takes, unlessTold);
        }, Qt::QueuedConnection);
    });
    connect(thread, &QThread::finished, thread, &QObject::deleteLater);
    thread->start();
}

QString Cups::folder()
{
    if (!m_folder)
        m_folder = std::make_unique<QTemporaryDir>(QDir::tempPath() + u"/ambrosia-print-XXXXXX"_s);
    return m_folder->path();
}

QUrl Cups::scratch()
{
    return QUrl::fromLocalFile(folder() + u'/' + QString::number(++m_files) + u".pdf"_s);
}

void Cups::discard(const QUrl &file)
{
    // Only what `scratch` gave.
    if (m_folder && file.isLocalFile() && file.toLocalFile().startsWith(m_folder->path() + u'/'))
        QFile::remove(file.toLocalFile());
}

QVariantMap Cups::open(const QUrl &file)
{
    auto document = std::make_shared<QPdfDocument>();
    QVariantList pages;
    if (document->load(file.toLocalFile()) == QPdfDocument::Error::None) {
        for (int page = 0; page < document->pageCount(); page++) {
            const QSizeF size = document->pagePointSize(page);
            pages.append(QVariantMap{{u"width"_s, size.width()}, {u"height"_s, size.height()}});
        }
    }
    const QString id = QString::number(++m_opened);
    {
        QMutexLocker locker(&s_lock);
        s_shown.insert(id, document);
    }
    return {{u"id"_s, id}, {u"pages"_s, pages}};
}

void Cups::close(const QString &id)
{
    QMutexLocker locker(&s_lock);
    s_shown.remove(id);
}

void Cups::send(const QString &printer, const QUrl &file, const QString &title, const QVariantMap &options)
{
    const QString path = file.toLocalFile();
    QPointer<Cups> self(this);
    QThread *thread = QThread::create([self, printer, path, title, options] {
        const auto said = [self](bool ok, const QString &why) {
            QMetaObject::invokeMethod(qApp, [self, ok, why] {
                if (self)
                    Q_EMIT self->sent(ok, why);
            }, Qt::QueuedConnection);
        };
        QFile pdf(path);
        if (!pdf.open(QIODevice::ReadOnly)) {
            said(false, u"The document could not be read."_s);
            return;
        }
        int count = 0;
        cups_option_t *list = nullptr;
        const int copies = std::clamp(options.value(u"copies"_s, 1).toInt(), 1, 999);
        count = cupsAddOption(CUPS_COPIES, QByteArray::number(copies).constData(), count, &list);
        if (copies > 1)
            count = cupsAddOption("multiple-document-handling", "separate-documents-collated-copies", count, &list);
        const int from = options.value(u"from"_s).toInt(), to = options.value(u"to"_s).toInt();
        if (from >= 1 && to >= from)
            count = cupsAddOption("page-ranges", (QByteArray::number(from) + '-' + QByteArray::number(to)).constData(), count, &list);
        const QByteArray paper = options.value(u"paper"_s).toString().toUtf8();
        if (!paper.isEmpty())
            count = cupsAddOption(CUPS_MEDIA, paper.constData(), count, &list);
        if (options.value(u"landscape"_s).toBool())
            count = cupsAddOption(CUPS_ORIENTATION, CUPS_ORIENTATION_LANDSCAPE, count, &list);
        if (options.value(u"fit"_s).toBool())
            count = cupsAddOption("fit-to-page", "true", count, &list);

        const QByteArray name = title.toUtf8();
        bool ok = false;
        QString why;
        {
            const Reached reached(printer, 30000);
            if (reached.info) {
                int job = 0;
                if (cupsCreateDestJob(reached.http, reached.dest, reached.info, &job, name.constData(), count, list) <= IPP_STATUS_OK_EVENTS_COMPLETE
                    && cupsStartDestDocument(reached.http, reached.dest, reached.info, job, name.constData(), CUPS_FORMAT_PDF, count, list, 1) == HTTP_STATUS_CONTINUE) {
                    ok = true;
                    char buffer[65536];
                    for (qint64 got; (got = pdf.read(buffer, sizeof(buffer))) > 0;) {
                        if (cupsWriteRequestData(reached.http, buffer, size_t(got)) != HTTP_STATUS_CONTINUE) {
                            ok = false;
                            break;
                        }
                    }
                    if (cupsFinishDestDocument(reached.http, reached.dest, reached.info) > IPP_STATUS_OK_EVENTS_COMPLETE)
                        ok = false;
                    if (!ok) {
                        why = QString::fromUtf8(cupsLastErrorString());
                        cupsCancelDestJob(reached.http, reached.dest, job);
                    }
                } else {
                    why = QString::fromUtf8(cupsLastErrorString());
                }
            } else if (reached.dest) {
                // A printer that won't say what it can do is still handed
                // the file, the plain way.
                ok = cupsPrintFile2(CUPS_HTTP_DEFAULT, reached.dest->name, path.toUtf8().constData(), name.constData(), count, list) != 0;
                if (!ok)
                    why = QString::fromUtf8(cupsLastErrorString());
            } else {
                why = u"The printer could not be reached."_s;
            }
        }
        cupsFreeOptions(count, list);
        said(ok, why);
    });
    connect(thread, &QThread::finished, thread, &QObject::deleteLater);
    thread->start();
}

void Cups::preview(const QUrl &file, const QString &title)
{
    // Under the document's name, in a folder of its own: Preview's title
    // is the file's.
    QString name = title;
    name.replace(u'/', u'-');
    if (name.isEmpty())
        name = u"Untitled"_s;
    const QString within = folder() + u"/preview-"_s + QString::number(++m_files);
    QDir().mkpath(within);
    const QString copy = within + u'/' + name + u".pdf"_s;
    if (QFile::copy(file.toLocalFile(), copy))
        QProcess::startDetached(u"ambrosia-preview"_s, {copy});
}

void Cups::settings()
{
    QProcess::startDetached(u"ambrosia-settings"_s, {u"--pane"_s, u"printers"_s});
}

void Cups::shade(QQuickWindow *window, int radius)
{
    if (!window)
        return;
    if (!makeShadow(window, radius, window->devicePixelRatio())->create())
        qWarning("Print panel: KWin took no shadow for the window");
}
