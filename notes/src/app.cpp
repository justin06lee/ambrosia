#include "app.h"
#include "shadow.h"

#include <KWindowShadow>
#include <KWindowSystem>

#include <QGuiApplication>
#include <QLocale>
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

bool App::hour24() const
{
    // The locale's short time has no AM or PM in it.
    return !QLocale().timeFormat(QLocale::ShortFormat).contains(QLatin1Char('a'), Qt::CaseInsensitive);
}

void App::decorate(QQuickWindow *window, int radius)
{
    if (!window || offscreen())
        return;
    auto *shadow = makeShadow(window, radius, window->devicePixelRatio());
    if (!shadow->create())
        qWarning("Notes: KWin took no shadow for the window");
}

void App::shown(QQuickWindow *window)
{
    if (m_options.grab.isEmpty() || m_grabbed)
        return;
    m_grabbed = true;
    QTimer::singleShot(900, window, [this, window] {
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

void App::Show(const QString &token)
{
    if (!token.isEmpty())
        KWindowSystem::setCurrentXdgActivationToken(token);
    Q_EMIT showRequested();
}
