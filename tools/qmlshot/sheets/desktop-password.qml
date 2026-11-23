import QtQuick
import Quickshell
import "../parts"
import "../../../out/build/qmlshot/shell"

// A program asking for the password (polkit), as the shell's agent shows it:
// the stand-in agent is handed a request, and a few characters are typed.
Desk {
    Authorization { id: authorization }

    then: () => {
        authorization.agent.shotAsk({
            message: "Authentication is required to install software",
            who: "Ada Lovelace",
        });
        shotPointer.type("nectar");
    }
}
