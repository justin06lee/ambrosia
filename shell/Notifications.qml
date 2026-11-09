import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import QtQuick
import Ambrosia

// Notification banners, top right; NotificationStore keeps what they show.
// A banner slides in from the edge of the screen and leaves after a few
// seconds, or stays until answered when it's urgent or its app says it never
// expires; clicking it runs the notification's default action. Banners step
// aside while the control center or the notification center is open.
Scope {
    // Built afresh per first screen, as the menu bar is per screen: a window
    // whose screen goes away (a monitor unplugged, a switch to a console)
    // doesn't come back on its own. The store stays, and with it the
    // banners being shown.
    Variants {
        model: Quickshell.screens.slice(0, 1)

        PanelWindow {
            id: banners

            required property ShellScreen modelData

            readonly property int bannerWidth: 344
            // Out past the screen's edge.
            readonly property int offscreen: bannerWidth + Theme.space.s6
            readonly property bool away: (Popups.kind === "controlCenter" || Popups.kind === "notificationCenter") && Popups.screen === screen

            screen: modelData
            visible: NotificationStore.banners.count > 0 || leaving.running
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
                model: NotificationStore.banners
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

                delegate: NotificationCard {
                    id: banner
                    required property int nid
                    readonly property var notification: NotificationStore.live(nid)
                    readonly property Region blurArea: Region { item: banner; radius: Theme.radius.panel }
                    readonly property var entry: notification ? NotificationStore.entryOf(notification) : null

                    width: banners.bannerWidth
                    appName: notification?.appName || entry?.name || ""
                    iconSource: notification ? NotificationStore.iconOf(notification, entry) : ""
                    summary: notification?.summary ?? ""
                    body: notification?.body ?? ""
                    // Its actions other than the default one (a click on the banner).
                    buttons: notification ? notification.actions.filter(a => a.identifier !== "default") : []

                    onActivated: NotificationStore.openLive(nid)
                    onCloseClicked: notification?.dismiss()

                    // Leaves on its own unless urgent or the app says it never expires (0: a
                    // pairing request waits for its answer, and expiring it would refuse); the
                    // app may ask for longer. Quickshell gives the timeout in milliseconds.
                    Timer {
                        running: banner.notification !== null
                            && banner.notification.urgency !== NotificationUrgency.Critical
                            && banner.notification.expireTimeout !== 0 && !banner.hovered
                        interval: banner.notification?.expireTimeout > 0 ? banner.notification.expireTimeout : 5000
                        onTriggered: NotificationStore.bannerDone(banner.nid)
                    }
                }
            }
        }
    }
}
