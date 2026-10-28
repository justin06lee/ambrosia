#pragma once

#include <QObject>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

// General › About: this computer as System Settings describes a Mac. The
// name is hostnamed's pretty hostname (set through hostnamed, with polkit's
// prompt); the model and its maker from hostnamed (the firmware's DMI); the
// chip and memory from /proc; graphics from the DRM devices and pci.ids;
// the displays from the screens; the system volume from statvfs; the
// system's name from os-release and its version from our package.
class About : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(QString computerName READ computerName NOTIFY computerNameChanged)
    Q_PROPERTY(QString model READ model CONSTANT)
    Q_PROPERTY(QString maker READ maker CONSTANT)
    Q_PROPERTY(bool laptop READ laptop CONSTANT)
    Q_PROPERTY(QString chip READ chip CONSTANT)
    Q_PROPERTY(QString memory READ memory CONSTANT)
    Q_PROPERTY(QStringList graphics READ graphics CONSTANT)
    Q_PROPERTY(QString systemName READ systemName CONSTANT)
    Q_PROPERTY(QString systemVersion READ systemVersion CONSTANT)
    Q_PROPERTY(QVariantList displays READ displays NOTIFY displaysChanged)
    Q_PROPERTY(QString volumeName READ volumeName CONSTANT)
    Q_PROPERTY(QString volumeSpace READ volumeSpace NOTIFY volumeSpaceChanged)

public:
    explicit About(QObject *parent = nullptr);

    QString computerName() const { return m_name; }
    QString model() const { return m_model; }
    QString maker() const { return m_maker; }
    bool laptop() const { return m_laptop; }
    QString chip() const { return m_chip; }
    QString memory() const { return m_memory; }
    QStringList graphics() const { return m_graphics; }
    QString systemName() const { return m_systemName; }
    QString systemVersion() const { return m_systemVersion; }
    QVariantList displays() const;
    QString volumeName() const { return m_volumeName; }
    QString volumeSpace() const;

    // Renames the computer (hostnamed's pretty hostname); polkit asks for
    // an administrator's password where it needs one.
    Q_INVOKABLE void setComputerName(const QString &name);
    // Reads the free space again (the page does when it's shown).
    Q_INVOKABLE void refresh();

Q_SIGNALS:
    void computerNameChanged();
    void displaysChanged();
    void volumeSpaceChanged();

private Q_SLOTS:
    void hostnameChanged(const QString &interface, const QVariantMap &changed, const QStringList &invalidated);

private:
    void readName();

    QString m_name;
    QString m_model;
    QString m_maker;
    bool m_laptop = false;
    QString m_chip;
    QString m_memory;
    QStringList m_graphics;
    QString m_systemName;
    QString m_systemVersion;
    QString m_volumeName;
    int m_spaceTick = 0;
};
