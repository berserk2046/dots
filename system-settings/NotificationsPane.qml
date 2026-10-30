import QtQuick
import qs.shared

// Notifications: previews, banner duration, history, Do Not Disturb, and per-app settings
// (allow, banners, lock screen). Read by the lock screen shell's notification daemon.
Column {
    id: pane

    readonly property string appName: Ui.subpage.startsWith("app:") ? Ui.subpage.slice(4) : ""
    property string pageTitle: appName

    spacing: 10

    NotificationApps {
        id: apps
    }

    // ---- Main page ----

    GroupTitle {
        visible: pane.appName === ""
        text: qsTr("Notification Center")
    }

    SettingsGroup {
        visible: pane.appName === ""

        SettingRow {
            title: qsTr("Do Not Disturb")
            subtitle: qsTr("Silences banners and the lock screen; everything still goes to the Notification Center")
            glyph: Theme.iFocus
            tileColor: "#5e5ce6"

            Toggle {
                anchors.verticalCenter: parent.verticalCenter
                checked: apps.doNotDisturb
                onToggled: on => apps.setDnd(on)
            }
        }

        SettingRow {
            title: qsTr("Show previews")

            Dropdown {
                anchors.verticalCenter: parent.verticalCenter
                options: [
                    {
                        label: qsTr("Always"),
                        value: "always"
                    },
                    {
                        label: qsTr("When Unlocked"),
                        value: "unlocked"
                    },
                    {
                        label: qsTr("Never"),
                        value: "never"
                    }
                ]
                value: Store.get("notifications", "previews", "always")
                onPicked: v => Store.set("notifications", "previews", v)
            }
        }

        SettingRow {
            title: qsTr("Banner duration")

            Dropdown {
                anchors.verticalCenter: parent.verticalCenter
                options: [3, 5, 8, 10, 15, 30].map(s => ({
                            label: qsTr("%1 seconds").arg(s),
                            value: s
                        }))
                value: Store.get("notifications", "bannerSeconds", 5)
                onPicked: v => Store.set("notifications", "bannerSeconds", v)
            }
        }

        SettingRow {
            title: qsTr("Keep in history")

            Dropdown {
                anchors.verticalCenter: parent.verticalCenter
                options: [50, 100, 200, 500, 1000].map(n => ({
                            label: qsTr("%1 notifications").arg(n),
                            value: n
                        }))
                value: Store.get("notifications", "historyLimit", 200)
                onPicked: v => Store.set("notifications", "historyLimit", v)
            }
        }

        SettingRow {
            title: qsTr("Notification history")
            subtitle: (apps.history.length === 1 ? qsTr("1 notification saved") : qsTr("%1 notifications saved").arg(apps.history.length))

            TextButton {
                anchors.verticalCenter: parent.verticalCenter
                text: confirming ? qsTr("Click again to clear") : qsTr("Clear All…")
                destructive: confirming
                enabled: apps.history.length > 0

                property bool confirming: false

                onClicked: {
                    if (confirming) {
                        Store.lockscreenIpc(["notifications", "clearAll"]);
                        confirming = false;
                    } else {
                        confirming = true;
                    }
                }
            }
        }
    }

    Caption {
        visible: pane.appName === ""
        text: qsTr("“When Unlocked” shows only the app name on the lock screen. Critical notifications, and apps allowed in Focus, show even during Do Not Disturb.")
    }

    GroupTitle {
        visible: pane.appName === ""
        text: qsTr("Application Notifications")
    }

    SettingsGroup {
        visible: pane.appName === ""

        SettingRow {
            visible: apps.names.length === 0
            title: qsTr("Apps show up here after their first notification")
            titleColor: Theme.textSecondary
        }

        Repeater {
            model: apps.names

            SettingRow {
                required property string modelData

                title: modelData
                subtitle: apps.summary(modelData)
                iconSource: apps.iconFor(modelData)
                glyph: Theme.iBell
                tileColor: "#48484a"
                chevron: true
                onClicked: Ui.openSub("app:" + modelData)
            }
        }
    }

    // ---- One app ----

    SettingsGroup {
        visible: pane.appName !== ""

        SettingRow {
            title: qsTr("Allow notifications")
            iconSource: apps.iconFor(pane.appName)
            glyph: Theme.iBell
            tileColor: "#48484a"

            Toggle {
                anchors.verticalCenter: parent.verticalCenter
                checked: apps.rule(pane.appName).allow !== false
                onToggled: on => apps.setRule(pane.appName, "allow", on)
            }
        }

        SettingRow {
            title: qsTr("Show banners")
            subtitle: qsTr("In the top right corner while unlocked")
            enabled: apps.rule(pane.appName).allow !== false
            opacity: enabled ? 1 : 0.4

            Toggle {
                anchors.verticalCenter: parent.verticalCenter
                checked: apps.rule(pane.appName).banners !== false
                onToggled: on => apps.setRule(pane.appName, "banners", on)
            }
        }

        SettingRow {
            title: qsTr("Play sound for notifications")
            enabled: apps.rule(pane.appName).allow !== false
            opacity: enabled ? 1 : 0.4

            Toggle {
                anchors.verticalCenter: parent.verticalCenter
                checked: apps.rule(pane.appName).sound !== false
                onToggled: on => apps.setRule(pane.appName, "sound", on)
            }
        }

        SettingRow {
            title: qsTr("Show on Lock Screen")
            enabled: apps.rule(pane.appName).allow !== false
            opacity: enabled ? 1 : 0.4

            Toggle {
                anchors.verticalCenter: parent.verticalCenter
                checked: apps.rule(pane.appName).lockScreen !== false
                onToggled: on => apps.setRule(pane.appName, "lockScreen", on)
            }
        }

        SettingRow {
            title: qsTr("Allow during Do Not Disturb")
            enabled: apps.rule(pane.appName).allow !== false
            opacity: enabled ? 1 : 0.4

            Toggle {
                anchors.verticalCenter: parent.verticalCenter
                checked: Store.get("focus", "allowedApps", []).includes(pane.appName)
                onToggled: on => {
                    const list = Store.get("focus", "allowedApps", []).filter(n => n !== pane.appName);
                    Store.set("focus", "allowedApps", on ? [...list, pane.appName] : list);
                }
            }
        }
    }

    Caption {
        visible: pane.appName !== ""
        text: qsTr("With notifications off, this app's notifications are dropped and not saved. Turning off banners and the lock screen still keeps them in the Notification Center.")
    }

    SettingsGroup {
        visible: pane.appName !== ""

        SettingRow {
            title: qsTr("Saved notifications")
            subtitle: qsTr("%1 in the Notification Center").arg(apps.countFor(pane.appName))

            TextButton {
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Clear")
                enabled: apps.countFor(pane.appName) > 0
                onClicked: Store.lockscreenIpc(["notifications", "clearApp", pane.appName])
            }
        }
    }
}
