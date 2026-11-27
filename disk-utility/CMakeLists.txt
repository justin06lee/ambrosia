cmake_minimum_required(VERSION 3.25)
project(ambrosia-disk-utility VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE RelWithDebInfo)
endif()

find_package(Qt6 6.8 REQUIRED COMPONENTS Core Gui Widgets Qml Quick QuickControls2 DBus)
find_package(KF6WindowSystem REQUIRED)
qt_standard_project_setup(REQUIRES 6.8)

qt_add_executable(ambrosia-disk-utility
    src/main.cpp
    src/shadow.cpp src/shadow.h
)
target_compile_definitions(ambrosia-disk-utility PRIVATE DISKUTILITY_VERSION="${PROJECT_VERSION}")
set_source_files_properties(qml/Look.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
# The About panel every app of ours shows and the pop-up button of their
# Settings windows, from one source (../kit).
set_source_files_properties(../kit/AboutWindow.qml PROPERTIES QT_RESOURCE_ALIAS AboutWindow.qml)
set_source_files_properties(../kit/About.qml PROPERTIES QT_RESOURCE_ALIAS About.qml QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(../kit/PrefPopup.qml PROPERTIES QT_RESOURCE_ALIAS PrefPopup.qml)
qt_add_qml_module(ambrosia-disk-utility
    URI DiskUtility
    VERSION 1.0
    SOURCES
        src/app.h src/app.cpp
        src/disks.h src/disks.cpp
    QML_FILES
        ../kit/AboutWindow.qml
        ../kit/About.qml
        ../kit/PrefPopup.qml
        qml/Main.qml
        qml/DiskUtilityWindow.qml
        qml/InfoWindow.qml
        qml/Look.qml
        qml/Appearance.qml
        qml/MenuBar.qml
        qml/TrafficLights.qml
        qml/Capsule.qml
        qml/ToolButton.qml
        qml/Toolbar.qml
        qml/Sidebar.qml
        qml/DiskPage.qml
        qml/DiskIcon.qml
        qml/Sheets.qml
        qml/PushButton.qml
        qml/ScrollThumb.qml
        qml/Glyph.qml
        qml/Label.qml
        qml/glyphs.js
        qml/disks.mjs
)

target_include_directories(ambrosia-disk-utility PRIVATE src)

target_link_libraries(ambrosia-disk-utility PRIVATE
    Qt6::Widgets Qt6::Quick Qt6::QuickControls2 Qt6::DBus KF6::WindowSystem
)

include(GNUInstallDirs)
install(TARGETS ambrosia-disk-utility RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
install(FILES org.ambrosia.diskutility.desktop DESTINATION ${CMAKE_INSTALL_DATADIR}/applications)
