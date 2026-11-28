cmake_minimum_required(VERSION 3.25)
project(ambrosia-textedit VERSION 0.1.0 LANGUAGES CXX)

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

qt_add_executable(ambrosia-textedit
    src/main.cpp
    src/shadow.cpp src/shadow.h
)
target_compile_definitions(ambrosia-textedit PRIVATE TEXTEDIT_VERSION="${PROJECT_VERSION}")
set_source_files_properties(qml/Look.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
# The module is TextEditor: TextEdit is Qt Quick's own type.
# The About panel every app of ours shows, from one source (../kit).
set_source_files_properties(../kit/AboutWindow.qml PROPERTIES QT_RESOURCE_ALIAS AboutWindow.qml)
set_source_files_properties(../kit/About.qml PROPERTIES QT_RESOURCE_ALIAS About.qml QT_QML_SINGLETON_TYPE TRUE)
# The Settings window's opener and controls, likewise; what it sets.
set_source_files_properties(../kit/PrefCheck.qml PROPERTIES QT_RESOURCE_ALIAS PrefCheck.qml)
set_source_files_properties(../kit/PrefPopup.qml PROPERTIES QT_RESOURCE_ALIAS PrefPopup.qml)
set_source_files_properties(../kit/Preferences.qml PROPERTIES QT_RESOURCE_ALIAS Preferences.qml QT_QML_SINGLETON_TYPE TRUE)
# The Colors and Fonts panels (../kit; screencolor.h is the eyedropper).
set_source_files_properties(../kit/ColorPanel.qml PROPERTIES QT_RESOURCE_ALIAS ColorPanel.qml)
set_source_files_properties(../kit/Colors.qml PROPERTIES QT_RESOURCE_ALIAS Colors.qml QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(../kit/FontPanel.qml PROPERTIES QT_RESOURCE_ALIAS FontPanel.qml)
set_source_files_properties(../kit/Fonts.qml PROPERTIES QT_RESOURCE_ALIAS Fonts.qml QT_QML_SINGLETON_TYPE TRUE)
# The Print panel (../kit; printing.h is what it asks of CUPS).
set_source_files_properties(../kit/PrefRadio.qml PROPERTIES QT_RESOURCE_ALIAS PrefRadio.qml)
set_source_files_properties(../kit/PrintPanel.qml PROPERTIES QT_RESOURCE_ALIAS PrintPanel.qml)
set_source_files_properties(../kit/Printing.qml PROPERTIES QT_RESOURCE_ALIAS Printing.qml QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(../kit/SavePanel.qml PROPERTIES QT_RESOURCE_ALIAS SavePanel.qml)
set_source_files_properties(../kit/Saving.qml PROPERTIES QT_RESOURCE_ALIAS Saving.qml QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(qml/Prefs.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
qt_add_qml_module(ambrosia-textedit
    URI TextEditor
    VERSION 1.0
    SOURCES
        src/app.h src/app.cpp
        src/editor.h src/editor.cpp
        ../kit/screencolor.h
        ../kit/printing.h ../kit/printing.cpp
        ../kit/saving.h ../kit/saving.cpp
    QML_FILES
        ../kit/AboutWindow.qml
        ../kit/About.qml
        ../kit/PrefCheck.qml
        ../kit/PrefPopup.qml
        ../kit/Preferences.qml
        ../kit/ColorPanel.qml
        ../kit/Colors.qml
        ../kit/FontPanel.qml
        ../kit/Fonts.qml
        ../kit/PrefRadio.qml
        ../kit/PrintPanel.qml
        ../kit/Printing.qml
        ../kit/SavePanel.qml
        ../kit/Saving.qml
        qml/Prefs.qml
        qml/SettingsWindow.qml
        qml/Main.qml
        qml/EditorWindow.qml
        qml/Look.qml
        qml/Appearance.qml
        qml/MenuBar.qml
        qml/TrafficLights.qml
        qml/FormatBar.qml
        qml/Ruler.qml
        qml/FindBar.qml
        qml/Alert.qml
        qml/Segments.qml
        qml/PopUp.qml
        qml/SizeField.qml
        qml/ColorWell.qml
        qml/ColorPopup.qml
        qml/PopupMenu.qml
        qml/PushButton.qml
        qml/ScrollThumb.qml
        qml/Glyph.qml
        qml/Label.qml
        qml/glyphs.js
        qml/rtf.mjs
)

target_include_directories(ambrosia-textedit PRIVATE src ../kit)

target_link_libraries(ambrosia-textedit PRIVATE
    Qt6::Widgets Qt6::Quick Qt6::QuickControls2 Qt6::DBus Qt6::Pdf KF6::WindowSystem PkgConfig::CUPS
)

include(GNUInstallDirs)
install(TARGETS ambrosia-textedit RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
install(FILES org.ambrosia.textedit.desktop DESTINATION ${CMAKE_INSTALL_DATADIR}/applications)
