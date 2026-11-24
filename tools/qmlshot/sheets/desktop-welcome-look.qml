import QtQuick
import Quickshell
import "../parts"
import "../../../out/build/qmlshot/shell"

// The welcome's second page: Choose Your Look.
Desk {
    then: () => {
        Popups.welcomeOpen = true;
        welcome.next();
    }
}
