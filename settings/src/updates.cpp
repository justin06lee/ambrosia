#include "updates.h"

#include "dryrun.h"

#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusObjectPath>
#include <QVariantMap>
#include <algorithm>

using namespace Qt::StringLiterals;

namespace
{
const auto service = u"org.freedesktop.PackageKit"_s;
const auto transaction = u"org.freedesktop.PackageKit.Transaction"_s;
constexpr quint64 noFilter = 2; // PK_FILTER_ENUM_NONE, as a bit
constexpr quint64 trusted = 2; // PK_TRANSACTION_FLAG_ENUM_ONLY_TRUSTED, as a bit
constexpr uint success = 1; // PK_EXIT_ENUM_SUCCESS
}

Updates::Updates(QObject *parent)
    : QObject(parent)
{
}

void Updates::read()
{
    if (m_state == "reading"_L1 || m_state == "checking"_L1 || m_state == "installing"_L1)
        return;
    run(u"reading"_s, u"GetUpdates"_s, {QVariant::fromValue(noFilter)});
}

void Updates::check()
{
    if (dryRun("refresh the package lists (PackageKit RefreshCache)"))
        return;
    run(u"checking"_s, u"RefreshCache"_s, {false});
}

void Updates::install()
{
    if (dryRun("install every update (PackageKit UpdatePackages)"))
        return;
    run(u"installing"_s, u"UpdatePackages"_s, {QVariant::fromValue(trusted), m_ids});
}

void Updates::run(const QString &state, const QString &method, const QVariantList &arguments)
{
    m_state = state;
    m_method = method;
    m_error.clear();
    m_percent = 0;
    m_collected.clear();
    m_collectedIds.clear();
    Q_EMIT changed();

    QDBusMessage create = QDBusMessage::createMethodCall(service, u"/org/freedesktop/PackageKit"_s, service, u"CreateTransaction"_s);
    auto *watcher = new QDBusPendingCallWatcher(QDBusConnection::systemBus().asyncCall(create), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, watcher, method, arguments] {
        watcher->deleteLater();
        const QDBusPendingReply<QDBusObjectPath> reply = *watcher;
        if (reply.isError()) {
            m_state = u"failed"_s;
            m_error = reply.error().message();
            Q_EMIT changed();
            return;
        }
        m_path = reply.value().path();
        QDBusConnection bus = QDBusConnection::systemBus();
        bus.connect(service, m_path, transaction, u"Package"_s, this, SLOT(onPackage(uint, QString, QString)));
        bus.connect(service, m_path, transaction, u"Finished"_s, this, SLOT(onFinished(uint, uint)));
        bus.connect(service, m_path, transaction, u"ErrorCode"_s, this, SLOT(onError(uint, QString)));
        bus.connect(service, m_path, u"org.freedesktop.DBus.Properties"_s, u"PropertiesChanged"_s, this,
                    SLOT(onProperties(QString, QVariantMap, QStringList)));
        QDBusMessage call = QDBusMessage::createMethodCall(service, m_path, transaction, method);
        call.setArguments(arguments);
        call.setInteractiveAuthorizationAllowed(true);
        bus.asyncCall(call);
    });
}

void Updates::disconnectTransaction()
{
    QDBusConnection bus = QDBusConnection::systemBus();
    bus.disconnect(service, m_path, transaction, u"Package"_s, this, SLOT(onPackage(uint, QString, QString)));
    bus.disconnect(service, m_path, transaction, u"Finished"_s, this, SLOT(onFinished(uint, uint)));
    bus.disconnect(service, m_path, transaction, u"ErrorCode"_s, this, SLOT(onError(uint, QString)));
    bus.disconnect(service, m_path, u"org.freedesktop.DBus.Properties"_s, u"PropertiesChanged"_s, this,
                   SLOT(onProperties(QString, QVariantMap, QStringList)));
}

void Updates::onPackage(uint, const QString &id, const QString &)
{
    if (m_method != "GetUpdates"_L1)
        return;
    const QStringList parts = id.split(u';');
    m_collectedIds.append(id);
    m_collected.append(QVariantMap{{u"name"_s, parts.value(0)}, {u"version"_s, parts.value(1)}});
}

void Updates::onError(uint, const QString &details)
{
    m_error = details;
}

void Updates::onProperties(const QString &, const QVariantMap &changed, const QStringList &)
{
    const auto percent = changed.constFind(u"Percentage"_s);
    if (percent == changed.constEnd())
        return;
    const uint value = percent->toUInt();
    m_percent = value > 100 ? 0 : int(value); // 101 means not known
    Q_EMIT this->changed();
}

void Updates::onFinished(uint status, uint)
{
    disconnectTransaction();
    const QString method = m_method;
    if (status != success) {
        m_state = u"failed"_s;
        if (m_error.isEmpty())
            m_error = tr("PackageKit couldn't finish.");
        Q_EMIT changed();
        return;
    }
    if (method == "GetUpdates"_L1) {
        std::sort(m_collected.begin(), m_collected.end(), [](const QVariant &a, const QVariant &b) {
            return a.toMap().value(u"name"_s).toString() < b.toMap().value(u"name"_s).toString();
        });
        m_packages = m_collected;
        m_ids = m_collectedIds;
        m_state = u"ready"_s;
        Q_EMIT changed();
        return;
    }
    // A refresh or an install: what's waiting has changed.
    m_state = u"idle"_s;
    read();
}
