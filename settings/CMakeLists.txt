cmake_minimum_required(VERSION 3.25)
project(ambrosia-settings VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE RelWithDebInfo)
endif()

find_package(Qt6 6.8 REQUIRED COMPONENTS Core Gui Widgets Qml Quick QuickControls2 DBus)
find_package(KF6WindowSystem REQUIRED)
find_package(KF6Config REQUIRED)
find_package(KF6PulseAudioQt REQUIRED)
find_package(KF6NetworkManagerQt REQUIRED)
find_package(KF6BluezQt REQUIRED)
find_package(KF6Screen REQUIRED)
find_package(PkgConfig REQUIRED)
pkg_check_modules(PULSE REQUIRED IMPORTED_TARGET libpulse)
qt_standard_project_setup(REQUIRES 6.8)

qt_add_executable(ambrosia-settings
    src/main.cpp
)
target_compile_definitions(ambrosia-settings PRIVATE SETTINGS_VERSION="${PROJECT_VERSION}")
set_source_files_properties(qml/Look.qml qml/Panes.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
qt_add_qml_module(ambrosia-settings
    URI Settings
    VERSION 1.0
    SOURCES
        src/app.h src/app.cpp
        src/about.h src/about.cpp
        src/sound.h src/sound.cpp
        src/wifi.h src/wifi.cpp
        src/bluetooth.h src/bluetooth.cpp
        src/network.h src/network.cpp
        src/displays.h src/displays.cpp
    QML_FILES
        qml/SettingsWindow.qml
        qml/MenuBar.qml
        qml/Appearance.qml
        qml/Look.qml
        qml/Panes.qml
        qml/Label.qml
        qml/Glyph.qml
        qml/glyphs.js
        qml/PaneIcon.qml
        qml/TrafficLights.qml
        qml/Sidebar.qml
        qml/SearchField.qml
        qml/Toolbar.qml
        qml/Capsule.qml
        qml/Page.qml
        qml/HeaderBox.qml
        qml/SectionHeading.qml
        qml/Box.qml
        qml/FormRow.qml
        qml/NavRow.qml
        qml/Switch.qml
        qml/PopUpButton.qml
        qml/PopupMenu.qml
        qml/Slider.qml
        qml/Segmented.qml
        qml/PushButton.qml
        qml/HelpButton.qml
        qml/NameField.qml
        qml/GeneralPage.qml
        qml/AboutPage.qml
        qml/ControlsPage.qml
        qml/SoundPage.qml
        qml/CheckBox.qml
        qml/DeviceTable.qml
        qml/LevelMeter.qml
        qml/Spinner.qml
        qml/NetworkSignal.qml
        qml/NetworkRow.qml
        qml/WiFiPage.qml
        qml/BluetoothPage.qml
        qml/DeviceRow.qml
        qml/NetworkPage.qml
        qml/ServiceRow.qml
        qml/DisplaysPage.qml
        qml/ScaleTile.qml
        qml/Sheet.qml
        qml/WiFiDetailsSheet.qml
        qml/EditList.qml
    RESOURCES
        art/desktop.svg
        art/laptop.svg
        art/drive.svg
)

target_include_directories(ambrosia-settings PRIVATE src)

target_link_libraries(ambrosia-settings PRIVATE
    Qt6::Widgets Qt6::Quick Qt6::QuickControls2 Qt6::DBus KF6::WindowSystem
    KF6::ConfigCore KF6::PulseAudioQt KF6::NetworkManagerQt KF6::BluezQt KF6::Screen PkgConfig::PULSE
)

include(GNUInstallDirs)
install(TARGETS ambrosia-settings RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
install(FILES org.ambrosia.settings.desktop DESTINATION ${CMAKE_INSTALL_DATADIR}/applications)
