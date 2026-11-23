import QtQuick

// Stands in for Quickshell's polkit agent: registered, and asked nothing
// until a sheet gives it a request (`shotAsk({ message, who })`).
QtObject {
    id: agent

    property string path
    readonly property bool isRegistered: true
    property bool isActive: false
    property QtObject flow: null
    signal authenticationRequestStarted()

    property Component shotFlow: Component {
        QtObject {
            property string message
            property string iconName
            property string actionId
            property QtObject selectedIdentity
            property bool isResponseRequired: true
            property bool responseVisible: false
            property string inputPrompt: "Password: "
            property var shotSubmitted: []
            signal authenticationFailed()
            signal authenticationSucceeded()
            signal authenticationRequestCancelled()
            function submit(value) { shotSubmitted.push(value); }
            function cancelAuthenticationRequest() { agent.isActive = false; }
        }
    }
    property Component shotIdentity: Component {
        QtObject {
            property string displayName
        }
    }
    function shotAsk(request) {
        flow = shotFlow.createObject(agent, {
            message: request.message,
            selectedIdentity: shotIdentity.createObject(agent, { displayName: request.who }),
        });
        isActive = true;
        authenticationRequestStarted();
    }
}
