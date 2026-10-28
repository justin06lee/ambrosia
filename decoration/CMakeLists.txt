cmake_minimum_required(VERSION 3.25)
project(ambrosia-decoration VERSION 0.1.0 LANGUAGES CXX)

# Ambrosia's window frame for KWin: the titlebar and the traffic lights on
# every window KWin decorates. Sizes and colors come from the tokens, through
# dist/kdecoration/tokens.h (bun tools/gen/index.ts).

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE RelWithDebInfo)
endif()

find_package(Qt6 6.8 REQUIRED COMPONENTS Core Gui)
find_package(KDecoration3 REQUIRED)
find_package(KF6CoreAddons REQUIRED)

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
