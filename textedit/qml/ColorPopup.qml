import QtQuick
import QtQuick.Controls.Basic as Controls
import QtQuick.Effects
import Ambrosia
import TextEditor

// The colors a well offers, in a panel under it: a click takes one. The
// one in use has a ring; "" among them is none (a highlighter's), drawn as
// an empty cell with a stroke through it.
Controls.Popup {
    id: popup

    property var colors: []
    property string current: ""
    property int columns: 8
    signal chosen(string color)

    function openUnder(control) {
        parent = control;
        x = 0;
        y = control.height + 4;
        open();
    }

    padding: 9
    margins: 6
    closePolicy: Controls.Popup.CloseOnEscape | Controls.Popup.CloseOnPressOutside
    background: Rectangle {
        radius: 10
        color: Look.menu
        border.width: 0.5
        border.color: Look.menuRim
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "black"
            shadowOpacity: Theme.dark ? 0.5 : 0.2
            shadowBlur: 0.8
            shadowVerticalOffset: 4
            blurMax: 24
        }
    }
    contentItem: Grid {
        columns: popup.columns
        spacing: 5
        Repeater {
            model: popup.colors
            Rectangle {
                id: cell
                required property string modelData
                readonly property bool none: modelData === ""
                width: 20
                height: 20
                radius: 5
                color: none ? "transparent" : modelData
                border.width: 0.5
                border.color: Theme.dark ? "#40ffffff" : "#30000000"

                // None: a stroke corner to corner.
                Rectangle {
                    visible: cell.none
                    anchors.centerIn: parent
                    width: 22
                    height: 1.5
                    rotation: -45
                    color: "#ff453a"
                    antialiasing: true
                }
                // The one in use.
                Rectangle {
                    visible: popup.current.toLowerCase() === cell.modelData.toLowerCase()
                    anchors.fill: parent
                    anchors.margins: -3
                    radius: 8
                    color: "transparent"
                    border.width: 2
                    border.color: Theme.accent.bg
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        popup.close();
                        popup.chosen(cell.modelData);
                    }
                }
            }
        }
    }
}
