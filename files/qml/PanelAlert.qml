import QtQuick
import QtQuick.Effects
import Ambrosia

// The window asking before it does something that can't be taken back (a
// Save panel writing over a file, a tag deleted): the window dims and a
// card asks, Cancel the default as on a Mac.
Rectangle {
    id: alert

    required property var finder
    property string name
    property string title
    property string detail
    property string acceptText
    // What the other button does; replaced() when it is null.
    property var then: null
    signal replaced()

    function ask(name, folderName) {
        alert.name = name;
        question("“" + name + "” already exists. Do you want to replace it?",
                 "A file or folder with the same name already exists in the folder " + folderName
                 + ". Replacing it will overwrite its current contents.", "Replace", null);
    }
    function question(title, detail, acceptText, then) {
        alert.title = title;
        alert.detail = detail;
        alert.acceptText = acceptText;
        alert.then = then;
        visible = true;
        card.forceActiveFocus();
    }
    function dismiss() {
        visible = false;
        finder.panelFocus();
    }

    visible: false
    radius: Finder.windowRadius
    color: Theme.dark ? "#66000000" : "#33000000"
    // Nothing under the card takes a click while it asks.
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onWheel: (wheel) => wheel.accepted = true }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: 260
        height: column.height + 36
        radius: 20
        color: Theme.dark ? "#2e2e2b" : "#f6f6f6"
        border.width: 0.5
        border.color: Theme.dark ? "#33ffffff" : "#26000000"
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "black"
            shadowOpacity: 0.3
            shadowBlur: 1
            shadowVerticalOffset: 8
            blurMax: 48
        }
        Keys.onReturnPressed: alert.dismiss()
        Keys.onEnterPressed: alert.dismiss()
        Keys.onEscapePressed: alert.dismiss()

        Column {
            id: column
            x: 18
            y: 18
            width: parent.width - 36
            spacing: 10
            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: alert.title
                style: Theme.text.headline
            }
            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: alert.detail
                style: Theme.text.caption
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                topPadding: 6
                spacing: 10
                PushButton {
                    width: (column.width - 10) / 2
                    text: alert.acceptText
                    onClicked: {
                        const then = alert.then;
                        alert.then = null;
                        if (then) {
                            alert.dismiss();
                            then();
                        } else {
                            alert.visible = false;
                            alert.replaced();
                        }
                    }
                }
                PushButton {
                    width: (column.width - 10) / 2
                    primary: true
                    text: "Cancel"
                    onClicked: alert.dismiss()
                }
            }
        }
    }
}
