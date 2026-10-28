import Quickshell
import Quickshell.Wayland
import Quickshell.Networking
import Quickshell.Services.UPower
import QtQuick
import Ambrosia

// The menu bar: the Ambrosia menu, the focused app's name and its own menus
// on the left; status, search, the control center and the clock on the
// right. Menus open on press, and once one is open, moving along the titles
// switches to theirs. Thin glass: the material's tint over the compositor's
// blur.
PanelWindow {
    id: bar

    // The focused app's menus, as it publishes them over DBus. Apps that
    // don't get a Window menu of ours.
    readonly property var appEntries: appMenu.item?.entries ?? []
    readonly property bool hasAppMenu: Apps.activeName !== "" && appEntries.length > 0
    readonly property var appTitles: hasAppMenu ? appEntries : []
    readonly property bool appHasWindowMenu: appTitles.some(entry => entry.text === "Window")

    anchors { top: true; left: true; right: true }
    implicitHeight: Theme.size.menubar.height
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "ambrosia-menubar"
    BackgroundEffect.blurRegion: Region { item: glass }

    Loader {
        id: appMenu
        source: "file://" + Quickshell.shellDir + "/AppMenu.qml"
        onLoaded: {
            item.service = Qt.binding(() => Apps.menuService);
            item.path = Qt.binding(() => Apps.menuPath);
        }
    }

    function ambrosiaMenu() {
        return [
            { text: "About This Computer", action: () => Session.settings("about") },
            { separator: true },
            { text: "System Settings…", action: () => Session.settings() },
            { separator: true },
            { text: "Force Quit…", action: () => Session.forceQuit() },
            { separator: true },
            { text: "Sleep", action: () => Session.sleep() },
            { text: "Restart…", action: () => Popups.confirm(bar.screen, {
                title: "Are you sure you want to restart your computer now?",
                text: "Open apps are asked to close first.", accept: "Restart", action: () => Session.restart() }) },
            { text: "Shut Down…", action: () => Popups.confirm(bar.screen, {
                title: "Are you sure you want to shut down your computer now?",
                text: "Open apps are asked to close first.", accept: "Shut Down", action: () => Session.shutDown() }) },
            { separator: true },
            { text: "Lock Screen", action: () => Session.lock() },
            { text: `Log Out ${Session.userName}…`, action: () => Popups.confirm(bar.screen, {
                title: "Are you sure you want to quit all apps and log out now?",
                accept: "Log Out", action: () => Session.logOut() }) },
        ];
    }

    // The bold menu named for the app. With nothing focused it's the file
    // manager's, as the Mac shows Finder's.
    function appNameMenu() {
        if (Apps.activeName === "") return [
            { text: "New Window", action: () => Session.launch("org.ambrosia.files") },
            { separator: true },
            { text: "Settings…", action: () => Session.settings() },
        ];
        const row = Apps.activeRow;
        return [
            { text: `Hide ${Apps.activeName}`, action: () => Apps.hide(row) },
            { separator: true },
            { text: `Quit ${Apps.activeName}`, action: () => Apps.quit(row) },
        ];
    }

    function windowMenu() {
        const window = Apps.focusedWindow();
        const any = window.row >= 0;
        return [
            { text: "Minimize", enabled: any, action: () => Apps.minimizeWindow(window) },
            { text: "Zoom", enabled: any, action: () => Apps.zoomWindow(window) },
            { text: "Enter Full Screen", enabled: any, action: () => Apps.fullScreenWindow(window) },
            { separator: true },
            { text: "Close Window", enabled: any, action: () => Apps.closeWindow(window) },
        ];
    }

    function goMenu() {
        const home = Quickshell.env("HOME");
        return [
            { text: "Home", action: () => Session.open(home) },
            { text: "Desktop", action: () => Session.open(home + "/Desktop") },
            { text: "Documents", action: () => Session.open(home + "/Documents") },
            { text: "Downloads", action: () => Session.open(home + "/Downloads") },
            { separator: true },
            { text: "Trash", action: () => Session.open("trash:/") },
        ];
    }

    readonly property var wifiDevice: Networking.devices.values.find(device => device.type === DeviceType.Wifi) ?? null

    // Look for networks while the Wi-Fi menu is open; the menu fills in.
    Binding {
        when: bar.wifiDevice !== null
        target: bar.wifiDevice
        property: "scannerEnabled"
        value: Popups.menuOpen && Popups.owner === "wifi" && Popups.screen === bar.screen
    }

    function wifiMenu() {
        const items = [{
            text: "Wi-Fi", checked: Networking.wifiEnabled,
            action: () => Networking.wifiEnabled = !Networking.wifiEnabled,
        }];
        if (Networking.wifiEnabled && wifiDevice) {
            const networks = wifiDevice.networks.values.slice()
                .sort((a, b) => (b.connected - a.connected) || (b.signalStrength - a.signalStrength))
                .slice(0, 10);
            if (networks.length > 0) items.push({ separator: true });
            for (const network of networks) items.push({
                text: network.name, checked: network.connected,
                action: () => bar.join(network),
            });
        }
        items.push({ separator: true });
        items.push({ text: "Network Settings…", action: () => Session.settings("network") });
        return items;
    }

    // Known and open networks connect at once; others ask for the password.
    function join(network) {
        if (network.connected) return;
        if (network.known || network.security === WifiSecurityType.Open) {
            network.connect();
            return;
        }
        Popups.confirm(bar.screen, {
            title: `Enter the password for “${network.name}”`,
            accept: "Join", password: true,
            action: password => network.connectWithPsk(password),
        });
    }

    function batteryMenu() {
        const device = UPower.displayDevice;
        return [
            { text: `Battery: ${Math.round(device.percentage * 100)}%`, enabled: false },
            { separator: true },
            { text: "Battery Settings…", action: () => Session.settings("battery") },
        ];
    }

    function clockMenu() {
        return [
            { text: Qt.formatDateTime(clock.date, "dddd, MMMM d, yyyy"), enabled: false },
            { separator: true },
            { text: "Date & Time Settings…", action: () => Session.settings("datetime") },
        ];
    }

    // Opens the menu of a menu bar item, or closes it if it's the one open.
    function openFor(item, toggle) {
        if (toggle && Popups.menuOpen && Popups.owner === item.owner) {
            Popups.close();
            return;
        }
        const source = item.menu;
        if (!source) return;
        const x = item.mapToItem(null, 0, 0).x;
        Popups.openMenu(bar.screen, item.owner, source, x, Theme.space.s0_5);
    }

    // The menus in order, for moving between them with the arrow keys.
    function menuItems() {
        const list = [logo, appName];
        for (let i = 0; i < titles.count; i++) list.push(titles.itemAt(i));
        if (windowTitle.visible) list.push(windowTitle);
        if (goTitle.visible) list.push(goTitle);
        return list.filter(item => item);
    }

    Connections {
        target: Popups
        function onStep(direction) {
            if (Popups.screen !== bar.screen) return;
            const items = bar.menuItems();
            const at = items.findIndex(item => item.owner === Popups.owner);
            if (at < 0) return;
            bar.openFor(items[(at + direction + items.length) % items.length], false);
        }
    }

    Rectangle {
        id: glass
        anchors.fill: parent
        color: Theme.color.material.thin.tint

        // The hairline under the bar.
        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 0.5
            color: Theme.color.separator
        }
    }

    // A click on the empty bar closes an open menu.
    MouseArea {
        anchors.fill: parent
        onPressed: Popups.close()
    }

    Row {
        anchors { left: parent.left; leftMargin: Theme.space.s2; verticalCenter: parent.verticalCenter }

        MenuBarItem { id: logo; owner: "ambrosia"; icon: "bowl"; iconSize: 16; menu: bar.ambrosiaMenu }
        MenuBarItem { id: appName; owner: "app"; text: Apps.activeName || "Files"; bold: true; menu: bar.appNameMenu }
        Repeater {
            id: titles
            model: bar.appTitles

            MenuBarItem {
                required property var modelData
                required property int index
                owner: "menu:" + index
                text: modelData.text
                menu: modelData
            }
        }
        MenuBarItem { id: goTitle; owner: "go"; visible: Apps.activeName === ""; text: "Go"; menu: bar.goMenu }
        MenuBarItem { id: windowTitle; owner: "window"; visible: !bar.appHasWindowMenu; text: "Window"; menu: bar.windowMenu }
    }

    Row {
        anchors { right: parent.right; rightMargin: Theme.space.s2; verticalCenter: parent.verticalCenter }

        MenuBarItem {
            owner: "battery"; icon: "battery"; menu: bar.batteryMenu
            visible: UPower.displayDevice.isLaptopBattery
        }
        MenuBarItem {
            owner: "wifi"; icon: "wifi"; menu: bar.wifiMenu
            visible: bar.wifiDevice !== null
            iconOpacity: Networking.wifiEnabled && bar.wifiDevice?.connected ? 1 : 0.4
        }
        MenuBarItem {
            owner: "search"; icon: "search"
            active: Popups.searchOpen
            onPressed: Popups.toggleSearch(bar.screen)
        }
        MenuBarItem {
            owner: "controlCenter"; icon: "controls"
            active: Popups.kind === "controlCenter" && Popups.screen === bar.screen
            onPressed: Popups.toggleControlCenter(bar.screen)
        }
        MenuBarItem {
            owner: "clock"; menu: bar.clockMenu
            text: Qt.formatDateTime(clock.date, "ddd MMM d  h:mm AP")
            leftPadding: Theme.space.s2
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
}
