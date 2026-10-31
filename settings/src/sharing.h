#pragma once

#include <QObject>
#include <QtQml/qqmlregistration.h>

// Sharing: Remote Login (sshd, through systemd) and the computer's local
// hostname (hostnamed). Each change asks through polkit.
class Sharing : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(bool remoteLoginAvailable READ remoteLoginAvailable NOTIFY changed)
    Q_PROPERTY(bool remoteLogin READ remoteLogin NOTIFY changed)
    Q_PROPERTY(QString hostname READ hostname NOTIFY changed)
    Q_PROPERTY(QString user READ user CONSTANT)

public:
    explicit Sharing(QObject *parent = nullptr);

    bool remoteLoginAvailable() const { return m_available; }
    bool remoteLogin() const { return m_remoteLogin; }
    QString hostname() const { return m_hostname; }
    QString user() const;

    Q_INVOKABLE void read();
    Q_INVOKABLE void setRemoteLogin(bool on);
    Q_INVOKABLE void setHostname(const QString &name);

Q_SIGNALS:
    void changed();

private:
    bool m_available = false;
    bool m_remoteLogin = false;
    QString m_hostname;
};
