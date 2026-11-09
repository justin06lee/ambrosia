#pragma once

#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

// Privacy & Security: what apps have been allowed through the desktop
// portal (its permission store: camera, microphone, screenshots and screen
// sharing they were let keep), and whether the system disk is encrypted.
// Apps that don't go through the portal (most installed from packages)
// aren't asked, so they don't show.
class Privacy : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    // For each kind ("camera", "microphone", "screen"): [{app, name, icon, allowed, kind}].
    Q_PROPERTY(QVariantMap apps READ apps NOTIFY changed)
    // "on", "off" or "" when it can't be told.
    Q_PROPERTY(QString diskEncryption READ diskEncryption CONSTANT)

public:
    explicit Privacy(QObject *parent = nullptr);

    QVariantMap apps() const { return m_apps; }
    QString diskEncryption() const;

    // An app's permission for a kind, by the row's own kind ("screenshot" or
    // a saved screen share, which turning off forgets).
    Q_INVOKABLE void setAllowed(const QString &rowKind, const QString &app, bool allowed);

public Q_SLOTS:
    void read();

Q_SIGNALS:
    void changed();

private:
    // Set once constructed: a change read while QML is still creating us
    // (Panes asking Power for the battery) mustn't loop back into it.
    bool m_ready = false;
    QVariantMap m_apps;
};
