import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import Ambrosia

// Install Ambrosia, as an assistant of ours: the live image's installer
// (`ambrosia install`, which /usr/local/bin/ambrosia-install runs there).
// It covers the first screen as the welcome does, the desktop blurred behind
// it, and asks one thing a page: the network when there is none, the disk,
// the account, the time zone; then says what it is about to erase, installs
// behind a bar that fills, and offers to restart. The script answers its
// questions (the disks, the networks, the time zones) and does the work;
// nothing here touches a disk. Return continues, Escape goes back, Tab moves
// between fields, the arrows choose in a list.
PanelWindow {
    id: installer

    // The screen this window was made for.
    required property ShellScreen home
    readonly property bool open: Popups.installerOpen
    readonly property string tool: "/usr/local/bin/ambrosia-install"
    readonly property QtObject size: Theme.size.welcome
    readonly property QtObject sizes: Theme.size.installer

    // intro, network, disk, account, zone, ready, installing, end.
    property string page: "intro"

    // What the script said there is.
    property var disks: []
    property var networks: []
    property bool hasWifi: true
    property var zones: []
    property bool online: false
    // The answers.
    property int disk: 0
    property string ssid: ""
    property string zone: "UTC"
    property bool accountTyped: false
    // Joining a network, and how the last try went.
    property bool joining: false
    property bool joinFailed: false
    // The install: how far, what it is doing, how it ended.
    property real fraction: 0
    property string doing: ""
    property bool failed: false

    readonly property var chosenDisk: disks[disk] ?? null
    readonly property var chosenNetwork: networks.find(network => network.ssid === ssid) ?? null
    readonly property bool accountOk: /^[a-z_][a-z0-9_-]{0,31}$/.test(account.text)
    readonly property bool passwordOk: password.text !== "" && password.text === verify.text
    readonly property var shownZones: {
        const words = zoneSearch.text.trim().toLowerCase().replace(/ /g, "_");
        return words === "" ? zones : zones.filter(name => name.toLowerCase().includes(words));
    }
    // Whether Continue has somewhere to go from this page.
    readonly property bool ready: page === "network" ? online
        : page === "disk" ? chosenDisk !== null
        : page === "account" ? fullName.text.trim() !== "" && accountOk && passwordOk
        : page === "zone" ? zones.includes(zone)
        : page !== "installing"

    // "Mina Park" is mina; the computer is minas-ambrosia, as a Mac names itself.
    function shortName(name) {
        return name.trim().split(/\s+/)[0].toLowerCase().normalize("NFD").replace(/[^a-z0-9_-]/g, "").replace(/^[^a-z_]+/, "");
    }
    readonly property string hostname: account.text !== "" ? account.text.replace(/_/g, "-") + "s-ambrosia" : "ambrosia"
    // lsblk's "476.9G" as a person writes it.
    function sizeWords(size) {
        return size.replace(/([KMGTP])$/, " $1B");
    }
    function city(name) {
        return name.split("/").pop().replace(/_/g, " ");
    }
    function region(name) {
        return name.includes("/") ? name.split("/").slice(0, -1).join(", ").replace(/_/g, " ") : "";
    }

    function next() {
        if (!ready) return;
        switch (page) {
        case "intro": page = online ? "disk" : "network"; break;
        case "network": page = "disk"; break;
        case "disk": page = "account"; break;
        case "account": page = "zone"; break;
        case "zone": page = "ready"; break;
        case "ready": install(); break;
        case "end":
            if (failed)
                Popups.installerOpen = false;
            else
                Quickshell.execDetached(["systemctl", "reboot"]);
            break;
        }
    }
    function back() {
        switch (page) {
        case "network": page = "intro"; break;
        case "disk": page = "intro"; break;
        case "account": page = "disk"; break;
        case "zone": page = "account"; break;
        case "ready": page = "zone"; break;
        }
    }
    // Up and down in the list this page has, left and right among the disks.
    function move(by) {
        if (page === "network" && networks.length > 0) {
            const at = networks.findIndex(network => network.ssid === ssid);
            choose(networks[Math.max(0, Math.min(networks.length - 1, at + by))].ssid);
        } else if (page === "disk") {
            disk = Math.max(0, Math.min(disks.length - 1, disk + by));
        } else if (page === "zone" && shownZones.length > 0) {
            const at = shownZones.indexOf(zone);
            zone = shownZones[Math.max(0, Math.min(shownZones.length - 1, at + by))];
            zoneList.positionViewAtIndex(shownZones.indexOf(zone), ListView.Contain);
        }
    }
    function choose(name) {
        ssid = name;
        joinFailed = false;
        wifiPassword.text = "";
        Qt.callLater(focusPage);
    }
    function join() {
        if (joining || !chosenNetwork) return;
        joining = true;
        joinFailed = false;
        joiner.command = [tool, "join", ssid];
        joiner.running = true;
    }
    function install() {
        page = "installing";
        fraction = 0;
        doing = "Getting ready…";
        failed = false;
        runner.running = true;
    }
    // The keyboard goes to the page's first field, or to the page itself.
    function focusPage() {
        if (page === "account")
            (fullName.text === "" ? fullName : password).forceActiveFocus();
        else if (page === "zone")
            zoneSearch.forceActiveFocus();
        else if (page === "network" && chosenNetwork?.secure && !online)
            wifiPassword.forceActiveFocus();
        else
            keys.forceActiveFocus();
    }

    onOpenChanged: {
        if (!open) return;
        // Opened again mid-install or after it, it is where it was.
        if (page !== "installing" && page !== "end") page = "intro";
        lister.running = true;
        checker.running = true;
        zoner.running = true;
        guesser.running = true;
        focusPage();
    }
    onPageChanged: {
        if (page === "network") scanner.running = true;
        if (page === "zone") Qt.callLater(() => zoneList.positionViewAtIndex(Math.max(0, shownZones.indexOf(zone)), ListView.Center));
        Qt.callLater(focusPage);
    }
    onOnlineChanged: if (online && page === "network") Qt.callLater(next)
    // A search that leaves the chosen zone out chooses its first find.
    onShownZonesChanged: if (page === "zone" && shownZones.length > 0 && !shownZones.includes(zone)) zone = shownZones[0]

    // The disks Ambrosia can go on.
    Process {
        id: lister
        command: [installer.tool, "disks"]
        stdout: StdioCollector {
            onStreamFinished: {
                installer.disks = text.split("\n").filter(line => line !== "").map(line => {
                    const [name, size, model] = line.split("\t");
                    return { name: name, size: size ?? "", model: (model ?? "Disk").trim() };
                });
                installer.disk = Math.min(installer.disk, Math.max(0, installer.disks.length - 1));
            }
        }
    }
    // The internet: asked at once and, while the network page waits for it, again and again.
    Process {
        id: checker
        command: [installer.tool, "online"]
        onExited: (code, status) => installer.online = code === 0
    }
    Timer {
        interval: 4000
        repeat: true
        running: installer.open && installer.page === "network" && !installer.online
        onTriggered: checker.running = true
    }
    // The Wi-Fi networks in reach, looked for again while the page is up.
    Process {
        id: scanner
        command: [installer.tool, "wifi"]
        stdout: StdioCollector {
            onStreamFinished: {
                installer.networks = text.split("\n").filter(line => line !== "").map(line => {
                    const [name, signal, security] = line.split("\t");
                    return { ssid: name, signal: Number(signal ?? 0), secure: (security ?? "") !== "" && security !== "--" };
                });
            }
        }
        onExited: (code, status) => installer.hasWifi = code === 0 || installer.networks.length > 0
    }
    Timer {
        interval: 15000
        repeat: true
        running: installer.open && installer.page === "network" && !installer.online && !installer.joining
        onTriggered: scanner.running = true
    }
    Process {
        id: joiner
        stdinEnabled: true
        onStarted: write(wifiPassword.text + "\n")
        onExited: (code, status) => {
            installer.joining = false;
            installer.joinFailed = code !== 0;
            if (code === 0)
                checker.running = true;
            else
                Qt.callLater(installer.focusPage);
        }
    }
    Process {
        id: zoner
        command: [installer.tool, "timezones"]
        stdout: StdioCollector {
            onStreamFinished: installer.zones = text.split("\n").filter(line => line !== "")
        }
    }
    // Where this computer seems to be, until a zone is chosen by hand.
    Process {
        id: guesser
        command: [installer.tool, "timezone"]
        stdout: StdioCollector {
            onStreamFinished: if (text.trim() !== "" && installer.page !== "zone" && installer.page !== "ready") installer.zone = text.trim()
        }
    }
    // The install itself: the answers go in, lines of progress come out.
    Process {
        id: runner
        command: [installer.tool, "run"]
        stdinEnabled: true
        onStarted: write(`disk=${installer.chosenDisk?.name ?? ""}\nfullname=${fullName.text.trim()}\nuser=${account.text}\n`
            + `hostname=${installer.hostname}\ntimezone=${installer.zone}\npassword=${password.text}\nstart\n`)
        stdout: SplitParser {
            onRead: line => {
                if (line.startsWith("progress ")) {
                    const words = line.split(" ");
                    installer.fraction = Math.max(installer.fraction, Number(words[1]) || 0);
                    installer.doing = words.slice(2).join(" ");
                }
            }
        }
        onExited: (code, status) => {
            installer.failed = code !== 0;
            if (!installer.failed) installer.fraction = 1;
            installer.page = "end";
        }
    }

    screen: home
    visible: open || veil.opacity > 0
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "ambrosia-installer"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    BackgroundEffect.blurRegion: Region { item: veil }

    // The desktop behind, blurred by the compositor and quietened.
    Rectangle {
        id: veil
        anchors.fill: parent
        color: Theme.color.material.thin.tint
        opacity: installer.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.fade.base } }

        // Nothing under it takes a click while it is up.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            hoverEnabled: true
            onWheel: wheel => wheel.accepted = true
            onPressed: installer.focusPage()
        }

        // A page with no field has the keyboard here; a field passes on
        // what it has no use for (Keys.forwardTo).
        Item {
            id: keys
            anchors.fill: parent
            focus: installer.open
            Keys.onPressed: event => {
                switch (event.key) {
                case Qt.Key_Return:
                case Qt.Key_Enter:
                    if (installer.page === "network" && !installer.online)
                        installer.join();
                    else
                        installer.next();
                    break;
                case Qt.Key_Escape: installer.back(); break;
                case Qt.Key_Up: installer.move(-1); break;
                case Qt.Key_Down: installer.move(1); break;
                case Qt.Key_Left: if (installer.page === "disk") installer.move(-1); break;
                case Qt.Key_Right: if (installer.page === "disk") installer.move(1); break;
                default: return;
                }
                event.accepted = true;
            }
        }

        Item {
            id: panel
            anchors.centerIn: parent
            width: installer.size.width
            height: installer.size.height
            scale: installer.open ? 1 : 0.96
            Behavior on scale { NumberAnimation { duration: Theme.fade.base; easing.type: Easing.OutCubic } }

            Glass {
                anchors.fill: parent
                tint: Theme.color.material.thick.tint
                radius: Theme.radius.panel
                shadow: Theme.color.shadow.window
            }

            // Install Ambrosia.
            Page {
                name: "intro"
                centered: true
                mark: "bowl"
                title: "Install Ambrosia"
                text: "Ambrosia will be installed on this computer. You’ll choose a disk and set up your account; the rest is automatic."
            }

            // The network, when there is none.
            Page {
                name: "network"
                title: "Connect to the Internet"
                text: installer.online ? "This computer is connected."
                    : installer.hasWifi ? "Ambrosia is downloaded as it installs. Choose your Wi-Fi network, or plug in a network cable."
                    : "Ambrosia is downloaded as it installs. Plug in a network cable; this computer has no Wi-Fi to join with."

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: installer.sizes.list
                    height: installer.sizes.row * 5
                    radius: Theme.radius.control
                    color: Theme.color.bg.control
                    border.width: 1
                    border.color: Theme.color.border
                    visible: installer.hasWifi
                    clip: true

                    ListView {
                        anchors { fill: parent; margins: 1 }
                        model: installer.networks
                        boundsBehavior: Flickable.StopAtBounds
                        delegate: Choice {
                            required property var modelData
                            width: ListView.view.width
                            chosen: installer.ssid === modelData.ssid
                            text: modelData.ssid
                            glyph: modelData.secure ? "lock" : ""
                            trailing: "wifi"
                            onPicked: installer.choose(modelData.ssid)
                        }
                    }
                    Label {
                        anchors.centerIn: parent
                        visible: installer.networks.length === 0
                        text: "Looking for networks…"
                        color: Theme.color.label.secondary
                    }
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.space.s2
                    visible: installer.hasWifi && installer.chosenNetwork !== null && !installer.online

                    Field {
                        id: wifiPassword
                        width: installer.sizes.list - joinButton.width - parent.spacing
                        visible: installer.chosenNetwork?.secure ?? false
                        secret: true
                        placeholder: installer.joinFailed ? "That didn’t work. Try the password again" : "Password"
                        enabled: !installer.joining
                        onAccepted: installer.join()
                    }
                    PushButton {
                        id: joinButton
                        text: installer.joining ? "Joining…" : "Join"
                        opacity: installer.joining ? 0.5 : 1
                        onClicked: installer.join()
                    }
                }
            }

            // Where it goes.
            Page {
                name: "disk"
                title: "Choose a Disk"
                text: installer.disks.length > 0 ? "Ambrosia takes the whole disk. Everything on the disk you choose will be erased."
                    : "There’s no disk here to install Ambrosia on."

                Item { width: 1; height: Theme.space.s4 }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.space.s4

                    Repeater {
                        model: installer.disks.slice(0, 4)

                        Item {
                            id: drive
                            required property var modelData
                            required property int index
                            readonly property bool chosen: installer.disk === index

                            width: installer.sizes.disk
                            height: driveColumn.height + 2 * Theme.space.s3

                            Rectangle {
                                anchors.fill: parent
                                radius: Theme.radius.card
                                color: drive.chosen ? Theme.accent.bg : "transparent"
                            }
                            Column {
                                id: driveColumn
                                y: Theme.space.s3
                                width: parent.width
                                spacing: Theme.space.s1

                                Icon {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    name: "drive"
                                    size: installer.sizes.driveIcon
                                    color: drive.chosen ? Theme.accent.fg : Theme.color.label.primary
                                }
                                Label {
                                    width: parent.width - 2 * Theme.space.s2
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                    text: drive.modelData.model
                                    color: drive.chosen ? Theme.accent.fg : Theme.color.label.primary
                                }
                                Label {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: installer.sizeWords(drive.modelData.size)
                                    style: Theme.text.callout
                                    color: drive.chosen ? Theme.accent.fg : Theme.color.label.secondary
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: installer.disk = drive.index
                            }
                        }
                    }
                }
            }

            // Who it is for.
            Page {
                name: "account"
                title: "Create Your Account"
                text: "Your name and a password, to log in with and to change settings."

                Item { width: 1; height: Theme.space.s2 }
                Asked {
                    label: "Full name"
                    Field {
                        id: fullName
                        width: installer.sizes.field
                        KeyNavigation.tab: account
                        onAccepted: account.forceActiveFocus()
                        onTextChanged: if (!installer.accountTyped) account.text = installer.shortName(text)
                    }
                }
                Asked {
                    label: "Account name"
                    hint: account.text !== "" && !installer.accountOk ? "Lowercase letters, digits, - and _, starting with a letter."
                        : "The name of your home folder."
                    Field {
                        id: account
                        width: installer.sizes.field
                        KeyNavigation.tab: password
                        KeyNavigation.backtab: fullName
                        onAccepted: password.forceActiveFocus()
                        onEdited: installer.accountTyped = text !== ""
                    }
                }
                Asked {
                    label: "Password"
                    Field {
                        id: password
                        width: installer.sizes.field
                        secret: true
                        KeyNavigation.tab: verify
                        KeyNavigation.backtab: account
                        onAccepted: verify.forceActiveFocus()
                    }
                }
                Asked {
                    label: "Verify"
                    hint: verify.text !== "" && password.text !== verify.text ? "The passwords don’t match." : ""
                    Field {
                        id: verify
                        width: installer.sizes.field
                        secret: true
                        KeyNavigation.tab: fullName
                        KeyNavigation.backtab: password
                        onAccepted: installer.next()
                    }
                }
            }

            // When it is.
            Page {
                name: "zone"
                title: "Select Your Time Zone"
                text: "The clock follows the city you choose."

                Field {
                    id: zoneSearch
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: installer.sizes.list
                    placeholder: "Search"
                    onAccepted: installer.next()
                }
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: installer.sizes.list
                    height: installer.sizes.row * 6
                    radius: Theme.radius.control
                    color: Theme.color.bg.control
                    border.width: 1
                    border.color: Theme.color.border
                    clip: true

                    ListView {
                        id: zoneList
                        anchors { fill: parent; margins: 1 }
                        model: installer.shownZones
                        boundsBehavior: Flickable.StopAtBounds
                        delegate: Choice {
                            required property string modelData
                            width: ListView.view.width
                            chosen: installer.zone === modelData
                            text: installer.city(modelData)
                            note: installer.region(modelData)
                            onPicked: installer.zone = modelData
                        }
                    }
                }
            }

            // What is about to happen, said once more.
            Page {
                name: "ready"
                centered: true
                mark: "drive"
                title: "Ready to Install"
                text: `“${installer.chosenDisk?.model ?? ""}” (${installer.sizeWords(installer.chosenDisk?.size ?? "")}) will be erased, and Ambrosia installed on it for ${fullName.text.trim()}.\nThis can’t be undone.`
            }

            Page {
                name: "installing"
                centered: true
                mark: "bowl"
                title: "Installing Ambrosia"
                text: installer.doing

                Item { width: 1; height: Theme.space.s2 }
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: installer.sizes.bar
                    height: installer.sizes.barHeight
                    radius: height / 2
                    color: Theme.color.fill.secondary

                    Rectangle {
                        width: Math.max(parent.height, parent.width * installer.fraction)
                        height: parent.height
                        radius: height / 2
                        color: Theme.accent.bg
                        Behavior on width { NumberAnimation { duration: Theme.fade.slow; easing.type: Easing.OutCubic } }
                    }
                }
            }

            Page {
                name: "end"
                centered: true
                mark: installer.failed ? "warning" : "check"
                title: installer.failed ? "The Installation Couldn’t Finish" : "Ambrosia Is Installed"
                text: installer.failed ? "The disk may already have been erased. What went wrong is written in /tmp/ambrosia-install.log."
                    : "Restart to start using it, and remove the USB drive when the screen goes dark."
            }

            PushButton {
                anchors { left: parent.left; bottom: parent.bottom; margins: Theme.space.s6 }
                visible: installer.page !== "installing"
                text: installer.page === "intro" ? "Quit"
                    : installer.page !== "end" ? "Back"
                    : installer.failed ? "Show Log" : "Later"
                onClicked: {
                    if (installer.page === "intro" || (installer.page === "end" && !installer.failed))
                        Popups.installerOpen = false;
                    else if (installer.page === "end")
                        Session.open("/tmp/ambrosia-install.log");
                    else
                        installer.back();
                }
            }
            PushButton {
                anchors { right: parent.right; bottom: parent.bottom; margins: Theme.space.s6 }
                visible: installer.page !== "installing"
                text: installer.page === "ready" ? "Erase and Install"
                    : installer.page !== "end" ? "Continue"
                    : installer.failed ? "Close" : "Restart"
                primary: true
                opacity: installer.ready ? 1 : 0.4
                onClicked: installer.next()
            }
        }
    }

    // One page: its title and a line under it, then what it asks. A
    // centered page (one with nothing to fill in) carries a mark and sits
    // in the panel's middle.
    component Page: Column {
        property string name
        property string title
        property string text
        property string mark
        property bool centered

        default property alias asked: body.data

        x: installer.size.padding
        y: centered ? Math.round((panel.height - height) / 2) - Theme.space.s6 : installer.size.padding
        width: panel.width - 2 * installer.size.padding
        spacing: Theme.space.s2
        opacity: installer.page === name ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Theme.fade.base } }

        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: mark !== ""
            name: mark
            size: installer.size.mark
            color: Theme.color.label.primary
        }
        Item { width: 1; height: Theme.space.s2; visible: mark !== "" }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: title
            style: Theme.text.largeTitle
        }
        Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: parent.text
            color: Theme.color.label.secondary
        }
        Item { width: 1; height: Theme.space.s4 }
        Column {
            id: body
            width: parent.width
            spacing: Theme.space.s3
        }
    }

    // A text field: the keyboard given to it goes to the text inside.
    component Field: FocusScope {
        id: field

        property alias text: input.text
        property string placeholder
        property bool secret
        signal accepted
        signal edited

        height: Theme.size.control.regular

        Rectangle {
            anchors.fill: parent
            radius: Theme.radius.control
            color: Theme.color.bg.control
            border.width: input.activeFocus ? Theme.size.focusRing.width : 1
            border.color: input.activeFocus ? Theme.accent.highlight : Theme.color.border
        }
        Label {
            anchors { fill: input }
            visible: input.text === ""
            text: field.placeholder
            color: Theme.color.label.tertiary
            elide: Text.ElideRight
        }
        TextInput {
            id: input
            anchors { fill: parent; leftMargin: Theme.space.s2; rightMargin: Theme.space.s2 }
            focus: true
            verticalAlignment: TextInput.AlignVCenter
            echoMode: field.secret ? TextInput.Password : TextInput.Normal
            activeFocusOnTab: true
            font.family: Theme.uiFont
            font.pixelSize: Theme.text.body.size
            color: Theme.color.label.primary
            selectionColor: Theme.accent.highlight
            clip: true
            KeyNavigation.tab: field.KeyNavigation.tab
            KeyNavigation.backtab: field.KeyNavigation.backtab
            onAccepted: field.accepted()
            onTextEdited: field.edited()
            Keys.onEscapePressed: installer.back()
            Keys.onUpPressed: installer.move(-1)
            Keys.onDownPressed: installer.move(1)
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.IBeamCursor
            acceptedButtons: Qt.NoButton
        }
    }

    // A field with its name before it and, when there is one, a line under it.
    component Asked: Item {
        property string label
        property string hint
        default property alias field: slot.data

        anchors.horizontalCenter: parent.horizontalCenter
        width: installer.sizes.label + Theme.space.s3 + installer.sizes.field
        height: slot.height + (hintLine.visible ? hintLine.height + Theme.space.s1 : 0)

        Label {
            width: installer.sizes.label
            height: slot.height
            horizontalAlignment: Text.AlignRight
            text: label
        }
        Item {
            id: slot
            x: installer.sizes.label + Theme.space.s3
            width: installer.sizes.field
            height: Theme.size.control.regular
        }
        Label {
            id: hintLine
            x: slot.x
            y: slot.height + Theme.space.s1
            width: slot.width
            visible: hint !== ""
            wrapMode: Text.WordWrap
            text: hint
            style: Theme.text.footnote
            color: Theme.color.label.secondary
        }
    }

    // A row of a list: a network, a time zone.
    component Choice: Item {
        id: choice

        property bool chosen
        property string text
        property string note
        property string glyph
        property string trailing
        signal picked

        height: installer.sizes.row

        Rectangle {
            anchors { fill: parent; leftMargin: Theme.space.s1; rightMargin: Theme.space.s1; topMargin: 2; bottomMargin: 2 }
            radius: Theme.radius.minimum
            color: choice.chosen ? Theme.accent.bg : "transparent"
        }
        Label {
            id: words
            anchors { left: parent.left; leftMargin: Theme.space.s3; verticalCenter: parent.verticalCenter }
            width: Math.min(implicitWidth, parent.width - 2 * Theme.space.s3 - ends.width - noteWords.implicitWidth)
            elide: Text.ElideRight
            text: choice.text
            color: choice.chosen ? Theme.accent.fg : Theme.color.label.primary
        }
        Label {
            id: noteWords
            anchors { left: words.right; leftMargin: Theme.space.s2; verticalCenter: parent.verticalCenter }
            visible: choice.note !== ""
            text: choice.note
            style: Theme.text.callout
            color: choice.chosen ? Theme.accent.fg : Theme.color.label.secondary
        }
        Row {
            id: ends
            anchors { right: parent.right; rightMargin: Theme.space.s3; verticalCenter: parent.verticalCenter }
            spacing: Theme.space.s2

            Icon {
                visible: choice.glyph !== ""
                name: choice.glyph
                size: Theme.size.menubar.icon
                color: choice.chosen ? Theme.accent.fg : Theme.color.label.secondary
            }
            Icon {
                visible: choice.trailing !== ""
                name: choice.trailing
                size: Theme.size.menubar.icon
                color: choice.chosen ? Theme.accent.fg : Theme.color.label.secondary
            }
        }
        MouseArea {
            anchors.fill: parent
            onClicked: choice.picked()
        }
    }
}
