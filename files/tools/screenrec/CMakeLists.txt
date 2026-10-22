cmake_minimum_required(VERSION 3.22)
project(screenrec LANGUAGES CXX)
# A screen recorder for Files' demo videos: the desktop portal's screencast,
# encoded by KPipeWire. A development tool; it isn't packaged.
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_AUTOMOC ON)
find_package(Qt6 REQUIRED COMPONENTS Core DBus Gui)
find_package(KPipeWire REQUIRED)
add_executable(screenrec main.cpp)
target_link_libraries(screenrec Qt6::Core Qt6::DBus Qt6::Gui K::KPipeWireRecord)
