#include "app.h"
#include "../../kit/placing.h"
#include "../../kit/resume.h"
#include "../../kit/alert.h"
#include "shadow.h"

#include <KWindowShadow>
#include <KWindowSystem>

#include <QClipboard>
#include <QDir>
#include <QFileDialog>
#include <QFileInfo>
#include <QGuiApplication>
#include <QImageReader>
#include <QImageWriter>
#include <QPdfDocument>
#include <QSaveFile>
#include <QMimeDatabase>
#include <QPageLayout>
#include <QPageSize>
#include <QPainter>
#include <QPdfWriter>
#include <QPalette>
#include <QQmlEngine>
#include <QStandardPaths>
#include <QStyleHints>
#include <QTimer>
#include <QTransform>

App *App::s_instance = nullptr;

App::App(const Options &options)
    : m_options(options)
{
    s_instance = this;
    QJSEngine::setObjectOwnership(this, QJSEngine::CppOwnership);
    connect(QGuiApplication::styleHints(), &QStyleHints::colorSchemeChanged, this, &App::appearanceChanged);
    connect(qGuiApp, &QGuiApplication::paletteChanged, this, &App::appearanceChanged);
}

App *App::create(QQmlEngine *engine, QJSEngine *)
{
    // Kept for what is raised from here (the alert of a failed export).
    s_instance->m_engine = engine;
    return s_instance;
}

bool App::dark() const
{
    if (!m_options.appearance.isEmpty())
        return m_options.appearance == QLatin1String("dark");
    return QGuiApplication::styleHints()->colorScheme() == Qt::ColorScheme::Dark;
}

QColor App::accent() const
{
    if (!m_options.appearance.isEmpty())
        return {};
    return QGuiApplication::palette().color(QPalette::Active, QPalette::Highlight);
}

void App::decorate(QQuickWindow *window, int radius)
{
    if (!window || QGuiApplication::platformName() == QLatin1String("offscreen"))
        return;
    auto *shadow = makeShadow(window, radius, window->devicePixelRatio());
    if (!shadow->create())
        qWarning("Preview: KWin took no shadow for the window");
}

void App::shown(QQuickWindow *window)
{
    if (m_options.grab.isEmpty() || m_grabbed)
        return;
    m_grabbed = true;
    // A second and a half later the pages have been drawn (they are drawn
    // off the main thread) and a search has gone through them.
    QTimer::singleShot(1500, window, [this, window] {
        window->grabWindow().save(m_options.grab);
        QGuiApplication::quit();
    });
}

void App::activate(QQuickWindow *window)
{
    if (window->visibility() == QWindow::Minimized)
        window->showNormal();
    KWindowSystem::activateWindow(window);
}

void App::copy(const QString &text)
{
    QGuiApplication::clipboard()->setText(text);
}

void App::copyPicture(const QUrl &file, int quarterTurns)
{
    QImageReader reader(file.toLocalFile());
    reader.setAutoTransform(true);
    QImage picture = reader.read();
    if (picture.isNull())
        return;
    if (quarterTurns % 4 != 0)
        picture = picture.transformed(QTransform().rotate(90 * (quarterTurns % 4)));
    QGuiApplication::clipboard()->setImage(picture);
}

bool App::isPdf(const QUrl &file) const
{
    return QMimeDatabase().mimeTypeForFile(file.toLocalFile()).inherits(QStringLiteral("application/pdf"));
}

bool App::picturesPdf(const QVariantList &files, const QUrl &target, const QSizeF &paper) const
{
    if (files.isEmpty() || paper.isEmpty())
        return false;
    const bool sideways = paper.width() > paper.height();
    QPdfWriter writer(target.toLocalFile());
    writer.setCreator(QStringLiteral("Preview"));
    writer.setResolution(300);
    writer.setPageSize(QPageSize(sideways ? paper.transposed() : paper, QPageSize::Point, QString(), QPageSize::ExactMatch));
    writer.setPageOrientation(sideways ? QPageLayout::Landscape : QPageLayout::Portrait);
    writer.setPageMargins(QMarginsF(18, 18, 18, 18), QPageLayout::Point);
    QPainter painter;
    bool first = true;
    for (const QVariant &each : files) {
        QImageReader reader(each.toUrl().toLocalFile());
        reader.setAutoTransform(true);
        const QImage picture = reader.read();
        if (picture.isNull())
            continue;
        if (first) {
            if (!painter.begin(&writer))
                return false;
            painter.setRenderHint(QPainter::SmoothPixmapTransform);
        } else {
            writer.newPage();
        }
        first = false;
        const QRectF page(0, 0, writer.width(), writer.height());
        const QSizeF fitted = QSizeF(picture.size()).scaled(page.size(), Qt::KeepAspectRatio);
        painter.drawImage(QRectF(QPointF((page.width() - fitted.width()) / 2, (page.height() - fitted.height()) / 2), fitted), picture);
    }
    if (first)
        return false;
    painter.end();
    return true;
}

