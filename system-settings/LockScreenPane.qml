import QtQuick
import qs.shared

// Lock Screen: when to lock, turn the display off and sleep (hypridle), the password grace period,
// the message and picture on the lock screen, and the login screen copy.
Column {
    id: pane

    property string pageTitle: ""

    readonly property var idleOptions: [
        {
            label: qsTr("Never"),
            value: 0
        },
        ...[1, 2, 3, 5, 10, 15, 20, 30].map(m => ({
                    label: (m === 1 ? qsTr("For 1 minute") : qsTr("For %1 minutes").arg(m)),
                    value: m
                })),
        {
            label: qsTr("For 1 hour"),
            value: 60
        },
        {
            label: qsTr("For 2 hours"),
            value: 120
        }
    ]

    spacing: 10

    function setIdle(key, value) {
        Store.set("lockScreen", key, value);
        Store.writeIdle();
    }

    GroupTitle {
        text: qsTr("When Inactive")
    }

    SettingsGroup {
        SettingRow {
            title: qsTr("Lock the screen when inactive")

            Dropdown {
                anchors.verticalCenter: parent.verticalCenter
                options: pane.idleOptions
                value: Store.get("lockScreen", "lockAfter", 0)
                onPicked: v => pane.setIdle("lockAfter", v)
            }
        }

        SettingRow {
            title: qsTr("Turn display off when inactive")

            Dropdown {
                anchors.verticalCenter: parent.verticalCenter
                options: pane.idleOptions
                value: Store.get("lockScreen", "displayOffAfter", 0)
                onPicked: v => pane.setIdle("displayOffAfter", v)
            }
        }

        SettingRow {
            title: qsTr("Sleep when inactive")

            Dropdown {
                anchors.verticalCenter: parent.verticalCenter
                options: pane.idleOptions
                value: Store.get("lockScreen", "sleepAfter", 0)
                onPicked: v => pane.setIdle("sleepAfter", v)
            }
        }

        SettingRow {
            title: qsTr("Lock before going to sleep")
            subtitle: qsTr("Also when closing the lid")

            Toggle {
                anchors.verticalCenter: parent.verticalCenter
                checked: Store.get("lockScreen", "lockBeforeSleep", true)
                onToggled: on => pane.setIdle("lockBeforeSleep", on)
            }
        }
    }

    Caption {
        text: qsTr("Handled by hypridle. Watching a video in fullscreen or with an app that asks to stay awake keeps the screen on. A key press or mouse move turns the display back on.")
    }

    GroupTitle {
        text: qsTr("Password")
    }

    SettingsGroup {
        SettingRow {
            title: qsTr("Require password after locking")
            subtitle: qsTr("Before that, any key or click unlocks")

            Dropdown {
                anchors.verticalCenter: parent.verticalCenter
                options: [
                    {
                        label: qsTr("Immediately"),
                        value: 0
                    },
                    {
                        label: qsTr("After 5 seconds"),
                        value: 5
                    },
                    {
                        label: qsTr("After 15 seconds"),
                        value: 15
                    },
                    {
                        label: qsTr("After 1 minute"),
                        value: 60
                    },
                    {
                        label: qsTr("After 5 minutes"),
                        value: 300
                    }
                ]
                value: Store.get("lockScreen", "graceSeconds", 15)
                onPicked: v => Store.set("lockScreen", "graceSeconds", v)
            }
        }
    }

    Caption {
        text: qsTr("Locking before sleep, and $mod+Ctrl+Q's lockNow, always ask for the password right away.")
    }

    GroupTitle {
        text: qsTr("Lock Screen")
    }

    SettingsGroup {
        SettingRow {
            title: qsTr("Show message when locked")

            Field {
                id: messageField

                anchors.verticalCenter: parent.verticalCenter
                width: 240
                placeholder: qsTr("No message")
                text: Store.get("lockScreen", "message", "")

                Connections {
                    target: messageField.input

                    function onEditingFinished() {
                        Store.set("lockScreen", "message", messageField.text.trim());
                    }
                }
            }
        }

        SettingRow {
            title: qsTr("Notification previews")
            subtitle: {
                const previews = Store.get("notifications", "previews", "always");
                return previews === "always" ? qsTr("Shown") : previews === "unlocked" ? qsTr("App names only") : qsTr("Hidden");
            }
            chevron: true
            onClicked: Ui.open("notifications")
        }

        SettingRow {
            title: qsTr("Wallpaper")
            subtitle: Store.get("lockScreen", "wallpaper", "") ? Store.get("lockScreen", "wallpaper", "").split("/").pop() : qsTr("Same as the desktop")

            TextButton {
                anchors.verticalCenter: parent.verticalCenter
                visible: Store.get("lockScreen", "wallpaper", "") !== ""
                text: qsTr("Use Desktop's")
                onClicked: Store.set("lockScreen", "wallpaper", "")
            }

            TextButton {
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Choose…")
                onClicked: Store.run(["zenity", "--file-selection", "--title=" + qsTr("Choose a lock screen picture"), "--file-filter=" + qsTr("Pictures") + " | *.jpg *.jpeg *.png *.webp"], (code, out) => {
                    if (code === 0 && out.trim() !== "")
                        Store.set("lockScreen", "wallpaper", out.trim());
                })
            }
        }

        LoginScreenRow {}
    }

    Caption {
        text: qsTr("The password field shows on the main display (Displays → Use as). The login screen keeps its own copy of your picture, message and wallpaper; update it after changing them.")
    }

    Row {
        anchors.right: parent.right

        TextButton {
            text: qsTr("Lock Screen Now")
            onClicked: Store.lockscreenIpc(["lock", "lock"])
        }
    }
}
