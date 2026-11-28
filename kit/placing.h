// A window comes back where it was left, as a Mac's does: its place and
// size are the compositor's to keep (Wayland tells an app neither), and
// KWin keeps them for the windows that ask by the session-management
// protocol (xdg_session_manager_v1), under the app's name and the
// window's.
//
//     int main(int argc, char *argv[])
//     {
//         KitPlacing placing(argc, argv, "org.ambrosia.calculator");
//         QApplication app(argc, argv);
//         kitPlacing(&app);
//
// and a window that wants its place kept says which window it is:
//
//     Window { property string frameName: "main" }
//
// Two windows open at once can't share a name (the protocol ends an app
// that tries), so a second "main" is asked for as "main-2", the third as
// "main-3", each the lowest free: the window says what it got in
// `framedAs`.
//
// Qt names the session on its command line (-session) and has no public
// way to name a window: that part is its private QWaylandWindow
// interface, so it is used only by the Qt this was built with (same
// major.minor), and anywhere else, or built without Qt's private
// headers, this does nothing.
#pragma once

#include <QEvent>
#include <QGuiApplication>
#include <QHash>
#include <QLibraryInfo>
#include <QPlatformSurfaceEvent>
#include <QPointer>
#include <QVersionNumber>
#include <QWindow>

#include <cstring>
#include <vector>

#ifdef Q_OS_UNIX
#include <fcntl.h>
#include <sys/file.h>
#include <unistd.h>
#endif

#if defined(Q_OS_LINUX) && __has_include(<QtGui/qpa/qplatformwindow_p.h>)
#include <QtGui/qpa/qplatformwindow_p.h>
#define KIT_PLACING_NAMES 1
#endif

// Adds "-session <id>" to the command line Qt reads, unless one is there.
// Made before the application object and alive as long as it.
//
// One process at a time has the session: a second one asking for it would
// take it from the first (KWin calls the first's "replaced" and keeps its
// windows' places no more), and most of our apps' second launches only
// hand their files to the first and leave. So the first holds a lock (a
// file in the runtime folder, flock) for as long as it runs, and a process
// that finds it held asks for nothing.
class KitPlacing
{
public:
    KitPlacing(int &argc, char **&argv, const char *id)
    {
        for (int i = 1; i < argc; ++i) {
            if (argv[i] && std::strcmp(argv[i], "-session") == 0)
                return;
        }
#ifdef Q_OS_UNIX
        const QByteArray runtime = qgetenv("XDG_RUNTIME_DIR");
        if (runtime.isEmpty())
            return;
        const int fd = ::open((runtime + '/' + id + ".placing.lock").constData(), O_CREAT | O_RDWR | O_CLOEXEC, 0600);
        if (fd < 0)
            return;
        if (::flock(fd, LOCK_EX | LOCK_NB) != 0) {
            ::close(fd);
            return;
        }
        // Held, and let go by the kernel, until the process ends.
#else
        return;
#endif
        m_args.assign(argv, argv + argc);
        m_args.push_back(const_cast<char *>("-session"));
        m_args.push_back(const_cast<char *>(id));
        m_args.push_back(nullptr);
        argc += 2;
        argv = m_args.data();
    }

private:
    std::vector<char *> m_args;
};

class KitPlacer : public QObject
{
public:
    using QObject::QObject;

    // The name a window would be given now: `wanted`, or the lowest
    // "wanted-N" no open window holds.
    QString freeName(const QString &wanted) const
    {
        QString name = wanted;
        for (int n = 2; held(name); ++n)
            name = wanted + QLatin1Char('-') + QString::number(n);
        return name;
    }

protected:
    bool eventFilter(QObject *object, QEvent *event) override
    {
        if (event->type() != QEvent::PlatformSurface || !object->isWindowType())
            return false;
        auto *window = static_cast<QWindow *>(object);
        if (static_cast<QPlatformSurfaceEvent *>(event)->surfaceEventType() == QPlatformSurfaceEvent::SurfaceCreated)
            name(window);
        else
            m_names.remove(window);
        return false;
    }

private:
    bool held(const QString &name) const
    {
        for (auto it = m_names.cbegin(); it != m_names.cend(); ++it) {
            if (it.value() == name)
                return true;
        }
        return false;
    }

    void name(QWindow *window)
    {
        const QString wanted = window->property("frameName").toString();
        if (wanted.isEmpty() || !window->isTopLevel() || !qGuiApp || qGuiApp->sessionId().isEmpty())
            return;
#ifdef KIT_PLACING_NAMES
        auto *native = window->nativeInterface<QNativeInterface::Private::QWaylandWindow>();
        if (!native)
            return;
        const QString name = freeName(wanted);
        m_names.insert(window, name);
        native->setSessionRestoreId(name);
        window->setProperty("framedAs", name);
#endif
    }

    QHash<QWindow *, QString> m_names;
};

// Once per app, after the application object. Returns the placer (null
// where windows can't be named).
inline KitPlacer *kitPlacing(QGuiApplication *app)
{
    static QPointer<KitPlacer> placer;
    if (placer)
        return placer;
#ifdef KIT_PLACING_NAMES
    const QVersionNumber running = QLibraryInfo::version();
    if (QGuiApplication::platformName() != QLatin1String("wayland") || running.majorVersion() != QT_VERSION_MAJOR
        || running.minorVersion() != QT_VERSION_MINOR)
        return nullptr;
    placer = new KitPlacer(app);
    app->installEventFilter(placer);
#else
    Q_UNUSED(app);
#endif
    return placer;
}
