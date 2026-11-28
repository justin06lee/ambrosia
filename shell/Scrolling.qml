// A trackpad's momentum and rubber band in the shell's lists, as in our
// apps (kit/scrolling.h): importing the module is what installs it
// (style/scrolling, in ambrosia-style). shell.qml loads this file by name,
// so a system without the module has a shell all the same.
import QtQuick
import org.ambrosia.scrolling

QtObject {}
