#include "printers.h"

#include "dryrun.h"

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QLocale>
#include <QPointer>
#include <QProcess>
#include <QSaveFile>
#include <QThread>
#include <QUrl>
#include <algorithm>
#include <functional>
#include <cups/cups.h>
#include <sys/socket.h>

using namespace Qt::StringLiterals;

namespace
{
struct Paper {
    const char *name;
    const char *pwg;
    const char *legacy; // what a PPD and older tools call it
};
const Paper paperSizes[] = {
    {QT_TRANSLATE_NOOP("Printers", "US Letter"), "na_letter_8.5x11in", "Letter"},
    {QT_TRANSLATE_NOOP("Printers", "US Legal"), "na_legal_8.5x14in", "Legal"},
    {QT_TRANSLATE_NOOP("Printers", "A4"), "iso_a4_210x297mm", "A4"},
    {QT_TRANSLATE_NOOP("Printers", "A5"), "iso_a5_148x210mm", "A5"},
    {QT_TRANSLATE_NOOP("Printers", "JIS B5"), "jis_b5_182x257mm", "B5"},
    {QT_TRANSLATE_NOOP("Printers", "Envelope #10"), "na_number-10_4.125x9.5in", "Env10"},
    {QT_TRANSLATE_NOOP("Printers", "Envelope DL"), "iso_dl_110x220mm", "EnvDL"},
    {QT_TRANSLATE_NOOP("Printers", "Tabloid"), "na_ledger_11x17in", "Tabloid"},
    {QT_TRANSLATE_NOOP("Printers", "A3"), "iso_a3_297x420mm", "A3"},
};

QString pwgOf(const QString &media)
{
    for (const Paper &each : paperSizes) {
        if (media.compare(QLatin1String(each.pwg), Qt::CaseInsensitive) == 0 || media.compare(QLatin1String(each.legacy), Qt::CaseInsensitive) == 0)
            return QLatin1String(each.pwg);
    }
    return media;
}

QString option(const cups_dest_t &dest, const char *name)
{
    return QString::fromUtf8(cupsGetOption(name, dest.num_options, dest.options));
}

// Where a printer is, from its device address: a host name, or "" for a
// DNS-SD name (which says nothing a person can use) and local devices.
QString hostOf(const QString &uri)
{
    const QUrl url(uri);
    if (url.scheme() == u"dnssd" || url.host().isEmpty())
        return {};
    return url.host();
}

struct Snapshot {
    bool running = false;
    QVariantList printers;
    QString defaultPrinter;
    QString paper;
};

Snapshot snapshot()
{
    Snapshot result;
    http_t *http = httpConnect2(cupsServer(), ippPort(), nullptr, AF_UNSPEC, cupsEncryption(), 1, 2000, nullptr);
    result.running = http != nullptr;
    if (!http)
        return result;
    httpClose(http);

    cups_dest_t *dests = nullptr;
    const int count = cupsGetDests2(CUPS_HTTP_DEFAULT, &dests);
    QString media;
    QString firstMedia;
    for (int i = 0; i < count; i++) {
        const cups_dest_t &dest = dests[i];
        if (dest.instance) // a saved set of options for a printer, not a printer
            continue;
        const QString name = QString::fromUtf8(dest.name);
        const uint type = option(dest, "printer-type").toUInt();
        const bool added = !(type & CUPS_PRINTER_DISCOVERED);
        const int state = option(dest, "printer-state").toInt();
        int jobs = 0;
        if (added) {
            cups_job_t *list = nullptr;
            jobs = std::max(0, cupsGetJobs2(CUPS_HTTP_DEFAULT, &list, dest.name, 0, CUPS_WHICHJOBS_ACTIVE));
            cupsFreeJobs(jobs, list);
        }
        const QString title = option(dest, "printer-info");
        QVariantMap printer{
            {u"name"_s, name},
            {u"title"_s, title.isEmpty() ? name : title},
            {u"model"_s, option(dest, "printer-make-and-model")},
            {u"location"_s, option(dest, "printer-location")},
            {u"address"_s, hostOf(option(dest, "device-uri"))},
            {u"state"_s, !added ? u"nearby"_s : state == IPP_PSTATE_STOPPED ? u"stopped"_s : state == IPP_PSTATE_PROCESSING || jobs > 0 ? u"printing"_s : u"idle"_s},
            {u"jobs"_s, jobs},
            {u"isDefault"_s, dest.is_default != 0},
            {u"added"_s, added},
        };
        result.printers.append(printer);
        const QString own = option(dest, "media");
        if (dest.is_default) {
            result.defaultPrinter = name;
            media = own;
        }
        if (firstMedia.isEmpty())
            firstMedia = own;
    }
    cupsFreeDests(count, dests);
    std::sort(result.printers.begin(), result.printers.end(), [](const QVariant &a, const QVariant &b) {
        return a.toMap().value(u"title"_s).toString().localeAwareCompare(b.toMap().value(u"title"_s).toString()) < 0;
    });
    if (media.isEmpty())
        media = firstMedia;
    // Nothing chosen yet: what the region uses, as apps assume.
    if (media.isEmpty())
        media = QLocale().measurementSystem() == QLocale::MetricSystem ? u"iso_a4_210x297mm"_s : u"na_letter_8.5x11in"_s;
    result.paper = pwgOf(media);
    return result;
}

// Your printing defaults, ~/.cups/lpoptions: a line a printer, "Default name
// options…" for the default one and "Dest name options…" for the rest.
// Edited here and not through lpoptions, which saves nothing while CUPS has
// no queue of its own (cupsSetDests gives up when the server lists no
// printers), which is whenever every printer is one found on the network.
void editOptions(const std::function<void(QList<QByteArrayList> &)> &edit)
{
    const QString path = QDir::homePath() + u"/.cups/lpoptions"_s;
    QList<QByteArrayList> lines;
    QFile file(path);
    if (file.open(QIODevice::ReadOnly)) {
        const QByteArrayList text = file.readAll().split('\n');
        for (const QByteArray &each : text) {
            QByteArrayList words = each.simplified().split(' ');
            if (words.size() >= 2 && (words.at(0) == "Default" || words.at(0) == "Dest"))
                lines.append(words);
        }
    }
    edit(lines);
    QDir().mkpath(QDir::homePath() + u"/.cups"_s);
    QSaveFile out(path);
    if (!out.open(QIODevice::WriteOnly))
        return;
    for (const QByteArrayList &line : std::as_const(lines))
        out.write(line.join(' ') + '\n');
    out.commit();
}
}

