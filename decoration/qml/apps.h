#pragma once

#include <QObject>
#include <QString>

namespace Ambrosia
{

// What an app is called and which icon it wears: its desktop file's Name
// ("System Settings" for org.ambrosia.settings) and Icon. KWin's QML knows a
// window's desktop file and no more.
class Apps : public QObject
{
    Q_OBJECT

public:
    using QObject::QObject;

    // The name for a desktop file's name (without ".desktop"), or "" when
    // there is no such app.
    Q_INVOKABLE QString name(const QString &desktopFile) const;

    // The name of its icon (the file's Icon=), or "".
    Q_INVOKABLE QString icon(const QString &desktopFile) const;
};

}
