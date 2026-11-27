#include "app.h"
#include "shadow.h"

#include <KWindowShadow>

#include <QClipboard>
#include <QGuiApplication>
#include <QQmlEngine>
#include <QTimer>

App *App::s_instance = nullptr;

App::App(const Options &options)
    : m_options(options)
{
    s_instance = this;
}

App *App::create(QQmlEngine *, QJSEngine *)
{
    QQmlEngine::setObjectOwnership(s_instance, QQmlEngine::CppOwnership);
    return s_instance;
}

void App::decorate(QQuickWindow *window, int radius)
{
    if (!window || QGuiApplication::platformName() == QLatin1String("offscreen"))
        return;
    auto *shadow = makeShadow(window, radius, window->devicePixelRatio());
    if (!shadow->create())
        qWarning("Calculator: KWin took no shadow for the window");
}

void App::shown(QQuickWindow *window)
{
    if (m_options.grab.isEmpty() || m_grabbed)
        return;
    m_grabbed = true;
    // Half a second later everything (the font) has been drawn.
    QTimer::singleShot(500, window, [this, window] {
        window->grabWindow().save(m_options.grab);
        QGuiApplication::quit();
    });
}

void App::copy(const QString &text)
{
    QGuiApplication::clipboard()->setText(text);
}

QString App::clipboard() const
{
    return QGuiApplication::clipboard()->text();
}
