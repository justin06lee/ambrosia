cmake_minimum_required(VERSION 3.25)
project(ambrosia-activity-monitor VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE RelWithDebInfo)
endif()

find_package(Qt6 6.8 REQUIRED COMPONENTS Core Gui Widgets Qml Quick QuickControls2 DBus)
find_package(KF6WindowSystem REQUIRED)
# The launcher's apps: a process running an app's file takes its name and icon.
find_package(KF6Service REQUIRED)
qt_standard_project_setup(REQUIRES 6.8)

qt_add_executable(ambrosia-activity-monitor
    src/main.cpp
    src/shadow.cpp src/shadow.h
)
target_compile_definitions(ambrosia-activity-monitor PRIVATE MONITOR_VERSION="${PROJECT_VERSION}")
set_source_files_properties(qml/Look.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
# The About panel every app of ours shows, from one source (../kit).
set_source_files_properties(../kit/AboutWindow.qml PROPERTIES QT_RESOURCE_ALIAS AboutWindow.qml)
set_source_files_properties(../kit/About.qml PROPERTIES QT_RESOURCE_ALIAS About.qml QT_QML_SINGLETON_TYPE TRUE)
qt_add_qml_module(ambrosia-activity-monitor
    URI ActivityMonitor
    VERSION 1.0
    SOURCES
        src/app.h src/app.cpp
        src/sampler.h src/sampler.cpp
    QML_FILES
        ../kit/AboutWindow.qml
        ../kit/About.qml
        qml/Main.qml
        qml/MonitorWindow.qml
        qml/InspectorWindow.qml
        qml/Look.qml
        qml/Appearance.qml
        qml/MenuBar.qml
        qml/TrafficLights.qml
        qml/Capsule.qml
        qml/ToolButton.qml
        qml/Tabs.qml
        qml/SearchField.qml
        qml/PopupMenu.qml
        qml/Toolbar.qml
        qml/Table.qml
        qml/Panel.qml
        qml/StatRows.qml
        qml/Graph.qml
        qml/Alert.qml
        qml/PushButton.qml
        qml/ScrollThumb.qml
        qml/Glyph.qml
        qml/Label.qml
        qml/glyphs.js
        qml/monitor.mjs
)

target_include_directories(ambrosia-activity-monitor PRIVATE src)

target_link_libraries(ambrosia-activity-monitor PRIVATE
    Qt6::Widgets Qt6::Quick Qt6::QuickControls2 Qt6::DBus KF6::WindowSystem KF6::Service
)

include(GNUInstallDirs)
install(TARGETS ambrosia-activity-monitor RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
install(FILES org.ambrosia.activitymonitor.desktop DESTINATION ${CMAKE_INSTALL_DATADIR}/applications)
