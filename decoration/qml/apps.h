#pragma once

#include <QObject>
#include <QString>

namespace Ambrosia
{

// What an app is called: its desktop file's Name ("System Settings" for
// org.ambrosia.settings). KWin's QML knows a window's desktop file and no
// more.
class Apps : public QObject
{
    Q_OBJECT

public:
    using QObject::QObject;

    // The name for a desktop file's name (without ".desktop"), or "" when
    // there is no such app.
    Q_INVOKABLE QString name(const QString &desktopFile) const;
};

}
