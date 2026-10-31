#pragma once

#include <QObject>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

// Date & Time, on timedated: setting the clock automatically, the time zone,
// the time by hand; each asks through polkit.
class DateTime : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(bool automatic READ automatic NOTIFY changed)
    // The NTP server in use, as timesyncd says.
    Q_PROPERTY(QString source READ source NOTIFY changed)
    Q_PROPERTY(QString zone READ zone NOTIFY changed)
    Q_PROPERTY(QString zoneName READ zoneName NOTIFY changed)
    Q_PROPERTY(QString city READ city NOTIFY changed)
    // [{text, value}], every zone there is.
    Q_PROPERTY(QVariantList zones READ zones CONSTANT)

public:
    explicit DateTime(QObject *parent = nullptr);

    bool automatic() const { return m_automatic; }
    QString source() const { return m_source; }
    QString zone() const { return m_zone; }
    QString zoneName() const;
    QString city() const;
    QVariantList zones() const;

    Q_INVOKABLE void read();
    Q_INVOKABLE void setAutomatic(bool on);
    Q_INVOKABLE void setZone(const QString &zone);
    // "yyyy-MM-dd HH:mm:ss"; false if it doesn't read as a time.
    Q_INVOKABLE bool setTime(const QString &text);

Q_SIGNALS:
    void changed();

private:
    void call(const QString &method, const QVariantList &arguments);

    bool m_automatic = false;
    QString m_source;
    QString m_zone;
};
