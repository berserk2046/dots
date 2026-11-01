import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

// Session menu like the Apple menu: user header, Sleep / Restart… / Shut Down… / Lock Screen / Log Out….
// Restart, Shut Down and Log Out ask first, with macOS's 60 second countdown; closing the card cancels.
Column {
    id: panel

    property bool shown: false
    signal closeRequested

    // Same actions as the old fuzzel session menu. Lock before sleeping so the desktop isn't visible on wake.
    readonly property var commands: ({
            "sleep": "qs -p ~/.config/lockscreen ipc call lock lockNow; sleep 1; systemctl suspend",
            "restart": "systemctl reboot",
            "shutdown": "systemctl poweroff",
            "lock": "qs -p ~/.config/lockscreen ipc call lock lock",
            "logout": "loginctl terminate-user \"$USER\""
        })
    readonly property int countdownSeconds: 60

    readonly property string user: Quickshell.env("USER") ?? ""
    // Profile picture: ~/.face, the usual place display managers and desktops look.
    readonly property string facePath: (Quickshell.env("HOME") ?? "") + "/.face"
    property string fullName: ""
    property string host: ""
    property real uptime: 0

    // Action waiting for confirmation ("restart", "shutdown", "logout"), and seconds left.
    property string pending: ""
    property int remaining: 0

    width: parent?.width ?? 0
    spacing: 2

    onShownChanged: {
        pending = "";
        if (shown) {
            infoProc.running = true;
        }
    }

    function run(action) {
        pending = "";
        closeRequested();
        Quickshell.execDetached(["sh", "-c", commands[action]]);
    }

    function ask(action) {
        pending = action;
        remaining = countdownSeconds;
    }

    // Title and "%1 seconds" countdown line for the confirmation, in macOS's words.
    function confirmText(action) {
        switch (action) {
        case "restart":
            return [qsTr("Are you sure you want to restart your computer now?"), qsTr("If you do nothing, the computer will restart automatically in %1 seconds.")];
        case "shutdown":
            return [qsTr("Are you sure you want to shut down your computer now?"), qsTr("If you do nothing, the computer will shut down automatically in %1 seconds.")];
        default:
            return [qsTr("Are you sure you want to quit all applications and log out now?"), qsTr("If you do nothing, you will be logged out automatically in %1 seconds.")];
        }
    }

    function buttonText(action) {
        return action === "restart" ? qsTr("Restart") : action === "shutdown" ? qsTr("Shut Down") : qsTr("Log Out");
    }

    function uptimeText() {
        const minutes = Math.floor(uptime / 60);
        const h = Math.floor(minutes / 60);
        const d = Math.floor(h / 24);
        if (d > 0)
            return qsTr("up %1 d %2 h").arg(d).arg(h % 24);
        return h > 0 ? qsTr("up %1 h %2 min").arg(h).arg(minutes % 60) : qsTr("up %1 min").arg(minutes);
    }

    // Name (GECOS), hostname and uptime, read each time the menu opens.
    Process {
        id: infoProc

        command: ["sh", "-c", "getent passwd \"$USER\" | cut -d: -f5 | cut -d, -f1; cat /proc/sys/kernel/hostname; cut -d' ' -f1 /proc/uptime; [ -f \"$HOME/.face\" ] && echo face"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                panel.fullName = lines[0]?.trim() ?? "";
                panel.host = lines[1]?.trim() ?? "";
                panel.uptime = parseFloat(lines[2]) || 0;
                // Reload so a newly added or changed picture shows up.
                face.source = "";
                if (lines[3]?.trim() === "face")
                    face.source = "file://" + panel.facePath;
            }
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: panel.pending !== ""
        onTriggered: {
            if (--panel.remaining <= 0)
                panel.run(panel.pending);
        }
    }

    // ---- Menu ----

    Column {
        width: parent.width
        spacing: 2
        visible: panel.pending === ""

        Item {
            width: parent.width
            height: 56

            // Initials avatar, like a macOS account without a picture.
            Rectangle {
                id: avatar

                x: 6
                anchors.verticalCenter: parent.verticalCenter
                width: 38
                height: 38
                radius: 19
                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: "#8e8e93"
                    }
                    GradientStop {
                        position: 1
                        color: "#48484a"
                    }
                }

                ClippingRectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: "transparent"
                    visible: face.status === Image.Ready

                    Image {
                        id: face

                        anchors.fill: parent
                        fillMode: Image.PreserveAspectCrop
                        sourceSize.width: 96
                        sourceSize.height: 96
                        cache: false
                        asynchronous: true
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: face.status !== Image.Ready
                    text: (panel.fullName || panel.user).split(/\s+/).filter(w => w).slice(0, 2).map(w => w[0].toUpperCase()).join("")
                    color: "#ffffff"
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize(16)
                    font.weight: Font.DemiBold
                }
            }

            Column {
                anchors.left: avatar.right
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: panel.fullName || panel.user
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize(14)
                    font.weight: Font.Bold
                }

                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: [panel.host, panel.uptime > 0 ? panel.uptimeText() : ""].filter(x => x).join("  ·  ")
                    color: Theme.textSecondary
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize(11)
                }
            }
        }

        Separator {}

        ListRow {
            title: qsTr("Sleep")
            icon: IconCircle {
                glyph: Theme.iSleep
            }
            onClicked: panel.run("sleep")
        }
        ListRow {
            title: qsTr("Restart…")
            icon: IconCircle {
                glyph: Theme.iRestart
            }
            onClicked: panel.ask("restart")
        }
        ListRow {
            title: qsTr("Shut Down…")
            icon: IconCircle {
                glyph: Theme.iPower
            }
            onClicked: panel.ask("shutdown")
        }

        Separator {}

        ListRow {
            title: qsTr("Lock Screen")
            icon: IconCircle {
                glyph: Theme.iLock
            }
            onClicked: panel.run("lock")
        }
        ListRow {
            title: qsTr("Log Out %1…").arg(panel.fullName || panel.user)
            icon: IconCircle {
                glyph: Theme.iLogout
            }
            onClicked: panel.ask("logout")
        }
    }

    // ---- Confirmation, as in macOS's shut down dialog ----

    Column {
        width: parent.width
        spacing: 10
        visible: panel.pending !== ""
        topPadding: 14
        bottomPadding: 6

        // Icon with a ring that empties as the countdown runs.
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 64
            height: 64

            Canvas {
                id: ring

                property real progress: panel.countdownSeconds > 0 ? panel.remaining / panel.countdownSeconds : 0

                anchors.fill: parent
                onProgressChanged: requestPaint()
                onVisibleChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    const r = width / 2 - 2.5;
                    ctx.lineWidth = 3;
                    ctx.lineCap = "round";
                    ctx.strokeStyle = Theme.track;
                    ctx.beginPath();
                    ctx.arc(width / 2, height / 2, r, 0, Math.PI * 2);
                    ctx.stroke();
                    ctx.strokeStyle = panel.pending === "shutdown" ? Theme.danger : Theme.accent;
                    ctx.beginPath();
                    ctx.arc(width / 2, height / 2, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * progress);
                    ctx.stroke();
                }
            }

            Glyph {
                anchors.centerIn: parent
                text: panel.pending === "restart" ? Theme.iRestart : panel.pending === "logout" ? Theme.iLogout : Theme.iPower
                size: 28
            }
        }

        Text {
            x: 12
            width: parent.width - 24
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: panel.confirmText(panel.pending)[0]
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: Theme.fontSize(13)
            font.weight: Font.DemiBold
        }

        Text {
            x: 12
            width: parent.width - 24
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: panel.confirmText(panel.pending)[1].arg(panel.remaining)
            color: Theme.textSecondary
            font.family: Theme.font
            font.pixelSize: Theme.fontSize(12)
            font.features: {
                "tnum": 1
            }
        }

        Row {
            x: 8
            width: parent.width - 16
            spacing: 8
            topPadding: 4

            TextButton {
                width: (parent.width - parent.spacing) / 2
                implicitHeight: 28
                text: qsTr("Cancel")
                onClicked: panel.pending = ""
            }
            TextButton {
                width: (parent.width - parent.spacing) / 2
                implicitHeight: 28
                primary: true
                text: panel.buttonText(panel.pending)
                onClicked: panel.run(panel.pending)
            }
        }
    }
}
