#include "app.h"
#include "shadow.h"

#include <KWindowShadow>
#include <KWindowSystem>

#include <QClipboard>
#include <QDir>
#include <QFileDialog>
#include <QFileInfo>
#include <QGuiApplication>
#include <QImageReader>
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

App *App::create(QQmlEngine *, QJSEngine *)
{
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
