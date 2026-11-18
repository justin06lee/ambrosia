cmake_minimum_required(VERSION 3.25)
project(ambrosia-qmlshot LANGUAGES CXX)

# Draws a QML file into a picture with no window on screen, so a piece of
# the shell can be looked at where Quickshell and KWin don't run (the Mac):
#
#   qmlshot sheet.qml out.png [--dark] [--import dir]... [--font file]... [--wait ms]
#
# The sheets in sheets/ lay a piece out in its states. The shell's own files
# load as they are: what they import of Quickshell and Plasma is stood in
# for by stubs.cpp and the QML modules in stubs/.

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_AUTOMOC ON)

find_package(Qt6 6.8 REQUIRED COMPONENTS Gui Qml Quick Svg)
# For laying a hidden window out between frames (main.cpp). Its own
# component from Qt 6.9; part of Quick's before.
find_package(Qt6 QUIET COMPONENTS QuickPrivate)

add_executable(qmlshot main.cpp stubs.cpp stubs.h)
target_link_libraries(qmlshot PRIVATE Qt6::Gui Qt6::Qml Qt6::Quick Qt6::QuickPrivate Qt6::Svg)
