import Quickshell
import Quickshell.Services.Polkit
import QtQuick

// The password a program needs before it may change the system. The shell
// is the session's polkit agent (Plasma's own is kept from starting, as
// plasmashell is): what polkit asks comes up as our confirmation, with a
// lock and a password field, as a Mac asks. A wrong password shakes it and
// asks again; Cancel, Escape or a click beside it refuses.
Scope {
    id: authorization

    // Our dialog is up for the request in hand.
    property bool asking: false
    // For a sheet to reach (tools/qmlshot/sheets/desktop-password.qml).
    readonly property alias agent: agent

    function ask() {
        const flow = agent.flow;
        if (asking || !agent.isActive || !flow || !flow.isResponseRequired) return;
        const who = flow.selectedIdentity?.displayName ?? "";
        asking = true;
        Popups.confirm(Quickshell.screens[0], {
            glyph: "lock",
            title: flow.message,
            text: who ? `Enter the password for “${who}” to allow this.` : "Enter your password to allow this.",
            password: true,
            // An answer that isn't a secret (a code read off a device) is shown.
            shown: flow.responseVisible,
            accept: "OK",
            // Stays up until polkit has said yes or no.
            hold: true,
            action: answer => flow.submit(answer),
            cancel: () => {
                authorization.asking = false;
                flow.cancelAuthenticationRequest();
            },
        });
    }

    function done() {
        if (!asking) return;
        asking = false;
        Popups.finish();
    }

    PolkitAgent {
        id: agent
        onAuthenticationRequestStarted: authorization.ask()
        onIsActiveChanged: isActive ? authorization.ask() : authorization.done()
    }

    Connections {
        target: agent.flow
        function onIsResponseRequiredChanged() { authorization.ask(); }
        // Polkit starts over for the same account by itself.
        function onAuthenticationFailed() { if (authorization.asking) Popups.refused(); }
        function onAuthenticationSucceeded() { authorization.done(); }
        function onAuthenticationRequestCancelled() { authorization.done(); }
    }
}
