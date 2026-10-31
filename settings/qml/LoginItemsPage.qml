import QtQuick
import Ambrosia
import Settings

// General › Login Items: what opens at login, added from the apps there are.
// Left out: App Background Activity (services and timers are the system's to
// run, not a list to switch off here), Extensions, and the help button.
Page {
    id: page

    SectionHeading {
        first: true
        text: qsTr("Open at Login")
    }
    Label {
        x: Look.boxPadding
        style: Theme.text.caption
        color: Theme.color.label.secondary
        text: qsTr("These items will open automatically when you log in.")
    }
    PickList {
        title: qsTr("Item")
        column: qsTr("Kind")
        detail: qsTr("Application")
        items: LoginItems.items
        onAddRequested: chooser.open = true
        onRemoveRequested: (value) => LoginItems.remove(value)
    }

    ChooserSheet {
        id: chooser
        settings: page.settings
        title: qsTr("Select an app to open at login")
        items: LoginItems.apps
        onPicked: (value) => LoginItems.add(value)
    }
}
