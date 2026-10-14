import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Notifications
import QtQuick
import Ambrosia

// Notification banners, top right. The shell is the session's notification
// server (plasmashell, which would be, doesn't run in Ambrosia). A banner
// leaves after a few seconds, or stays until closed when it's urgent;
// clicking it runs the notification's default action. Focus (Do Not
// Disturb) holds back all but urgent ones.
Scope {
    NotificationServer {
        id: server
        keepOnReload: true
        actionsSupported: true
        bodyMarkupSupported: true
        imageSupported: true
        onNotification: notification => {
            if (Settings.doNotDisturb && notification.urgency !== NotificationUrgency.Critical) return;
            notification.tracked = true;
        }
    }

    PanelWindow {
        id: banners

        readonly property int bannerWidth: 344

        screen: Quickshell.screens[0] ?? null
        visible: server.trackedNotifications.values.length > 0
        anchors { top: true; right: true }
        // Room for the shadow on the left and below; the right edge is the screen's.
        margins.top: Theme.space.s2
        implicitWidth: bannerWidth + Theme.space.s8 + Theme.space.s2
        implicitHeight: Math.max(1, stack.height + Theme.space.s8)
        exclusionMode: ExclusionMode.Normal
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "ambrosia-notifications"
        mask: Region { item: stack }
        BackgroundEffect.blurRegion: Region {
            regions: {
                const list = [];
                for (let i = 0; i < repeater.count; i++) {
                    const banner = repeater.itemAt(i);
                    if (banner) list.push(banner.blurArea);
                }
                return list;
            }
        }

        Column {
            id: stack
            anchors { top: parent.top; right: parent.right; rightMargin: Theme.space.s2 }
            spacing: Theme.space.s2

            Repeater {
                id: repeater
                model: server.trackedNotifications

                Item {
                    id: banner
                    required property var modelData
                    readonly property Region blurArea: Region { item: banner; radius: Theme.radius.panel }
                    readonly property var entry: modelData.desktopEntry ? DesktopEntries.byId(modelData.desktopEntry) : DesktopEntries.heuristicLookup(modelData.appName)
                    // The notification's own picture, else its app's icon.
                    readonly property string iconSource: {
                        const icon = modelData.appIcon;
                        if (modelData.image) return modelData.image;
                        if (icon.startsWith("/")) return "file://" + icon;
                        if (icon.includes("://")) return icon;
                        return (icon ? Quickshell.iconPath(icon, true) : "") || Quickshell.iconPath(entry?.icon ?? "", "dialog-information");
                    }

                    width: banners.bannerWidth
                    height: Math.max(row.implicitHeight + 2 * Theme.space.s3, 64)

                    function invokeDefault() {
                        const action = modelData.actions.find(a => a.identifier === "default") ?? null;
                        if (action) action.invoke();
                        else modelData.dismiss();
                    }

                    // Leaves on its own unless urgent; the app may ask for longer.
                    Timer {
                        running: banner.modelData.urgency !== NotificationUrgency.Critical && !area.containsMouse
                        interval: banner.modelData.expireTimeout > 0 ? banner.modelData.expireTimeout * 1000 : 5000
                        onTriggered: banner.modelData.expire()
                    }

                    Glass {
                        anchors.fill: parent
                        tint: Theme.color.material.regular.tint
                        radius: Theme.radius.panel
                        shadow: Theme.color.shadow.panel
                    }

                    MouseArea {
                        id: area
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: banner.invokeDefault()
                    }

                    Row {
                        id: row
                        x: Theme.space.s3
                        y: Theme.space.s3
                        width: parent.width - Theme.space.s3 - Theme.space.s4
                        spacing: Theme.space.s3

                        IconImage {
                            implicitSize: 36
                            source: banner.iconSource
                        }

                        Column {
                            width: row.width - 36 - row.spacing

                            Item {
                                width: parent.width
                                height: appName.implicitHeight

                                Label {
                                    id: appName
                                    text: (banner.modelData.appName || banner.entry?.name || "").toUpperCase()
                                    style: Theme.text.footnote
                                    font.weight: Font.DemiBold
                                    font.letterSpacing: 0.4
                                    color: Theme.color.label.secondary
                                }
                                Label {
                                    anchors.right: parent.right
                                    text: "now"
                                    style: Theme.text.caption
                                    color: Theme.color.label.secondary
                                }
                            }
                            Label {
                                width: parent.width
                                text: banner.modelData.summary
                                style: Theme.text.headline
                                elide: Text.ElideRight
                                textFormat: Text.PlainText
                            }
                            Label {
                                width: parent.width
                                visible: text !== ""
                                text: banner.modelData.body
                                color: Theme.color.label.secondary
                                wrapMode: Text.Wrap
                                maximumLineCount: 3
                                elide: Text.ElideRight
                                textFormat: Text.StyledText
                            }
                        }
                    }

                    // Close: shown on hover, top left, as on a Mac.
                    Rectangle {
                        visible: area.containsMouse
                        x: -6
                        y: -6
                        width: 18
                        height: 18
                        radius: 9
                        color: Theme.color.bg.elevated
                        border.width: 0.5
                        border.color: Theme.color.glass.edge

                        Label {
                            anchors.centerIn: parent
                            text: "×"
                            style: Theme.text.callout
                            color: Theme.color.label.secondary
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: banner.modelData.dismiss()
                        }
                    }
                }
            }
        }
    }
}
