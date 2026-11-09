#include "sharing.h"

#include "dryrun.h"

#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusMessage>
#include <QDBusObjectPath>
#include <QDBusPendingCallWatcher>
#include <QDBusReply>

using namespace Qt::StringLiterals;

namespace
{
const auto systemd = u"org.freedesktop.systemd1"_s;
const auto managerPath = u"/org/freedesktop/systemd1"_s;
const auto manager = u"org.freedesktop.systemd1.Manager"_s;
const auto sshd = u"sshd.service"_s;
const auto hostnamed = u"org.freedesktop.hostname1"_s;
}

Sharing::Sharing(QObject *parent)
    : QObject(parent)
{
    read();
}

QString Sharing::user() const
{
    return qEnvironmentVariable("USER");
}

void Sharing::read()
{
    QDBusInterface host(hostnamed, u"/org/freedesktop/hostname1"_s, hostnamed, QDBusConnection::systemBus());
    m_hostname = host.property("Hostname").toString();

    QDBusInterface systemdManager(systemd, managerPath, manager, QDBusConnection::systemBus());
    const QDBusReply<QDBusObjectPath> path = systemdManager.call(u"LoadUnit"_s, sshd);
    if (path.isValid()) {
        QDBusInterface unit(systemd, path.value().path(), u"org.freedesktop.systemd1.Unit"_s, QDBusConnection::systemBus());
        m_available = unit.property("LoadState").toString() == "loaded"_L1;
        m_remoteLogin = unit.property("ActiveState").toString() == "active"_L1;
    } else {
        m_available = false;
    }
    Q_EMIT changed();
}

void Sharing::setRemoteLogin(bool on)
{
    if (dryRun(on ? "enable and start sshd.service" : "stop and disable sshd.service"))
        return;
    // Enabled or disabled first, so a refusal changes nothing; then started or stopped.
    QDBusMessage message = on
        ? QDBusMessage::createMethodCall(systemd, managerPath, manager, u"EnableUnitFiles"_s)
        : QDBusMessage::createMethodCall(systemd, managerPath, manager, u"DisableUnitFiles"_s);
    if (on)
        message.setArguments({QStringList{sshd}, false, false});
    else
        message.setArguments({QStringList{sshd}, false});
    message.setInteractiveAuthorizationAllowed(true);
    auto *first = new QDBusPendingCallWatcher(QDBusConnection::systemBus().asyncCall(message, 120000), this);
    connect(first, &QDBusPendingCallWatcher::finished, this, [this, first, on] {
        first->deleteLater();
        if (first->isError()) {
            qWarning("Settings: systemd: %s", qPrintable(first->error().message()));
            read();
            return;
        }
        QDBusMessage now = QDBusMessage::createMethodCall(systemd, managerPath, manager, on ? u"StartUnit"_s : u"StopUnit"_s);
        now.setArguments({sshd, u"replace"_s});
        now.setInteractiveAuthorizationAllowed(true);
        auto *second = new QDBusPendingCallWatcher(QDBusConnection::systemBus().asyncCall(now, 120000), this);
        connect(second, &QDBusPendingCallWatcher::finished, this, [this, second] {
            second->deleteLater();
            if (second->isError())
                qWarning("Settings: systemd: %s", qPrintable(second->error().message()));
            read();
        });
    });
}

void Sharing::setHostname(const QString &name)
{
    const QString wanted = name.trimmed();
    if (wanted.isEmpty() || wanted == m_hostname)
        return;
    if (dryRun(qPrintable(u"set the static hostname to "_s + wanted + u" (hostnamed)"_s)))
        return;
    QDBusMessage message = QDBusMessage::createMethodCall(hostnamed, u"/org/freedesktop/hostname1"_s, hostnamed, u"SetStaticHostname"_s);
    message.setArguments({wanted, true});
    message.setInteractiveAuthorizationAllowed(true);
    auto *watcher = new QDBusPendingCallWatcher(QDBusConnection::systemBus().asyncCall(message, 120000), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, watcher] {
        watcher->deleteLater();
        if (watcher->isError())
            qWarning("Settings: hostnamed: %s", qPrintable(watcher->error().message()));
        read();
    });
}
