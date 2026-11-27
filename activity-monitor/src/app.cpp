#include "app.h"
#include "shadow.h"

#include <KWindowShadow>
#include <KWindowSystem>

#include <QClipboard>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusPendingCall>
#include <QGuiApplication>
#include <QPalette>
#include <QQmlEngine>
#include <QStyleHints>
#include <QTimer>
#include <QUrl>

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
        qWarning("Activity Monitor: KWin took no shadow for the window");
}

void App::shown(QQuickWindow *window, bool inspector)
{
    if (m_options.grab.isEmpty() || m_grabbed || inspector != (m_options.inspect >= 0))
        return;
    m_grabbed = true;
    // After the second reading (a second in), so the rates are there.
    QTimer::singleShot(1800, window, [this, window] {
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
    KWindowSystem::activateWindow(window);
}

void App::copy(const QString &text)
{
    QGuiApplication::clipboard()->setText(text);
}

void App::reveal(const QString &path)
{
    if (path.isEmpty())
        return;
    QDBusMessage call = QDBusMessage::createMethodCall(QStringLiteral("org.freedesktop.FileManager1"), QStringLiteral("/org/freedesktop/FileManager1"),
                                                       QStringLiteral("org.freedesktop.FileManager1"), QStringLiteral("ShowItems"));
    call << QStringList{QUrl::fromLocalFile(path).toString()} << QString();
    QDBusConnection::sessionBus().asyncCall(call);
}

void App::Show(const QString &token)
{
    if (!token.isEmpty())
        KWindowSystem::setCurrentXdgActivationToken(token);
    Q_EMIT showRequested();
}
