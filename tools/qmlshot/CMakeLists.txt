cmake_minimum_required(VERSION 3.25)
project(ambrosia-qmlshot LANGUAGES CXX)

# Draws a QML file into a picture with no window on screen, so a piece of
# the shell can be looked at where Quickshell and KWin don't run (the Mac):
#
#   qmlshot sheet.qml out.png [--dark] [--import dir]... [--font file]... [--wait ms]
#
# The sheets in sheets/ lay a piece out in its states; they can use anything
# of the shell's that needs only Qt Quick and the generated Theme.

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 6.8 REQUIRED COMPONENTS Gui Qml Quick)

add_executable(qmlshot main.cpp)
target_link_libraries(qmlshot PRIVATE Qt6::Gui Qt6::Qml Qt6::Quick)
