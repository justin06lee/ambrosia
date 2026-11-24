cmake_minimum_required(VERSION 3.25)
project(ambrosia-input VERSION 0.1.0 LANGUAGES C)

# Ambrosia's input method for KWin: what lets the shell type into the app in
# front (the emoji picker's choice goes in at the insertion point, as on a
# Mac, with nothing put on the clipboard). KWin starts it as the session's
# input method (kwinrc's [Wayland] InputMethod names the desktop file here)
# and gives it alone the input-method protocol; it draws nothing and takes
# no keys. Only libwayland: no Qt.

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE RelWithDebInfo)
endif()

find_package(PkgConfig REQUIRED)
pkg_check_modules(WAYLAND REQUIRED IMPORTED_TARGET wayland-client)
pkg_get_variable(WAYLAND_PROTOCOLS wayland-protocols pkgdatadir)
find_program(WAYLAND_SCANNER wayland-scanner REQUIRED)

set(PROTOCOL "${WAYLAND_PROTOCOLS}/unstable/input-method/input-method-unstable-v1.xml")
add_custom_command(OUTPUT input-method-v1.h
    COMMAND "${WAYLAND_SCANNER}" client-header "${PROTOCOL}" input-method-v1.h
    DEPENDS "${PROTOCOL}" VERBATIM)
add_custom_command(OUTPUT input-method-v1.c
    COMMAND "${WAYLAND_SCANNER}" private-code "${PROTOCOL}" input-method-v1.c
    DEPENDS "${PROTOCOL}" VERBATIM)

add_executable(ambrosia-input src/main.c
    "${CMAKE_CURRENT_BINARY_DIR}/input-method-v1.c" "${CMAKE_CURRENT_BINARY_DIR}/input-method-v1.h")
target_include_directories(ambrosia-input PRIVATE "${CMAKE_CURRENT_BINARY_DIR}")
target_compile_options(ambrosia-input PRIVATE -Wall -Wextra)
target_link_libraries(ambrosia-input PRIVATE PkgConfig::WAYLAND)

install(TARGETS ambrosia-input DESTINATION lib/ambrosia)
install(FILES org.ambrosia.input.desktop DESTINATION share/applications)
