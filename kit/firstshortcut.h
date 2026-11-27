#pragma once

#include <QKeySequence>
#include <QObject>
#include <QShortcut>

// Qt numbers an app's shortcuts down from -1, and its platform menu items
// (Qt.labs.platform, what our menu bars are made of) keep -1 to mean "no
// shortcut". The menu item that happens to take the app's first shortcut
// is therefore never struck from Qt's table when its window closes, and
// whichever menu item is next built where it stood answers its key: in a
// second Preview window ⌘, opened About every other press (with nothing
// built there, the key goes to freed memory). This takes that first number
// for a shortcut that never fires, before any menu exists: call it right
// after the application object is made.
inline void takeFirstShortcutId(QObject *app)
{
    auto *first = new QShortcut(QKeySequence(Qt::CTRL | Qt::ALT | Qt::SHIFT | Qt::META | Qt::Key_F35), app);
    first->setEnabled(false);
}
