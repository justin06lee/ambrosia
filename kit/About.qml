pragma Singleton
import QtQuick

// Shows the app's About panel (AboutWindow.qml): one for the app, brought
// forward if it is already up. An app's menu calls
// About.show("TextEdit", "org.ambrosia.textedit").
QtObject {
    property var panel: null
    property Component window: Component { AboutWindow {} }

    function show(name, icon) {
        if (!panel)
            panel = window.createObject(null, { name: name, icon: icon, version: Qt.application.version });
        panel.show();
        panel.raise();
        panel.requestActivate();
    }
}
