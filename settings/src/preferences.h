#pragma once

#include <QFileSystemWatcher>
#include <QJsonObject>
#include <QObject>
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

public:
    explicit Preferences(QObject *parent = nullptr);

    QString appearance() const;
    void setAppearance(const QString &appearance);
    QString accent() const;
    void setAccent(const QString &accent);
    bool jumpToClick() const;
    void setJumpToClick(bool on);

Q_SIGNALS:
    void changed();

private:
    void read();
    void write();

    QString m_path;
    QJsonObject m_settings;
    QFileSystemWatcher m_watcher;
};
