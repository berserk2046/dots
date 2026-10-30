import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// macOS-style Notification Center: slides in from the right edge of the focused monitor with the
// Do Not Disturb switch and the saved notifications grouped by app. Each notification, each app group
// and the whole list can be deleted. Esc or a click outside closes it.
PanelWindow {
    id: window

    required property var daemon

    readonly property bool open: daemon.centerOpen

    // Newest first, grouped by app in order of each app's latest notification.
    readonly property var groups: {
        const order = [];
        const byApp = {};
        for (const entry of daemon.history) {
            const app = entry.appName || qsTr("Other");
            if (!byApp[app]) {
                byApp[app] = [];
                order.push(app);
            }
            byApp[app].push(entry);
        }
        return order.map(app => ({
                    app: app,
                    entries: byApp[app]
                }));
    }

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    visible: open || slideOut.running
    anchors {
        top: true
        bottom: true
        right: true
    }
    implicitWidth: 420
    exclusiveZone: 0
    color: "transparent"

    WlrLayershell.namespace: "lockscreen-notification-center"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    onOpenChanged: {
        if (open) {
            slideOut.stop();
            slideIn.restart();
            panel.forceActiveFocus();
        } else {
            slideIn.stop();
            slideOut.restart();
        }
    }

    // Clicking anywhere else closes it
    HyprlandFocusGrab {
        active: window.open
        windows: [window]
        onCleared: window.daemon.setCenterOpen(false)
    }

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    Rectangle {
        id: panel

        x: 8
        y: 8
        width: parent.width - 16
        height: parent.height - 16
        radius: 18
        color: "#000000"
        border.width: 1
        border.color: Theme.solidBorder
        focus: true

        Keys.onEscapePressed: window.daemon.setCenterOpen(false)

        transform: Translate {
            id: slide

            x: window.width
        }

        NumberAnimation {
            id: slideIn

            target: slide
            property: "x"
            to: 0
            duration: 280
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            id: slideOut

            target: slide
            property: "x"
            to: window.width
            duration: 220
            easing.type: Easing.InCubic
        }

        // Header: title and Clear All
        Item {
            id: header

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 16
            height: 28

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Notifications")
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 18
                font.weight: Font.Bold
            }

            TextButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: window.daemon.history.length > 0
                text: qsTr("Clear All")
                onClicked: window.daemon.clearAll()
            }
        }

        // Do Not Disturb, like the Focus tile in Control Center
        Rectangle {
            id: dndTile

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: header.bottom
            anchors.margins: 16
            anchors.topMargin: 12
            height: 52
            radius: 14
            color: dndMouse.containsMouse ? Theme.solidCardHover : Theme.solidCard

            Rectangle {
                id: moon

                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                width: 32
                height: 32
                radius: 16
                color: window.daemon.doNotDisturb ? "#5e5ce6" : Theme.solidCircle

                Text {
                    anchors.centerIn: parent
                    text: Theme.iMoon
                    color: Theme.text
                    font.family: Theme.iconFont
                    font.pixelSize: 18
                }
            }

            Column {
                anchors.left: moon.right
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    text: qsTr("Do Not Disturb")
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }

                Text {
                    text: window.daemon.doNotDisturb ? qsTr("On · notifications are saved here silently") : qsTr("Off")
                    color: Theme.textSecondary
                    font.family: Theme.font
                    font.pixelSize: 12
                }
            }

            MouseArea {
                id: dndMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: window.daemon.setDnd(!window.daemon.doNotDisturb)
            }
        }

        Text {
            anchors.centerIn: list
            visible: window.daemon.history.length === 0
            text: qsTr("No Notifications")
            color: Theme.textSecondary
            font.family: Theme.font
            font.pixelSize: 15
        }

        // Same 16 px side margins as the Do Not Disturb tile
        ListView {
            id: list

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            anchors.top: dndTile.bottom
            anchors.bottom: parent.bottom
            anchors.topMargin: 14
            anchors.bottomMargin: 8
            clip: true
            spacing: 16
            boundsBehavior: Flickable.StopAtBounds
            model: window.groups

            delegate: Column {
                id: group

                required property var modelData

                width: list.width
                spacing: 8

                // App name and a button that clears the app's notifications
                Item {
                    width: parent.width
                    height: 22

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        text: group.modelData.app
                        color: Theme.textSecondary
                        font.family: Theme.font
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }

                    TextButton {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("Clear")
                        onClicked: window.daemon.clearApp(group.modelData.app)
                    }
                }

                Repeater {
                    model: group.modelData.entries

                    NotificationCard {
                        required property var modelData

                        width: group.width
                        notification: modelData
                        received: new Date(modelData.time)
                        now: clock.date.getTime()
                        closable: true
                        showText: Config.previews !== "never"
                        color: Theme.solidCard
                        onClicked: window.daemon.activate(modelData.id)
                        onCloseClicked: window.daemon.remove([modelData.id])
                    }
                }
            }
        }
    }
}
