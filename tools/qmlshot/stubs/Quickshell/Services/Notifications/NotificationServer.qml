import QtQml

// A server nothing reaches. A sheet makes one arrive with shotNotify({
// appName, summary, body, … }): it is tracked and announced as an app's
// would be.
QtObject {
    id: server

    property bool keepOnReload: true
    property bool actionsSupported: false
    property bool actionIconsSupported: false
    property bool bodySupported: true
    property bool bodyMarkupSupported: false
    property bool bodyHyperlinksSupported: false
    property bool bodyImagesSupported: false
    property bool imageSupported: false
    property bool persistenceSupported: false
    property bool inlineReplySupported: false
    property var extraHints: []
    signal notification(var notification)

    property var shotTracked: []
    readonly property var trackedNotifications: ({ values: shotTracked })
    property int shotNext: 1
    // A plain object with what the shell reads of a notification (QML has
    // no property that can be called `id`).
    function shotNotify(fields) {
        const listeners = [];
        const one = Object.assign({
            id: shotNext++, tracked: false, expireTimeout: -1, appName: "", appIcon: "", desktopEntry: "",
            summary: "", body: "", image: "", urgency: 1, transient: false, resident: false,
            hasActionIcons: false, hasInlineReply: false, actions: [], hints: {},
            closed: { connect: listener => listeners.push(listener) },
        }, fields);
        const close = reason => {
            shotTracked = shotTracked.filter(each => each !== one);
            for (const listener of listeners) listener(reason);
        };
        one.dismiss = () => close(2);
        one.expire = () => close(1);
        shotTracked = shotTracked.concat([one]);
        notification(one);
        return one;
    }
}
