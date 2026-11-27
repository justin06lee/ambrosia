#include "app.h"
#include "shadow.h"

#include <KWindowShadow>
#include <KWindowSystem>

#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusPendingCall>
#include <QDir>
#include <QFileDialog>
#include <QFileInfo>
#include <QGuiApplication>
#include <QPalette>
#include <QQmlEngine>
#include <QStandardPaths>
#include <QStyleHints>
#include <QTimer>

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

bool App::offscreen() const
{
    return QGuiApplication::platformName() == QLatin1String("offscreen");
}

void App::decorate(QQuickWindow *window, int radius)
{
    if (!window || QGuiApplication::platformName() == QLatin1String("offscreen"))
        return;
    auto *shadow = makeShadow(window, radius, window->devicePixelRatio());
    if (!shadow->create())
        qWarning("Disk Utility: KWin took no shadow for the window");
}

void App::shown(QQuickWindow *window)
{
    if (m_options.grab.isEmpty() || m_grabbed)
        return;
    m_grabbed = true;
    // A moment in, so the disks have been read and drawn.
    QTimer::singleShot(1500, window, [this, window] {
        window->grabWindow().save(m_options.grab);
        QGuiApplication::quit();
    });
}

void App::activate(QQuickWindow *window)
{
    if (!window)
        return;
    if (window->visibility() == QWindow::Minimized)
        window->showNormal();
    window->show();
    window->raise();
    window->requestActivate();
    KWindowSystem::activateWindow(window);
}

void App::reveal(const QString &path)
{
    if (path.isEmpty())
        return;
    QDBusMessage call = QDBusMessage::createMethodCall(QStringLiteral("org.freedesktop.FileManager1"), QStringLiteral("/org/freedesktop/FileManager1"),
                                                       QStringLiteral("org.freedesktop.FileManager1"), QStringLiteral("ShowFolders"));
    call << QStringList{QUrl::fromLocalFile(path).toString()} << QString();
    QDBusConnection::sessionBus().asyncCall(call);
}

void App::Open(const QStringList &files, const QString &token)
{
    if (!token.isEmpty())
        KWindowSystem::setCurrentXdgActivationToken(token);
    QList<QUrl> urls;
    for (const QString &file : files)
        urls << QUrl(file);
    Q_EMIT openRequested(urls);
}

void App::chooseImage()
{
    if (m_choosing)
        return;
    m_choosing = true;
    auto *dialog = new QFileDialog(nullptr, QStringLiteral("Open Disk Image"));
    dialog->setAttribute(Qt::WA_DeleteOnClose);
    dialog->setFileMode(QFileDialog::ExistingFile);
    dialog->setAcceptMode(QFileDialog::AcceptOpen);
    dialog->setLabelText(QFileDialog::Accept, QStringLiteral("Open"));
    dialog->setNameFilters({QStringLiteral("Disk Images (*.iso *.img *.raw *.dmg)"), QStringLiteral("All Files (*)")});
    const QStringList downloads = QStandardPaths::standardLocations(QStandardPaths::DownloadLocation);
    if (!downloads.isEmpty())
        dialog->setDirectory(downloads.first());
    connect(dialog, &QFileDialog::finished, this, [this, dialog](int result) {
        m_choosing = false;
        if (result == QDialog::Accepted && !dialog->selectedUrls().isEmpty())
            Q_EMIT imageChosen(dialog->selectedUrls().constFirst());
    });
    dialog->open();
}

QVariantList App::places() const
{
    QVariantList places;
    QStringList seen;
    for (const auto where : {QStandardPaths::DesktopLocation, QStandardPaths::DocumentsLocation, QStandardPaths::DownloadLocation, QStandardPaths::HomeLocation}) {
        const QString path = QStandardPaths::writableLocation(where);
        if (path.isEmpty() || seen.contains(path) || !QFileInfo(path).isDir())
            continue;
        seen << path;
        places << QVariantMap{{QStringLiteral("name"), folderName(path)}, {QStringLiteral("path"), path}};
    }
    return places;
}

QString App::folderName(const QString &path) const
{
    const QString clean = QDir::cleanPath(path);
    if (clean == QLatin1String("/"))
        return QStringLiteral("Computer");
    return QFileInfo(clean).fileName();
}

bool App::exists(const QString &path) const
{
    return QFileInfo::exists(path);
}

void App::chooseFolder(const QString &from)
{
    if (m_choosing)
        return;
    m_choosing = true;
    auto *dialog = new QFileDialog(nullptr, QStringLiteral("Choose a Folder"));
    dialog->setAttribute(Qt::WA_DeleteOnClose);
    dialog->setFileMode(QFileDialog::Directory);
    dialog->setOption(QFileDialog::ShowDirsOnly, true);
    dialog->setAcceptMode(QFileDialog::AcceptOpen);
    dialog->setLabelText(QFileDialog::Accept, QStringLiteral("Choose"));
    if (!from.isEmpty())
        dialog->setDirectory(from);
    connect(dialog, &QFileDialog::finished, this, [this, dialog](int result) {
        m_choosing = false;
        if (result == QDialog::Accepted && !dialog->selectedUrls().isEmpty() && dialog->selectedUrls().constFirst().isLocalFile())
            Q_EMIT folderChosen(dialog->selectedUrls().constFirst().toLocalFile());
    });
    dialog->open();
}
