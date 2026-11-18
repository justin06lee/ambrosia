cmake_minimum_required(VERSION 3.25)
project(ambrosia-decoration VERSION 0.1.0 LANGUAGES CXX)

# Ambrosia's window frame for KWin: the titlebar and the traffic lights on
# every window KWin decorates. Sizes and colors come from the tokens, through
# dist/kdecoration/tokens.h (bun tools/gen/index.ts).
#
# Beside it, org.ambrosia.kwin: a small QML module for Ambrosia's QML that
# runs inside KWin (⌘Tab's switcher), with the blur behind its glass and
# apps' names.

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE RelWithDebInfo)
endif()

find_package(Qt6 6.8 REQUIRED COMPONENTS Core Gui)
find_package(KDecoration3 REQUIRED)
find_package(Qt6 6.8 REQUIRED COMPONENTS Qml Quick)
find_package(KF6CoreAddons REQUIRED)
find_package(KF6WindowSystem REQUIRED)
find_package(KF6Service REQUIRED)

set(AMBROSIA_TOKENS "${CMAKE_CURRENT_SOURCE_DIR}/../dist/kdecoration" CACHE PATH "Where the generated tokens.h is")
if(NOT EXISTS "${AMBROSIA_TOKENS}/tokens.h")
    message(FATAL_ERROR "No ${AMBROSIA_TOKENS}/tokens.h: run bun tools/gen/index.ts first")
endif()

add_library(org.ambrosia.decoration MODULE
    src/plugin.cpp
    src/decoration.h src/decoration.cpp
    src/button.h src/button.cpp
    src/shadow.h src/shadow.cpp
)
set_target_properties(org.ambrosia.decoration PROPERTIES PREFIX "")
target_include_directories(org.ambrosia.decoration PRIVATE "${AMBROSIA_TOKENS}")
target_link_libraries(org.ambrosia.decoration PRIVATE Qt6::Core Qt6::Gui KDecoration3::KDecoration KF6::CoreAddons)

install(TARGETS org.ambrosia.decoration DESTINATION lib/qt6/plugins/org.kde.kdecoration3)

add_library(ambrosiakwin MODULE
    qml/plugin.cpp
    qml/blurbehind.h qml/blurbehind.cpp
    qml/apps.h qml/apps.cpp
)
target_link_libraries(ambrosiakwin PRIVATE Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick KF6::WindowSystem KF6::Service)

install(TARGETS ambrosiakwin DESTINATION lib/qt6/qml/org/ambrosia/kwin)
install(FILES qml/qmldir DESTINATION lib/qt6/qml/org/ambrosia/kwin)
