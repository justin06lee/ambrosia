cmake_minimum_required(VERSION 3.25)
project(ambrosia-style VERSION 0.1.0 LANGUAGES CXX)

# Ambrosia's Qt widget style: the buttons, boxes, sliders, menus, tabs and
# lists of every Qt Widgets app (Konsole, Kate, Dolphin, the file dialog),
# drawn as macOS 26 draws its own. It stands on Breeze, or on Fusion where Breeze isn't
# installed, and repaints one kind of control at a time. Sizes and colors
# come from the tokens, through dist/qstyle/tokens.h (bun tools/gen/index.ts).
#
# The gallery draws every control it covers into a picture, with no display:
# ambrosia-style-gallery out.png [--dark] [--base].

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE RelWithDebInfo)
endif()

find_package(Qt6 6.8 REQUIRED COMPONENTS Core Gui Widgets)

set(AMBROSIA_TOKENS "${CMAKE_CURRENT_SOURCE_DIR}/../dist/qstyle" CACHE PATH "Where the generated tokens.h is")
if(NOT EXISTS "${AMBROSIA_TOKENS}/tokens.h")
    message(FATAL_ERROR "No ${AMBROSIA_TOKENS}/tokens.h: run bun tools/gen/index.ts first")
endif()

add_library(ambrosia-style-objects OBJECT src/style.h src/style.cpp)
set_target_properties(ambrosia-style-objects PROPERTIES POSITION_INDEPENDENT_CODE ON)
target_include_directories(ambrosia-style-objects PUBLIC "${AMBROSIA_TOKENS}" src)
target_link_libraries(ambrosia-style-objects PUBLIC Qt6::Core Qt6::Gui Qt6::Widgets)

# The plugin Qt loads for `widgetStyle=ambrosia` or QT_STYLE_OVERRIDE=ambrosia.
add_library(ambrosia MODULE src/plugin.cpp)
set_target_properties(ambrosia PROPERTIES PREFIX "")
target_link_libraries(ambrosia PRIVATE ambrosia-style-objects)

add_executable(ambrosia-style-gallery gallery/main.cpp)
target_link_libraries(ambrosia-style-gallery PRIVATE ambrosia-style-objects)

install(TARGETS ambrosia DESTINATION lib/qt6/plugins/styles)
install(TARGETS ambrosia-style-gallery DESTINATION lib/ambrosia)
