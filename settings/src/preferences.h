#pragma once

#include <QFileSystemWatcher>
#include <QJsonObject>
#include <QObject>
#include <QStringList>
#include <QUrl>
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
