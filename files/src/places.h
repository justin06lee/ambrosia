#pragma once

#include <QObject>
#include <QUrl>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

#include <Solid/Device>
#include <Solid/SolidNamespace>

// What the sidebar lists, in Finder's sections: the top items, Favorites,
// Locations and Tags. Each item is {name, url, glyph} (tags: {name, color}).
//
// Locations also has the other disks, from Solid: every volume with a file
// system that isn't part of the system (the disk it starts from is the
// computer's row), whether it is mounted or not. Theirs are {name, glyph,
// volume, url if mounted, ejectable, busy}: a click opens one, mounting it
// first, and its eject button unmounts it and, as Solid does for media that
// can be taken out, ejects it or powers its drive down.
class Places : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(QVariantList sections READ sections NOTIFY sectionsChanged)
    Q_PROPERTY(QString computer READ computer CONSTANT)

public:
    explicit Places(QObject *parent = nullptr);
    QVariantList sections() const;
    QString computer() const;

    // The Go menu's places by name: recents, applications, desktop,
    // documents, downloads, home, computer, trash.
    Q_INVOKABLE QUrl place(const QString &name) const;
    // A volume's row was clicked: opened() follows once it is mounted.
    Q_INVOKABLE void open(const QString &volume);
    Q_INVOKABLE void eject(const QString &volume);
    // The mounted volume a folder is on, {name, url, glyph}, or an empty map
    // for a folder on the computer's own disk.
    Q_INVOKABLE QVariantMap volumeOf(const QUrl &url) const;

Q_SIGNALS:
    void sectionsChanged();
    void opened(const QString &volume, const QUrl &url);
    // A volume is about to go: windows showing it go elsewhere first.
    void ejecting(const QUrl &url);

private:
    struct Volume {
        Solid::Device device;
        bool removable = false; // its drive's media comes out, or the drive itself
        bool busy = false;      // being mounted or ejected
    };
    void listVolumes();
    Volume *find(const QString &udi);
    void setupDone(Solid::ErrorType error, const QVariant &data, const QString &udi);
    void teardownDone(Solid::ErrorType error, const QVariant &data, const QString &udi);

    QList<Volume> m_volumes;
    bool m_watching = false;
};
