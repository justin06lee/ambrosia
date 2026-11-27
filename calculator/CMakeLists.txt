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
qt_add_qml_module(ambrosia-calculator
    URI Calculator
    VERSION 1.0
    SOURCES
        src/app.h src/app.cpp
    QML_FILES
        qml/CalculatorWindow.qml
        qml/Key.qml
        qml/MenuBar.qml
        qml/calc.mjs
)

target_include_directories(ambrosia-calculator PRIVATE src)

target_link_libraries(ambrosia-calculator PRIVATE
    Qt6::Widgets Qt6::Quick Qt6::QuickControls2 KF6::WindowSystem
)

include(GNUInstallDirs)
install(TARGETS ambrosia-calculator RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
install(FILES org.ambrosia.calculator.desktop DESTINATION ${CMAKE_INSTALL_DATADIR}/applications)