Printers::Printers(QObject *parent)
    : QObject(parent)
{
    read();
}

void Printers::read()
{
    if (m_reading) {
        m_again = true;
        return;
    }
    m_reading = true;
    QPointer<Printers> self(this);
    QThread *thread = QThread::create([self] {
        Snapshot result = snapshot();
        QMetaObject::invokeMethod(qApp, [self, result] {
            if (!self)
                return;
            self->m_reading = false;
            if (self->m_running != result.running || self->m_printers != result.printers || self->m_default != result.defaultPrinter
                || self->m_paper != result.paper) {
                self->m_running = result.running;
                self->m_printers = result.printers;
                self->m_default = result.defaultPrinter;
                self->m_paper = result.paper;
                Q_EMIT self->changed();
            }
            if (self->m_again) {
                self->m_again = false;
                self->read();
            }
        }, Qt::QueuedConnection);
    });
    connect(thread, &QThread::finished, thread, &QObject::deleteLater);
    thread->start();
}

QVariantList Printers::papers() const
{
    QVariantList list;
    for (const Paper &each : paperSizes)
        list.append(QVariantMap{{u"text"_s, tr(each.name)}, {u"value"_s, QLatin1String(each.pwg)}});
    return list;
}

// Runs one of CUPS's own tools, then reads again.
void Printers::run(const QString &program, const QStringList &arguments, const char *what)
{
    if (dryRun(what)) {
        read();
        return;
    }
    auto *process = new QProcess(this);
    connect(process, &QProcess::finished, this, [this, process] {
        process->deleteLater();
        read();
    });
    connect(process, &QProcess::errorOccurred, this, [process] { process->deleteLater(); });
    process->start(program, arguments);
}

void Printers::setDefaultPrinter(const QString &name)
{
    if (name == m_default || dryRun("set the default printer (~/.cups/lpoptions)"))
        return;
    // "" is none: every line a Dest.
    editOptions([&name](QList<QByteArrayList> &lines) {
        bool found = false;
        for (QByteArrayList &line : lines) {
            const bool it = !name.isEmpty() && line.at(1) == name.toUtf8();
            line[0] = it ? "Default" : "Dest";
            found = found || it;
        }
        if (!found && !name.isEmpty())
            lines.append({"Default", name.toUtf8()});
    });
    read();
}