QStringList App::exportFormats() const
{
    QStringList formats;
    const QList<QByteArray> known = QImageWriter::supportedImageFormats();
    for (const char *format : {"jpeg", "png", "tiff"}) {
        if (known.contains(format))
            formats << QString::fromLatin1(format);
    }
    return formats;
}

bool App::exportAs(const QUrl &source, int page, int quarterTurns, const QUrl &target, const QString &format)
{
    const QString from = source.toLocalFile(), to = target.toLocalFile();
    auto fail = [&](const QString &why) {
        const QString heading = QStringLiteral("The document “%1” could not be exported.").arg(QFileInfo(from).fileName());
        if (!kitAlert(m_engine, QStringLiteral("Preview"), {{QStringLiteral("icon"), QStringLiteral("org.ambrosia.preview")}, {QStringLiteral("heading"), heading}, {QStringLiteral("detail"), why}}))
            qWarning("Preview: %s %s", qPrintable(heading), qPrintable(why));
        return false;
    };
    const bool fromPdf = isPdf(source);
    if (fromPdf && format == QLatin1String("pdf")) {
        if (QFileInfo(from) == QFileInfo(to))
            return true;
        QFile::remove(to);
        return QFile::copy(from, to) ? true : fail(QStringLiteral("The file couldn’t be written there."));
    }
    // What is written: the picture as it is shown, or the PDF's page.
    QImage picture;
    if (fromPdf) {
        QPdfDocument document;
        if (document.load(from) != QPdfDocument::Error::None || page < 0 || page >= document.pageCount())
            return fail(QStringLiteral("The PDF couldn’t be read."));
        const QSizeF points = document.pagePointSize(page);
        const QSize pixels = (points * 150.0 / 72.0).toSize();
        const QImage drawn = document.render(page, pixels);
        if (drawn.isNull())
            return fail(QStringLiteral("The page couldn’t be drawn."));
        // A page is paper: white under what it leaves bare.
        picture = QImage(pixels, QImage::Format_RGB32);
        picture.fill(Qt::white);
        QPainter painter(&picture);
        painter.drawImage(0, 0, drawn);
        painter.end();
        picture.setDotsPerMeterX(qRound(150 / 0.0254));
        picture.setDotsPerMeterY(qRound(150 / 0.0254));
    } else {
        QImageReader reader(from);
        reader.setAutoTransform(true);
        picture = reader.read();
        if (picture.isNull())
            return fail(reader.errorString());
    }
    if (quarterTurns % 4 != 0)
        picture = picture.transformed(QTransform().rotate(90 * (quarterTurns % 4)));

    if (format == QLatin1String("pdf")) {
        // One page the picture's own size: a point a pixel unless the
        // picture says how many it has to the inch.
        const qreal dpi = picture.dotsPerMeterX() > 0 ? picture.dotsPerMeterX() * 0.0254 : 72.0;
        const qreal scale = dpi > 20 && dpi < 2400 ? 72.0 / dpi : 1.0;
        const QSizeF points = QSizeF(picture.size()) * scale;
        QPdfWriter writer(to);
        writer.setCreator(QStringLiteral("Preview"));
        writer.setResolution(300);
        writer.setPageSize(QPageSize(points, QPageSize::Point, QString(), QPageSize::ExactMatch));
        writer.setPageMargins(QMarginsF(0, 0, 0, 0), QPageLayout::Point);
        QPainter painter;
        if (!painter.begin(&writer))
            return fail(QStringLiteral("The file couldn’t be written there."));
        painter.setRenderHint(QPainter::SmoothPixmapTransform);
        painter.drawImage(QRectF(0, 0, writer.width(), writer.height()), picture);
        painter.end();
        return true;
    }
    if (format == QLatin1String("jpeg") && picture.hasAlphaChannel()) {
        // JPEG has no see-through: white under it, as a Mac's.
        QImage flat(picture.size(), QImage::Format_RGB32);
        flat.fill(Qt::white);
        QPainter painter(&flat);
        painter.drawImage(0, 0, picture);
        painter.end();
        flat.setDotsPerMeterX(picture.dotsPerMeterX());
        flat.setDotsPerMeterY(picture.dotsPerMeterY());
        picture = flat;
    }
    QSaveFile file(to);
    if (!file.open(QIODevice::WriteOnly))
        return fail(file.errorString());
    QImageWriter writer(&file, format.toLatin1());
    if (format == QLatin1String("jpeg"))
        writer.setQuality(90);
    if (!writer.write(picture)) {
        const QString why = writer.errorString();
        file.cancelWriting();
        return fail(why);
    }
    return file.commit() ? true : fail(file.errorString());
}

