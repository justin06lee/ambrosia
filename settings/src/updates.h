#pragma once

#include <QObject>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

// Software Update, on PackageKit: what's waiting (against the package lists as
// they stand; opening the page doesn't refresh them), checking again, and
// installing it all.
class Updates : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    // "idle" (nothing asked yet), "reading", "checking", "ready", "installing" or "failed".
    Q_PROPERTY(QString state READ state NOTIFY changed)
    // [{name, version}], sorted.
    Q_PROPERTY(QVariantList packages READ packages NOTIFY changed)
    Q_PROPERTY(int percent READ percent NOTIFY changed)
    Q_PROPERTY(QString error READ error NOTIFY changed)

public:
    explicit Updates(QObject *parent = nullptr);

    QString state() const { return m_state; }
    QVariantList packages() const { return m_packages; }
    int percent() const { return m_percent; }
    QString error() const { return m_error; }

    Q_INVOKABLE void read();
    Q_INVOKABLE void check();
    Q_INVOKABLE void install();

Q_SIGNALS:
    void changed();

private Q_SLOTS:
    void onPackage(uint info, const QString &id, const QString &summary);
    void onFinished(uint status, uint runtime);
    void onError(uint code, const QString &details);
    void onProperties(const QString &interface, const QVariantMap &changed, const QStringList &invalidated);

private:
    void run(const QString &state, const QString &method, const QVariantList &arguments);
    void disconnectTransaction();

    QString m_state = QStringLiteral("idle");
    QString m_method;
    QString m_path;
    QStringList m_ids;
    QVariantList m_packages;
    QVariantList m_collected;
    QStringList m_collectedIds;
    int m_percent = 0;
    QString m_error;
};
