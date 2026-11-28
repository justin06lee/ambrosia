// What was open when the session ended is open again at the next login,
// as on a Mac that logs back in with "Reopen windows" on. Plasma starts
// the apps that were open again (its own doing: plasma-fallback-session-
// restore); what each had open is the app's to bring back, and these are
// the pieces: whether a window is being closed because the session is
// ending, and a file per app of the windows so closed
// (~/.local/state/ambrosia/<app>-windows.json: { "windows": [[url, ...],
// ...] }, each window the documents it showed).
//
//     closing a window:   if (kitLeaving()) kitKeepWindow("textedit", { url });
//     starting:           for (const QStringList &window : kitTakeKept("textedit")) ...
//
// A window the user closes is asked about the same way and gets a no, so
// it is not kept. The file is taken (read and removed) by the app's next
// start, whenever that is.
#pragma once

#include <QDBusConnection>
#include <QDBusMessage>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSaveFile>
#include <QStandardPaths>
#include <QStringList>
#include <QUrl>

// Whether a log out, restart or shut down is under way: Plasma's session
// manager says so from before it has the windows closed (seen: 0.4 s
// before). No session manager, or no answer in 300 ms, is a no.
inline bool kitLeaving()
{
    QDBusConnection bus = QDBusConnection::sessionBus();
    if (!bus.isConnected())
        return false;
    QDBusMessage ask = QDBusMessage::createMethodCall(QStringLiteral("org.kde.ksmserver"), QStringLiteral("/KSMServer"),
                                                      QStringLiteral("org.kde.KSMServerInterface"), QStringLiteral("isShuttingDown"));
    ask.setAutoStartService(false);
    const QDBusMessage answer = bus.call(ask, QDBus::Block, 300);
    return answer.type() == QDBusMessage::ReplyMessage && answer.arguments().value(0).toBool();
}

inline QString kitKeptPath(const QString &app)
{
    return QStandardPaths::writableLocation(QStandardPaths::GenericStateLocation) + QStringLiteral("/ambrosia/") + app
        + QStringLiteral("-windows.json");
}

inline QJsonArray kitKeptWindows(const QString &app)
{
    QFile file(kitKeptPath(app));
    if (!file.open(QIODevice::ReadOnly))
        return {};
    return QJsonDocument::fromJson(file.readAll()).object().value(QLatin1String("windows")).toArray();
}

// One more window to open next time: the documents it shows (URLs).
inline void kitKeepWindow(const QString &app, const QStringList &files)
{
    if (files.isEmpty())
        return;
    QJsonArray windows = kitKeptWindows(app);
    windows.append(QJsonArray::fromStringList(files));
    const QString path = kitKeptPath(app);
    QDir().mkpath(QFileInfo(path).path());
    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly))
        return;
    file.write(QJsonDocument(QJsonObject{{QStringLiteral("windows"), windows}}).toJson());
    file.commit();
}

// The windows kept, and the file gone: each the documents that are still
// there (a window left with none is left out).
inline QList<QStringList> kitTakeKept(const QString &app)
{
    QList<QStringList> windows;
    const QJsonArray kept = kitKeptWindows(app);
    QFile::remove(kitKeptPath(app));
    for (const QJsonValue &each : kept) {
        QStringList files;
        const QJsonArray all = each.toArray();
        for (const QJsonValue &file : all) {
            const QUrl url(file.toString());
            if (url.isValid() && (!url.isLocalFile() || QFileInfo::exists(url.toLocalFile())))
                files.append(url.toString());
        }
        if (!files.isEmpty())
            windows.append(files);
    }
    return windows;
}
