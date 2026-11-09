#include "datetime.h"

#include "dryrun.h"

#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusMessage>
#include <QDBusPendingCallWatcher>
#include <QDateTime>
#include <QTimeZone>
#include <QVariantMap>

using namespace Qt::StringLiterals;

namespace
{
const auto timedate = u"org.freedesktop.timedate1"_s;
const auto timedatePath = u"/org/freedesktop/timedate1"_s;
}

DateTime::DateTime(QObject *parent)
    : QObject(parent)
{
    read();
}

void DateTime::read()
{
    QDBusInterface date(timedate, timedatePath, timedate, QDBusConnection::systemBus());
    m_automatic = date.property("NTP").toBool();
    m_zone = date.property("Timezone").toString();
    m_source.clear();
    // Only while it's on: asking would start it otherwise.
    if (m_automatic) {
        QDBusInterface sync(u"org.freedesktop.timesync1"_s, u"/org/freedesktop/timesync1"_s, u"org.freedesktop.timesync1.Manager"_s,
                            QDBusConnection::systemBus());
        m_source = sync.property("ServerName").toString();
    }
    Q_EMIT changed();
}

QString DateTime::zoneName() const
{
    const QTimeZone zone(m_zone.toUtf8());
    return zone.isValid() ? zone.displayName(QDateTime::currentDateTime(), QTimeZone::LongName) : m_zone;
}

QString DateTime::city() const
{
    return m_zone.section(u'/', -1).replace(u'_', u' ');
}

QVariantList DateTime::zones() const
{
    QVariantList list;
    const QList<QByteArray> ids = QTimeZone::availableTimeZoneIds();
    for (const QByteArray &id : ids) {
        if (!id.contains('/'))
            continue;
        const QString zone = QString::fromUtf8(id);
        list.append(QVariantMap{{u"text"_s, QString(zone).replace(u'_', u' ')}, {u"value"_s, zone}});
    }
    return list;
}

void DateTime::call(const QString &method, const QVariantList &arguments)
{
    QDBusMessage message = QDBusMessage::createMethodCall(timedate, timedatePath, timedate, method);
    message.setArguments(arguments);
    message.setInteractiveAuthorizationAllowed(true);
    auto *watcher = new QDBusPendingCallWatcher(QDBusConnection::systemBus().asyncCall(message, 120000), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, watcher] {
        watcher->deleteLater();
        if (watcher->isError())
            qWarning("Settings: timedated: %s", qPrintable(watcher->error().message()));
        read();
    });
}

void DateTime::setAutomatic(bool on)
{
    if (dryRun(on ? "turn NTP on (timedated SetNTP)" : "turn NTP off (timedated SetNTP)"))
        return;
    call(u"SetNTP"_s, {on, true});
}

void DateTime::setZone(const QString &zone)
{
    if (dryRun(qPrintable(u"set the time zone to "_s + zone + u" (timedated SetTimezone)"_s)))
        return;
    call(u"SetTimezone"_s, {zone, true});
}

bool DateTime::setTime(const QString &text)
{
    const QDateTime time = QDateTime::fromString(text.trimmed(), u"yyyy-MM-dd HH:mm:ss"_s);
    if (!time.isValid())
        return false;
    if (dryRun(qPrintable(u"set the clock to "_s + time.toString(Qt::ISODate) + u" (timedated SetTime)"_s)))
        return true;
    call(u"SetTime"_s, {QVariant::fromValue(time.toMSecsSinceEpoch() * 1000), false, true});
    return true;
}
