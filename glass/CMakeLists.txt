cmake_minimum_required(VERSION 3.25)
project(ambrosia-glass VERSION 0.1.0 LANGUAGES C CXX)

# Ambrosia's glass, in two halves that speak ambrosia_glass_v1 (protocol/):
#
# effect/  a KWin effect in KWin's blur's place: what is behind each pane of
#          glass, blurred and saturated as the pane's material asks, inside
#          its rounded outline. Forked from KWin's blur and linked to KWin:
#          GPL-2.0-or-later, unlike the rest of the repository.
# qml/     org.ambrosia.glass, a QML module: GlassPane, the item our QML puts
#          where a pane is. Only Qt and libwayland: MIT.
#
# The materials come from the tokens, through dist/glass/tokens.h
# (bun tools/gen/index.ts).

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE RelWithDebInfo)
endif()

# GuiPrivate: the window's Wayland surface, for the QML module (Qt's own
# warning about private headers says no more than this).
set(QT_NO_PRIVATE_MODULE_WARNING ON)
# Widgets: KWin's own targets name it.
find_package(Qt6 6.8 REQUIRED COMPONENTS Core Gui GuiPrivate Qml Quick Widgets)
find_package(KWin REQUIRED)
find_package(KDecoration3 REQUIRED)
find_package(KF6CoreAddons REQUIRED)
find_package(PkgConfig REQUIRED)
pkg_check_modules(WAYLAND_CLIENT REQUIRED IMPORTED_TARGET wayland-client)
pkg_check_modules(WAYLAND_SERVER REQUIRED IMPORTED_TARGET wayland-server)
find_program(WAYLAND_SCANNER wayland-scanner REQUIRED)

set(AMBROSIA_TOKENS "${CMAKE_CURRENT_SOURCE_DIR}/../dist/glass" CACHE PATH "Where the generated tokens.h is")
if(NOT EXISTS "${AMBROSIA_TOKENS}/tokens.h")
    message(FATAL_ERROR "No ${AMBROSIA_TOKENS}/tokens.h: run bun tools/gen/index.ts first")
endif()

set(PROTOCOL "${CMAKE_CURRENT_SOURCE_DIR}/protocol/ambrosia-glass-v1.xml")
foreach(side server client)
    add_custom_command(OUTPUT ambrosia-glass-v1-${side}.h
        COMMAND "${WAYLAND_SCANNER}" ${side}-header "${PROTOCOL}" ambrosia-glass-v1-${side}.h
        DEPENDS "${PROTOCOL}" VERBATIM)
endforeach()
add_custom_command(OUTPUT ambrosia-glass-v1.c
    COMMAND "${WAYLAND_SCANNER}" private-code "${PROTOCOL}" ambrosia-glass-v1.c
    DEPENDS "${PROTOCOL}" VERBATIM)

add_library(ambrosia_glass MODULE
    effect/main.cpp
    effect/glass.h effect/glass.cpp
    effect/protocol.h effect/protocol.cpp
    effect/glass.qrc
    "${CMAKE_CURRENT_BINARY_DIR}/ambrosia-glass-v1.c" "${CMAKE_CURRENT_BINARY_DIR}/ambrosia-glass-v1-server.h"
)
set_target_properties(ambrosia_glass PROPERTIES PREFIX "")
target_include_directories(ambrosia_glass PRIVATE "${AMBROSIA_TOKENS}" "${CMAKE_CURRENT_BINARY_DIR}")
target_link_libraries(ambrosia_glass PRIVATE KWin::kwin KDecoration3::KDecoration KF6::CoreAddons Qt6::Core Qt6::Gui Qt6::Qml PkgConfig::WAYLAND_SERVER)
# Clients' glass objects call into this until KWin itself ends, whether or
# not the effect is still loaded: it is never unloaded.
target_link_options(ambrosia_glass PRIVATE -Wl,-z,nodelete)

install(TARGETS ambrosia_glass DESTINATION lib/qt6/plugins/kwin/effects/plugins)

add_library(ambrosiaglass MODULE
    qml/plugin.cpp
    qml/pane.h qml/pane.cpp
    "${CMAKE_CURRENT_BINARY_DIR}/ambrosia-glass-v1.c" "${CMAKE_CURRENT_BINARY_DIR}/ambrosia-glass-v1-client.h"
)
target_include_directories(ambrosiaglass PRIVATE "${CMAKE_CURRENT_BINARY_DIR}")
target_link_libraries(ambrosiaglass PRIVATE Qt6::Core Qt6::Gui Qt6::GuiPrivate Qt6::Qml Qt6::Quick PkgConfig::WAYLAND_CLIENT)

install(TARGETS ambrosiaglass DESTINATION lib/qt6/qml/org/ambrosia/glass)
install(FILES qml/qmldir DESTINATION lib/qt6/qml/org/ambrosia/glass)
