import QtQuick
import Quickshell

// "… Settings…" row at the bottom of a panel, like macOS's menus: opens that System Settings pane over
// its IPC, starting the app first if it isn't running.
Rectangle {
    id: link

    property string text
    property string pane
    signal opened

    width: parent?.width ?? 0
    height: 28
    radius: 7
    color: mouse.containsMouse ? Theme.hover : "transparent"

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: link.text
        color: Theme.text
        font.family: Theme.font
        font.pixelSize: Theme.fontSize(13)
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            Quickshell.execDetached(["sh", "-c", `d=$HOME/.config/system-settings
                if ! qs -p "$d" ipc call settings show 2>/dev/null; then
                    qs -p "$d" -n -d >/dev/null 2>&1
                    for i in 1 2 3 4 5 6 7 8 9 10; do sleep 0.2; qs -p "$d" ipc call settings show 2>/dev/null && break; done
                fi
                qs -p "$d" ipc call settings open "$1" ""`, "sh", link.pane]);
            link.opened();
        }
    }
}
