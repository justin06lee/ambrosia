cmake_minimum_required(VERSION 3.25)
project(ambrosia-files VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE RelWithDebInfo)
endif()

find_package(Qt6 6.8 REQUIRED COMPONENTS Core Gui Widgets Qml Quick QuickControls2 DBus Concurrent Svg)
find_package(KF6KIO REQUIRED)
find_package(KF6Service REQUIRED)
find_package(KF6WindowSystem REQUIRED)
qt_standard_project_setup(REQUIRES 6.8)

qt_add_executable(ambrosia-files
    src/main.cpp
)
target_compile_definitions(ambrosia-files PRIVATE FILES_VERSION="${PROJECT_VERSION}")
set_source_files_properties(qml/Finder.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
qt_add_qml_module(ambrosia-files
    URI Files
    VERSION 1.0
    SOURCES
        src/app.h src/app.cpp
        src/fileops.h src/fileops.cpp
        src/foldermodel.h src/foldermodel.cpp
        src/iteminfo.h src/iteminfo.cpp
        src/format.h src/format.cpp
        src/places.h src/places.cpp
        src/sortkey.h src/sortkey.cpp
    QML_FILES
        qml/FinderWindow.qml
        qml/Appearance.qml
        qml/QuickLook.qml
        qml/InfoWindow.qml
        qml/InfoSection.qml
        qml/MenuBar.qml
        qml/Finder.qml
        qml/Sidebar.qml
        qml/SidebarFlush.qml
        qml/SidebarList.qml
        qml/RenameField.qml
        qml/Toolbar.qml
        qml/Capsule.qml
        qml/ToolButton.qml
        qml/Label.qml
        qml/TrafficLights.qml
        qml/ListPane.qml
        qml/IconPane.qml
        qml/ColumnPane.qml
        qml/GalleryPane.qml
        qml/PreviewPane.qml
        qml/Thumbnail.qml
        qml/PathBar.qml
        qml/FileIcon.qml
        qml/Glyph.qml
        qml/glyphs.js
    RESOURCES
        art/folder.svg
        art/document.svg
        art/document-small.svg
)

target_include_directories(ambrosia-files PRIVATE src)

target_link_libraries(ambrosia-files PRIVATE
    Qt6::Widgets Qt6::Quick Qt6::QuickControls2 Qt6::DBus Qt6::Concurrent Qt6::Svg
    KF6::KIOGui KF6::KIOWidgets KF6::Service KF6::WindowSystem
)

include(GNUInstallDirs)
install(TARGETS ambrosia-files RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
install(FILES org.ambrosia.files.desktop DESTINATION ${CMAKE_INSTALL_DATADIR}/applications)
# Files runs from login, as Finder does: a user unit for the Ambrosia session,
# wanted by Plasma's workspace target (installed enabled, like the shell's).
install(FILES ambrosia-files.service DESTINATION lib/systemd/user)
install(CODE "
    set(wants \"\$ENV{DESTDIR}\${CMAKE_INSTALL_PREFIX}/lib/systemd/user/plasma-workspace.target.wants\")
    file(MAKE_DIRECTORY \"\${wants}\")
    file(CREATE_LINK ../ambrosia-files.service \"\${wants}/ambrosia-files.service\" SYMBOLIC)
")
