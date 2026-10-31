#pragma once

#include <QFileSystemWatcher>
#include <QJsonObject>
#include <QObject>
#include <QStringList>
#include <QUrl>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

// What Settings shares with the shell, ~/.config/ambrosia/settings.json: the
// shell watches it and acts (applying the color scheme, following the night
// in Auto), and may write it too (Control Center); every key is one the shell
// declares, as its writes drop any other. And, in kdeglobals, what the click
// in a scroll bar does.
class Preferences : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    // "auto", "light" or "dark".
    Q_PROPERTY(QString appearance READ appearance WRITE setAppearance NOTIFY changed)
    // A name in Theme's accents.
    Q_PROPERTY(QString accent READ accent WRITE setAccent NOTIFY changed)
    // A click in a scroll bar jumps to the spot, rather than to the next page.
    Q_PROPERTY(bool jumpToClick READ jumpToClick WRITE setJumpToClick NOTIFY changed)
    // The desktop picture, which the shell draws: "nectar", a picture's path
    // or a color as "#rrggbb"; a picture that's gone reads as "nectar".
    Q_PROPERTY(QString wallpaper READ wallpaper WRITE setWallpaper NOTIFY changed)
    // "fill", "fit", "stretch", "center" or "tile".
    Q_PROPERTY(QString wallpaperFit READ wallpaperFit WRITE setWallpaperFit NOTIFY changed)
    // The pictures added so far that still exist, the latest first.
    Q_PROPERTY(QStringList wallpaperRecent READ wallpaperRecent NOTIFY changed)
    // The Dock, which the shell draws: its icons' size in points; how much
    // the one under the pointer grows, 0 to 1; "left", "bottom" or "right";
    // whether it hides, launching apps bounce, running ones have dots.
    Q_PROPERTY(int dockSize READ dockSize WRITE setDockSize NOTIFY changed)
    Q_PROPERTY(qreal dockMagnification READ dockMagnification WRITE setDockMagnification NOTIFY changed)
    Q_PROPERTY(QString dockPosition READ dockPosition WRITE setDockPosition NOTIFY changed)
    Q_PROPERTY(bool dockAutohide READ dockAutohide WRITE setDockAutohide NOTIFY changed)
    Q_PROPERTY(bool dockBounce READ dockBounce WRITE setDockBounce NOTIFY changed)
    Q_PROPERTY(bool dockIndicators READ dockIndicators WRITE setDockIndicators NOTIFY changed)
    // All of the file, for what a page only reads and writes as it stands
    // (the menu bar's, Notifications', Focus'), through set() below.
    Q_PROPERTY(QVariantMap all READ all NOTIFY changed)

public:
    explicit Preferences(QObject *parent = nullptr);

    QString appearance() const;
    void setAppearance(const QString &appearance);
    QString accent() const;
    void setAccent(const QString &accent);
    bool jumpToClick() const;
    void setJumpToClick(bool on);
    QString wallpaper() const;
    void setWallpaper(const QString &wallpaper);
    QString wallpaperFit() const;
    void setWallpaperFit(const QString &fit);
    QStringList wallpaperRecent() const;
    int dockSize() const;
    void setDockSize(int size);
    qreal dockMagnification() const;
    void setDockMagnification(qreal amount);
    QString dockPosition() const;
    void setDockPosition(const QString &position);
    bool dockAutohide() const;
    void setDockAutohide(bool on);
    bool dockBounce() const;
    void setDockBounce(bool on);
    bool dockIndicators() const;
    void setDockIndicators(bool on);
    QVariantMap all() const;
    Q_INVOKABLE void set(const QString &key, const QVariant &value);

    // Where Nectar's day and night are.
    Q_INVOKABLE QString wallpaperFolder() const;
    // A local path as an Image takes it, whatever is in its name.
    Q_INVOKABLE QUrl pictureUrl(const QString &path) const;
    // The system's dialogs; what's chosen becomes the wallpaper.
    Q_INVOKABLE void addWallpaperPicture();
    Q_INVOKABLE void chooseWallpaperColor();

Q_SIGNALS:
    void changed();

private:
    void read();
    void write();

    QString m_path;
    QJsonObject m_settings;
    QFileSystemWatcher m_watcher;
};
