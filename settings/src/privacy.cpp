#include "privacy.h"

#include "dryrun.h"

#include <KService>
#include <QDBusArgument>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusReply>
#include <QDBusVariant>
#include <QDir>
#include <QFile>
#include <QFileInfo>

#include <sys/stat.h>
#include <sys/sysmacros.h>

using namespace Qt::StringLiterals;

namespace
{
const auto store = u"org.freedesktop.impl.portal.PermissionStore"_s;
const auto storePath = u"/org/freedesktop/impl/portal/PermissionStore"_s;

QDBusMessage storeCall(const QString &method, const QVariantList &arguments)
{
    QDBusMessage message = QDBusMessage::createMethodCall(store, storePath, store, method);
    message.setArguments(arguments);
    return message;
}

// A table's entry: each app and what it was granted; empty if there is none.
QMap<QString, QStringList> lookup(const QString &table, const QString &id)
{
    QMap<QString, QStringList> permissions;
    const QDBusMessage reply = QDBusConnection::sessionBus().call(storeCall(u"Lookup"_s, {table, id}), QDBus::Block, 3000);
    if (reply.type() != QDBusMessage::ReplyMessage || reply.arguments().isEmpty())
        return permissions;
    const QDBusArgument argument = reply.arguments().first().value<QDBusArgument>();
    argument >> permissions;
    return permissions;
}

QStringList ids(const QString &table)
{
    const QDBusReply<QStringList> reply = QDBusConnection::sessionBus().call(storeCall(u"List"_s, {table}), QDBus::Block, 3000);
    return reply.isValid() ? reply.value() : QStringList();
}

// An app by its id, as the launcher names it; host apps the portal couldn't
// name ("") aren't listed.
QVariantMap app(const QString &id, const QString &kind, bool allowed)
{
    const KService::Ptr service = KService::serviceByDesktopName(id);
    return {
        {u"app"_s, id},
        {u"name"_s, service ? service->name() : id},
        {u"icon"_s, service ? service->icon() : QString()},
        {u"allowed"_s, allowed},
        {u"kind"_s, kind},
    };
}

QVariantList granted(const QString &table, const QString &id, const QString &kind)
{
    QVariantList list;
    const auto permissions = lookup(table, id);
    for (auto it = permissions.cbegin(); it != permissions.cend(); ++it)
        if (!it.key().isEmpty())
            list.append(app(it.key(), kind, it.value().value(0) == u"yes"));
    return list;
}

// Whether a block device, or one under it (LVM on LUKS), is a dm-crypt one.
bool encrypted(const QString &sys)
{
    QFile uuid(sys + u"/dm/uuid"_s);
    if (uuid.open(QIODevice::ReadOnly) && uuid.readAll().startsWith("CRYPT-"))
        return true;
    const QDir slaves(sys + u"/slaves"_s);
    for (const QString &slave : slaves.entryList(QDir::Dirs | QDir::NoDotAndDotDot))
        if (encrypted(slaves.filePath(slave)))
            return true;
    return false;
}
}

Privacy::Privacy(QObject *parent)
    : QObject(parent)
{
    QDBusConnection::sessionBus().connect(store, storePath, store, u"Changed"_s, this, SLOT(read()));
    read();
    m_ready = true;
}

void Privacy::read()
{
    QVariantList screen = granted(u"screenshot"_s, u"screenshot"_s, u"screenshot"_s);
    // Screen shares an app was let start again without asking.
    QSet<QString> kept;
    for (const QString &table : {u"screencast"_s, u"remote-desktop"_s})
        for (const QString &token : ids(table))
            for (const QString &each : lookup(table, token).keys())
                if (!each.isEmpty() && !kept.contains(each)) {
                    kept.insert(each);
                    screen.append(app(each, u"screencast"_s, true));
                }
    m_apps = {
        {u"camera"_s, granted(u"devices"_s, u"camera"_s, u"camera"_s)},
        {u"microphone"_s, granted(u"devices"_s, u"microphone"_s, u"microphone"_s)},
        {u"screen"_s, screen},
    };
    if (m_ready)
        Q_EMIT changed();
}

void Privacy::setAllowed(const QString &rowKind, const QString &app, bool allowed)
{
    if (dryRun(qPrintable(u"set "_s + rowKind + u" for "_s + app + (allowed ? u" to yes"_s : u" to no"_s) + u" (permission store)"_s)))
        return;
    QDBusConnection bus = QDBusConnection::sessionBus();
    if (rowKind == u"screencast") {
        // A kept share can only be forgotten: the app asks again next time.
        if (allowed)
            return;
        for (const QString &table : {u"screencast"_s, u"remote-desktop"_s})
            for (const QString &token : ids(table))
                if (lookup(table, token).contains(app))
                    bus.call(storeCall(u"DeletePermission"_s, {table, token, app}), QDBus::Block, 3000);
    } else {
        const QString table = rowKind == u"screenshot" ? u"screenshot"_s : u"devices"_s;
        bus.call(storeCall(u"SetPermission"_s, {table, true, rowKind, app, QStringList{allowed ? u"yes"_s : u"no"_s}}), QDBus::Block, 3000);
    }
    read();
}

QString Privacy::diskEncryption() const
{
    // The device "/" is mounted from, from the mount table (a btrfs
    // subvolume's own device number names no disk).
    QFile mounts(u"/proc/self/mountinfo"_s);
    if (!mounts.open(QIODevice::ReadOnly))
        return {};
    QString source;
    for (const QByteArray &line : mounts.readAll().split('\n')) {
        const QList<QByteArray> fields = line.split(' ');
        const int dash = fields.indexOf("-");
        if (fields.size() > 4 && fields.at(4) == "/" && dash > 0 && dash + 2 < fields.size())
            source = QString::fromUtf8(fields.at(dash + 2));
    }
    struct stat info {};
    if (!source.startsWith(u"/dev/"_s) || ::stat(QFile::encodeName(source).constData(), &info) != 0 || !S_ISBLK(info.st_mode))
        return {};
    const QString sys = u"/sys/dev/block/%1:%2"_s.arg(major(info.st_rdev)).arg(minor(info.st_rdev));
    if (!QFileInfo::exists(sys))
        return {};
    return encrypted(sys) ? u"on"_s : u"off"_s;
}
