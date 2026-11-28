cmake_minimum_required(VERSION 3.25)
project(ambrosia-calculator VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE RelWithDebInfo)
endif()

find_package(Qt6 6.8 REQUIRED COMPONENTS Core Gui Widgets Qml Quick QuickControls2)
find_package(KF6WindowSystem REQUIRED)
qt_standard_project_setup(REQUIRES 6.8)

qt_add_executable(ambrosia-calculator
    src/main.cpp
    src/shadow.cpp src/shadow.h
)
target_compile_definitions(ambrosia-calculator PRIVATE CALCULATOR_VERSION="${PROJECT_VERSION}")
# The About panel every app of ours shows, from one source (../kit).
set_source_files_properties(../kit/AboutWindow.qml PROPERTIES QT_RESOURCE_ALIAS AboutWindow.qml)
set_source_files_properties(../kit/About.qml PROPERTIES QT_RESOURCE_ALIAS About.qml QT_QML_SINGLETON_TYPE TRUE)
qt_add_qml_module(ambrosia-calculator
    URI Calculator
    VERSION 1.0
    SOURCES
        src/app.h src/app.cpp
    QML_FILES
        ../kit/AboutWindow.qml
        ../kit/About.qml
        qml/CalculatorWindow.qml
        qml/Key.qml
        qml/MenuBar.qml
        qml/calc.mjs
)

target_include_directories(ambrosia-calculator PRIVATE src)

target_link_libraries(ambrosia-calculator PRIVATE
    Qt6::Widgets Qt6::Quick Qt6::QuickControls2 KF6::WindowSystem
)
# A window's place is kept by a private part of Qt (../kit/placing.h):
# without its headers the app builds the same and windows open anywhere.
find_package(Qt6 QUIET COMPONENTS GuiPrivate)
if(TARGET Qt6::GuiPrivate)
    target_link_libraries(ambrosia-calculator PRIVATE Qt6::GuiPrivate)
endif()

include(GNUInstallDirs)
install(TARGETS ambrosia-calculator RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
install(FILES org.ambrosia.calculator.desktop DESTINATION ${CMAKE_INSTALL_DATADIR}/applications)
