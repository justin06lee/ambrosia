pragma Singleton
import QtQuick

// Shows the app's Settings window (a PreferencesWindow.qml the app fills
// in): one for the app, brought forward if it is already up. An app's menu
// calls Preferences.show("Files", "SettingsWindow"), naming its QML module
// and the window's type in it.
QtObject {
    property var panel: null

    function show(module, type) {
        if (!panel) {
            const component = Qt.createComponent(module, type);
            if (component.status !== Component.Ready) {
                console.warn(component.errorString());
                return;
            }
            panel = component.createObject(null);
        }
        panel.show();
        panel.raise();
        panel.requestActivate();
    }
}
