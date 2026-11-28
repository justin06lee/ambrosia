cmake_minimum_required(VERSION 3.25)
project(ambrosia-notes VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE RelWithDebInfo)
endif()

# Pdf: the Print panel's pages (on Arch it comes with qt6-webengine).
find_package(Qt6 6.8 REQUIRED COMPONENTS Core Gui Widgets Qml Quick QuickControls2 DBus Pdf)
find_package(KF6WindowSystem REQUIRED)
find_package(PkgConfig REQUIRED)
pkg_check_modules(CUPS REQUIRED IMPORTED_TARGET cups)
qt_standard_project_setup(REQUIRES 6.8)

qt_add_executable(ambrosia-notes
    src/main.cpp
    src/shadow.cpp src/shadow.h
)
target_compile_definitions(ambrosia-notes PRIVATE NOTES_VERSION="${PROJECT_VERSION}")
set_source_files_properties(qml/Look.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
# The About panel every app of ours shows and their Settings window with
# its controls, from one source (../kit); what the Settings set.
set_source_files_properties(../kit/AboutWindow.qml PROPERTIES QT_RESOURCE_ALIAS AboutWindow.qml)
set_source_files_properties(../kit/About.qml PROPERTIES QT_RESOURCE_ALIAS About.qml QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(../kit/PreferencesWindow.qml PROPERTIES QT_RESOURCE_ALIAS PreferencesWindow.qml)
set_source_files_properties(../kit/PrefCheck.qml PROPERTIES QT_RESOURCE_ALIAS PrefCheck.qml)
set_source_files_properties(../kit/PrefPopup.qml PROPERTIES QT_RESOURCE_ALIAS PrefPopup.qml)
set_source_files_properties(../kit/Preferences.qml PROPERTIES QT_RESOURCE_ALIAS Preferences.qml QT_QML_SINGLETON_TYPE TRUE)
# The Print panel (../kit; printing.h is what it asks of CUPS).
set_source_files_properties(../kit/PrefRadio.qml PROPERTIES QT_RESOURCE_ALIAS PrefRadio.qml)
set_source_files_properties(../kit/PrintPanel.qml PROPERTIES QT_RESOURCE_ALIAS PrintPanel.qml)
set_source_files_properties(../kit/Printing.qml PROPERTIES QT_RESOURCE_ALIAS Printing.qml QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(../kit/SavePanel.qml PROPERTIES QT_RESOURCE_ALIAS SavePanel.qml)
set_source_files_properties(../kit/Saving.qml PROPERTIES QT_RESOURCE_ALIAS Saving.qml QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(qml/Prefs.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
qt_add_qml_module(ambrosia-notes
    URI Notes
    VERSION 1.0
    SOURCES
        src/app.h src/app.cpp
        src/store.h src/store.cpp
        src/editor.h src/editor.cpp
        ../kit/printing.h ../kit/printing.cpp
        ../kit/saving.h ../kit/saving.cpp
    QML_FILES
        ../kit/AboutWindow.qml
        ../kit/About.qml
        ../kit/PreferencesWindow.qml
        ../kit/PrefCheck.qml
        ../kit/PrefPopup.qml
        ../kit/Preferences.qml
        ../kit/PrefRadio.qml
        ../kit/PrintPanel.qml
        ../kit/Printing.qml
        ../kit/SavePanel.qml
        ../kit/Saving.qml
        qml/Prefs.qml
        qml/SettingsWindow.qml
        qml/Main.qml
        qml/NotesWindow.qml
        qml/Look.qml
        qml/Appearance.qml
        qml/MenuBar.qml
        qml/TrafficLights.qml
        qml/Capsule.qml
        qml/ToolButton.qml
        qml/Toolbar.qml
        qml/Sidebar.qml
        qml/NoteList.qml
        qml/NotePane.qml
        qml/FormatMenu.qml
        qml/FindBar.qml
        qml/Alert.qml
        qml/PushButton.qml
        qml/ScrollThumb.qml
        qml/Glyph.qml
        qml/Label.qml
        qml/glyphs.js
        qml/notes.mjs
)

target_include_directories(ambrosia-notes PRIVATE src ../kit)

target_link_libraries(ambrosia-notes PRIVATE
    Qt6::Widgets Qt6::Quick Qt6::QuickControls2 Qt6::DBus Qt6::Pdf KF6::WindowSystem PkgConfig::CUPS
)
# A window's place is kept by a private part of Qt (../kit/placing.h):
# without its headers the app builds the same and windows open anywhere.
find_package(Qt6 QUIET COMPONENTS GuiPrivate)
if(TARGET Qt6::GuiPrivate)
    target_link_libraries(ambrosia-notes PRIVATE Qt6::GuiPrivate)
endif()

include(GNUInstallDirs)
install(TARGETS ambrosia-notes RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
install(FILES org.ambrosia.notes.desktop DESTINATION ${CMAKE_INSTALL_DATADIR}/applications)