QSize App::imageSize(const QUrl &file) const
{
    QImageReader reader(file.toLocalFile());
    reader.setAutoTransform(true);
    QSize size = reader.size();
    if (!size.isValid()) {
        // A format that can't say without being read.
        size = reader.read().size();
        return size;
    }
    if (reader.transformation() & QImageIOHandler::TransformationRotate90)
        size.transpose();
    return size;
}

QString App::name(const QUrl &file) const
{
    return file.fileName();
}

QString App::frameFor(const QString &file) const
{
    return file.isEmpty() || !m_options.grab.isEmpty() ? QString() : kitFrameName(file);
}

bool App::leaving() const
{
    return m_options.grab.isEmpty() && kitKeeping();
}

void App::keep(const QStringList &files) const
{
    kitKeepWindow(QStringLiteral("preview"), files);
}

QVariantList App::takeKept() const
{
    QVariantList windows;
    if (!m_options.grab.isEmpty())
        return windows;
    const QList<QStringList> kept = kitTakeKept(QStringLiteral("preview"));
    for (const QStringList &files : kept)
        windows.append(QVariant(files));
    return windows;
}

void App::chooseFiles()
{
    if (m_choosing)
        return;
    m_choosing = true;
    QStringList patterns{QStringLiteral("*.pdf")};
    const QList<QByteArray> formats = QImageReader::supportedImageFormats();
    for (const QByteArray &format : formats) {
        if (format != "pdf")
            patterns << QStringLiteral("*.") + QString::fromLatin1(format);
    }
    auto *dialog = new QFileDialog(nullptr, QStringLiteral("Open"));
    dialog->setAttribute(Qt::WA_DeleteOnClose);
    dialog->setFileMode(QFileDialog::ExistingFiles);
    dialog->setAcceptMode(QFileDialog::AcceptOpen);
    dialog->setNameFilter(QStringLiteral("Pictures and PDFs (%1)").arg(patterns.join(QLatin1Char(' '))));
    const QStringList pictures = QStandardPaths::standardLocations(QStandardPaths::PicturesLocation);
    if (!pictures.isEmpty())
        dialog->setDirectory(pictures.first());
    connect(dialog, &QFileDialog::finished, this, [this, dialog](int result) {
        m_choosing = false;
        QStringList chosen;
        if (result == QDialog::Accepted) {
            const QList<QUrl> urls = dialog->selectedUrls();
            for (const QUrl &url : urls)
                chosen << url.toString();
        }
        if (chosen.isEmpty())
            Q_EMIT chooseCancelled();
        else
            Q_EMIT openRequested(chosen);
    });
    dialog->open();
}

QStringList App::urls(const QStringList &arguments)
{
    QStringList urls;
    for (const QString &argument : arguments) {
        const QUrl given(argument);
        if (given.isValid() && !given.scheme().isEmpty() && given.scheme().size() > 1)
            urls << given.toString();
        else
            urls << QUrl::fromLocalFile(QFileInfo(argument).absoluteFilePath()).toString();
    }
    return urls;
}

void App::Open(const QStringList &files, const QString &token)
{
    if (!token.isEmpty())
        KWindowSystem::setCurrentXdgActivationToken(token);
    if (files.isEmpty())
        chooseFiles();
    else
        Q_EMIT openRequested(files);
}
