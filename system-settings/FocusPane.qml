import QtQuick
import Quickshell
import qs.shared

// Focus: Do Not Disturb by hand or on a schedule, and the apps that may still notify meanwhile.
Column {
    id: pane

    property string pageTitle: ""
    readonly property var schedule: Store.get("focus", "schedule", {})
    readonly property var allowed: Store.get("focus", "allowedApps", [])

    spacing: 10

    function setSchedule(key, value) {
        const next = Object.assign({
            enabled: false,
            from: "22:00",
            to: "7:00"
        }, schedule);
        next[key] = value;
        Store.set("focus", "schedule", next);
    }

    // Stored times may be "07:00" or "7:00"; the pickers use the latter.
    function normalize(time) {
        const [h, m] = String(time).split(":").map(Number);
        return (h || 0) + ":" + String(m || 0).padStart(2, "0");
    }

    NotificationApps {
        id: apps
    }

    SettingsGroup {
        SettingRow {
            title: qsTr("Do Not Disturb")
            subtitle: apps.doNotDisturb ? qsTr("On") : qsTr("Off")
            glyph: Theme.iFocus
            tileColor: "#5e5ce6"

            Toggle {
                anchors.verticalCenter: parent.verticalCenter
                checked: apps.doNotDisturb
                onToggled: on => apps.setDnd(on)
            }
        }
    }

    Caption {
        text: qsTr("Also from the Notification Center or by right-clicking the bell in the menu bar.")
    }

    GroupTitle {
        text: qsTr("Schedule")
    }

    SettingsGroup {
        SettingRow {
            title: qsTr("Turn on automatically")
            subtitle: qsTr("Every day")

            Toggle {
                anchors.verticalCenter: parent.verticalCenter
                checked: pane.schedule.enabled === true
                onToggled: on => pane.setSchedule("enabled", on)
            }
        }

        SettingRow {
            title: qsTr("From")
            enabled: pane.schedule.enabled === true
            opacity: enabled ? 1 : 0.4

            Dropdown {
                anchors.verticalCenter: parent.verticalCenter
                options: Ui.halfHours
                value: pane.normalize(pane.schedule.from ?? "22:00")
                onPicked: v => pane.setSchedule("from", v)
            }
        }

        SettingRow {
            title: qsTr("To")
            enabled: pane.schedule.enabled === true
            opacity: enabled ? 1 : 0.4

            Dropdown {
                anchors.verticalCenter: parent.verticalCenter
                options: Ui.halfHours
                value: pane.normalize(pane.schedule.to ?? "7:00")
                onPicked: v => pane.setSchedule("to", v)
            }
        }
    }

    Caption {
        text: qsTr("Turning Do Not Disturb off during the schedule keeps it off until the scheduled period ends.")
    }

    GroupTitle {
        text: qsTr("Allowed Notifications")

        Dropdown {
            anchors.verticalCenter: parent.verticalCenter
            placeholder: qsTr("Add App…")
            // Apps that have notified so far, then installed apps (notifications carry the app's name)
            options: Array.from(new Set([...apps.names, ...DesktopEntries.applications.values.filter(e => !e.noDisplay).map(e => e.name).sort((a, b) => a.localeCompare(b))])).filter(n => !pane.allowed.includes(n))
            value: undefined
            enabled: options.length > 0
            onPicked: v => Store.set("focus", "allowedApps", [...pane.allowed, v])
        }
    }

    SettingsGroup {
        SettingRow {
            visible: pane.allowed.length === 0
            title: qsTr("No apps; only critical notifications break through")
            titleColor: Theme.textSecondary
        }

        Repeater {
            model: pane.allowed

            SettingRow {
                required property string modelData

                title: modelData
                iconSource: apps.iconFor(modelData)
                glyph: Theme.iBell
                tileColor: "#48484a"

                TextButton {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Remove")
                    onClicked: Store.set("focus", "allowedApps", pane.allowed.filter(n => n !== modelData))
                }
            }
        }
    }
}
