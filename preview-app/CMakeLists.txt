cmake_minimum_required(VERSION 3.25)
project(ambrosia-preview VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE RelWithDebInfo)
endif()

# Qt's own PDF library (PDFium inside; on Arch it comes with qt6-webengine),
# through its C++ classes only: the QtQuick.Pdf QML module leans on Qt Quick's
# private classes and breaks when its build and Qt's differ.
find_package(Qt6 6.8 REQUIRED COMPONENTS Core Gui Widgets Qml Quick QuickControls2 DBus Pdf)
find_package(KF6WindowSystem REQUIRED)
qt_standard_project_setup(REQUIRES 6.8)

qt_add_executable(ambrosia-preview
    src/main.cpp
    src/shadow.cpp src/shadow.h
    src/pages.cpp src/pages.h
)
target_compile_definitions(ambrosia-preview PRIVATE PREVIEW_VERSION="${PROJECT_VERSION}")
set_source_files_properties(qml/Look.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
# The About panel every app of ours shows, from one source (../kit).
set_source_files_properties(../kit/AboutWindow.qml PROPERTIES QT_RESOURCE_ALIAS AboutWindow.qml)
set_source_files_properties(../kit/About.qml PROPERTIES QT_RESOURCE_ALIAS About.qml QT_QML_SINGLETON_TYPE TRUE)
qt_add_qml_module(ambrosia-preview
    URI Preview
    VERSION 1.0
    SOURCES
        src/app.h src/app.cpp
        src/document.h src/document.cpp
    QML_FILES
        ../kit/AboutWindow.qml
        ../kit/About.qml
        qml/Main.qml
        qml/PreviewWindow.qml
        qml/Look.qml
        qml/Appearance.qml
        qml/MenuBar.qml
        qml/TrafficLights.qml
        qml/Capsule.qml
        qml/ToolButton.qml
        qml/SearchField.qml
        qml/PopupMenu.qml
        qml/Toolbar.qml
        qml/Sidebar.qml
        qml/PdfView.qml
        qml/ImageView.qml
        qml/PageImage.qml
        qml/ScrollThumb.qml
        qml/Glyph.qml
        qml/Label.qml
        qml/glyphs.js
        qml/view.mjs
)

target_include_directories(ambrosia-preview PRIVATE src)

target_link_libraries(ambrosia-preview PRIVATE
    Qt6::Widgets Qt6::Quick Qt6::QuickControls2 Qt6::DBus Qt6::Pdf KF6::WindowSystem
)

include(GNUInstallDirs)
install(TARGETS ambrosia-preview RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
install(FILES org.ambrosia.preview.desktop DESTINATION ${CMAKE_INSTALL_DATADIR}/applications)