void Printers::setPaper(const QString &paper)
{
    if (paper == m_paper || paper.isEmpty() || m_printers.isEmpty() || dryRun("set every printer's default paper size (~/.cups/lpoptions)"))
        return;
    QByteArrayList names;
    for (const QVariant &each : std::as_const(m_printers))
        names.append(each.toMap().value(u"name"_s).toString().toUtf8());
    editOptions([&names, &paper](QList<QByteArrayList> &lines) {
        for (const QByteArray &name : std::as_const(names)) {
            auto line = std::find_if(lines.begin(), lines.end(), [&name](const QByteArrayList &each) { return each.at(1) == name; });
            if (line == lines.end()) {
                lines.append({"Dest", name});
                line = lines.end() - 1;
            }
            line->removeIf([](const QByteArray &word) { return word.startsWith("media=") || word.startsWith("PageSize="); });
            line->append("media=" + paper.toUtf8());
        }
    });
    read();
}

QString Printers::queueName(const QString &title) const
{
    QString name;
    for (const QChar c : title.trimmed()) {
        if (c.isLetterOrNumber() || c == u'-' || c == u'.')
            name += c;
        else if (!name.endsWith(u'_'))
            name += u'_';
    }
    while (name.endsWith(u'_'))
        name.chop(1);
    return name.left(100);
}

void Printers::add(const QString &address, const QString &title, const QString &location)
{
    QString uri = address.trimmed();
    if (uri.isEmpty() || m_adding)
        return;
    if (!uri.contains(u"://"))
        uri = u"ipp://"_s + uri + u"/ipp/print"_s;
    QString name = queueName(title);
    if (name.isEmpty())
        name = queueName(QUrl(uri).host());
    if (name.isEmpty()) {
        Q_EMIT addDone(false, tr("That isn't a printer's address."));
        return;
    }
    if (dryRun(qPrintable(u"add the printer %1 at %2 (lpadmin)"_s.arg(name, uri)))) {
        Q_EMIT addDone(true, QString());
        return;
    }
    QStringList arguments{u"-p"_s, name, u"-E"_s, u"-v"_s, uri, u"-m"_s, u"everywhere"_s};
    if (!title.trimmed().isEmpty())
        arguments << u"-D"_s << title.trimmed();
    if (!location.trimmed().isEmpty())
        arguments << u"-L"_s << location.trimmed();
    auto *process = new QProcess(this);
    m_adding = true;
    Q_EMIT addingChanged();
    auto done = [this, process](bool ok, const QString &message) {
        process->deleteLater();
        m_adding = false;
        Q_EMIT addingChanged();
        Q_EMIT addDone(ok, message);
        read();
    };
    connect(process, &QProcess::finished, this, [process, done](int code, QProcess::ExitStatus status) {
        QString message = QString::fromLocal8Bit(process->readAllStandardError()).trimmed();
        if (message.startsWith(u"lpadmin: "))
            message.remove(0, 9);
        const bool ok = status == QProcess::NormalExit && code == 0;
        done(ok, ok ? QString() : message.isEmpty() ? tr("The printer couldn't be added.") : message);
    });
    connect(process, &QProcess::errorOccurred, this, [done](QProcess::ProcessError error) {
        if (error == QProcess::FailedToStart)
            done(false, tr("The printer couldn't be added."));
    });
    process->start(u"lpadmin"_s, arguments);
}

void Printers::remove(const QString &name)
{
    if (dryRun("remove a printer (lpadmin)"))
        return;
    // Its saved defaults go with it.
    const QByteArray gone = name.toUtf8();
    editOptions([&gone](QList<QByteArrayList> &lines) {
        lines.removeIf([&gone](const QByteArrayList &line) { return line.at(1) == gone || line.at(1).startsWith(gone + '/'); });
    });
    run(u"lpadmin"_s, {u"-x"_s, name}, "remove a printer (lpadmin)");
}

void Printers::printTestPage(const QString &name)
{
    run(u"lp"_s, {u"-d"_s, name, u"-t"_s, tr("Test Page"), u"/usr/share/cups/data/testprint"_s}, "print a test page (lp)");
}
