import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Notifications
import QtQuick
import Ambrosia

// Notification banners, top right. The shell is the session's notification
// server (plasmashell, which would be, doesn't run in Ambrosia). A banner
// slides in from the edge of the screen and leaves after a few seconds, or
// stays until closed when it's urgent; clicking it runs the notification's
// default action. Banners step aside while the control center is open.
// Focus (Do Not Disturb) holds back all but urgent ones; an app turned off in
// Settings is held back whatever it says; Settings' list of apps is those
// heard from here. Without previews a banner says only that there's one.
Scope {
    NotificationServer {
        id: server
        keepOnReload: true
        actionsSupported: true
        bodyMarkupSupported: true
        imageSupported: true
        onNotification: notification => {
            const entry = notification.desktopEntry ? DesktopEntries.byId(notification.desktopEntry) : null;
            const app = notification.appName || entry?.name || "";
            if (app !== "") {
                const heard = Settings.notificationApps.some(each => each.split("\t")[0] === app);
                if (!heard)
                    Settings.notificationApps = Settings.notificationApps.concat([`${app}\t${entry?.icon ?? notification.appIcon ?? ""}`]);
                if (Settings.notificationsOff.includes(app)) return;
            }
            if (Settings.doNotDisturb && notification.urgency !== NotificationUrgency.Critical) return;
            notification.tracked = true;
        }
    }

    PanelWindow {
        id: banners

        readonly property int bannerWidth: 344
        // Out past the screen's edge.
        readonly property int offscreen: bannerWidth + Theme.space.s6
        readonly property bool away: Popups.kind === "controlCenter" && Popups.screen === screen

        screen: Quickshell.screens[0] ?? null
        visible: server.trackedNotifications.values.length > 0 || leaving.running
        anchors { top: true; right: true }
        // Room for the shadow on the left and below; the right edge is the screen's.
        margins.top: Theme.space.s2
        implicitWidth: bannerWidth + Theme.space.s8 + Theme.space.s2
        implicitHeight: Math.max(1, stack.height + Theme.space.s8)
        exclusionMode: ExclusionMode.Normal
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "ambrosia-notifications"
        mask: Region { item: banners.away ? nothing : stack }
        BackgroundEffect.blurRegion: Region {
            regions: {
                stack.count;
                const list = [];
                if (banners.away) return list;
                const children = stack.contentItem.children;
                for (let i = 0; i < children.length; i++) {
                    if (children[i].blurArea) list.push(children[i].blurArea);
                }
                return list;
            }
        }

        Item { id: nothing }

        ListView {
            id: stack
            anchors { top: parent.top; right: parent.right; rightMargin: Theme.space.s2 }
            width: banners.bannerWidth
            height: contentHeight
            spacing: Theme.space.s2
            interactive: false
            model: server.trackedNotifications
            opacity: banners.away ? 0 : 1
            transform: Translate {
                x: banners.away ? banners.offscreen : 0
                Behavior on x { NumberAnimation { duration: banners.away ? Theme.exit.smooth.duration : Theme.spring.smooth.duration; easing.type: Easing.OutQuart } }
            }
            Behavior on opacity { NumberAnimation { duration: banners.away ? Theme.fade.fast : Theme.fade.base } }

            // In on the smooth spring, out on its quicker exit.
            add: Transition {
                NumberAnimation { property: "x"; from: banners.offscreen; duration: Theme.spring.smooth.duration; easing.type: Easing.OutQuart }
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.fade.base }
            }
            remove: Transition {
                id: leaving
                NumberAnimation { property: "x"; to: banners.offscreen; duration: Theme.exit.smooth.duration; easing.type: Easing.OutQuart }
                NumberAnimation { property: "opacity"; to: 0; duration: Theme.fade.fast }
            }
            displaced: Transition {
                NumberAnimation { property: "y"; duration: Theme.spring.smooth.duration; easing.type: Easing.OutQuart }
            }

            delegate: Item {
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

                // Its actions other than the default one (a click on the banner), as buttons.
                readonly property var buttons: modelData.actions.filter(a => a.identifier !== "default")

                width: banners.bannerWidth
                height: Math.max(row.implicitHeight + 2 * Theme.space.s3, 64)
                    + (buttons.length ? actions.height + Theme.space.s3 : 0)

                function invokeDefault() {
                    const action = modelData.actions.find(a => a.identifier === "default") ?? null;
                    if (action) action.invoke();
                    else modelData.dismiss();
                }

                // Leaves on its own unless urgent or the app says it never expires (0: a
                // pairing request waits for its answer, and expiring it would refuse); the
                // app may ask for longer. Quickshell gives the timeout in milliseconds.
                Timer {
                    running: banner.modelData.urgency !== NotificationUrgency.Critical
                        && banner.modelData.expireTimeout !== 0 && !area.containsMouse
                    interval: banner.modelData.expireTimeout > 0 ? banner.modelData.expireTimeout : 5000
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
                            text: Settings.notificationPreviews ? banner.modelData.summary : "Notification"
                            style: Theme.text.headline
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                        }
                        Label {
                            width: parent.width
                            visible: text !== ""
                            text: Settings.notificationPreviews ? banner.modelData.body : ""
                            color: Theme.color.label.secondary
                            wrapMode: Text.Wrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                            textFormat: Text.StyledText
                        }
                    }
                }

                Row {
                    id: actions
                    visible: banner.buttons.length > 0
                    x: Theme.space.s3
                    y: Math.max(row.implicitHeight + 2 * Theme.space.s3, 64)
                    width: parent.width - 2 * Theme.space.s3
                    spacing: Theme.space.s2

                    Repeater {
                        model: banner.buttons
                        PushButton {
                            required property var modelData
                            width: (actions.width - (banner.buttons.length - 1) * actions.spacing) / banner.buttons.length
                            text: modelData.text
                            onClicked: modelData.invoke()
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
