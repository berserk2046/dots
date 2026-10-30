import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import Quickshell.Wayland

// macOS-style notification banners in the top right corner of the focused monitor while unlocked.
// They slide in, stay `duration` (critical ones until closed), and a click runs the default action.
PanelWindow {
    id: window

    // {notification, received: Date}
    property var banners: []
    property int duration: 5000
    property bool showText: true

    signal bannerExpired(var entry)
    signal bannerActivated(var entry)
    signal bannerClosed(var entry)

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    visible: banners.length > 0
    anchors {
        top: true
        right: true
    }
    margins {
        top: 8
        right: 10
    }
    implicitWidth: 380
    implicitHeight: Math.max(1, column.implicitHeight)
    exclusiveZone: 0
    color: "transparent"

    WlrLayershell.namespace: "lockscreen-notifications"
    WlrLayershell.layer: WlrLayer.Overlay

    Column {
        id: column

        width: parent.width
        spacing: 8

        Repeater {
            model: window.banners

            NotificationCard {
                id: banner

                required property var modelData

                notification: modelData.notification
                received: modelData.received
                closable: true
                showText: window.showText
                color: "#000000"
                border.width: 1
                border.color: Theme.solidBorder
                onClicked: window.bannerActivated(modelData)
                onCloseClicked: window.bannerClosed(modelData)

                // Slide in from the right
                transform: Translate {
                    id: slide

                    x: 400
                }

                Component.onCompleted: slideIn.start()

                NumberAnimation {
                    id: slideIn

                    target: slide
                    property: "x"
                    to: 0
                    duration: 300
                    easing.type: Easing.OutCubic
                }

                Timer {
                    interval: window.duration
                    // Critical notifications stay until closed
                    running: banner.notification.urgency !== NotificationUrgency.Critical
                    onTriggered: window.bannerExpired(banner.modelData)
                }
            }
        }
    }
}
