import QtQuick
import qs.shared

// Control Center: which modules show in the menu bar (waybar's modules-right) and the clock format.
Column {
    id: pane

    property string pageTitle: ""

    // waybar module -> name and icon, in menu bar order
    readonly property var modules: [
        {
            id: "tray",
            title: qsTr("App Icons (tray)"),
            glyph: Theme.iApps,
            color: "#8e8e93"
        },
        {
            id: "custom/spotify",
            title: qsTr("Now Playing (Spotify)"),
            glyph: Theme.iMusic,
            color: "#1db954"
        },
        {
            id: "mpd",
            title: qsTr("Music (MPD)"),
            glyph: Theme.iMusic,
            color: "#ff375f"
        },
        {
            id: "privacy",
            title: qsTr("Microphone & Screen Sharing in Use"),
            glyph: Theme.iMic,
            color: "#ff9f0a"
        },
        {
            id: "custom/keyboard",
            title: qsTr("Keyboard Layout"),
            glyph: Theme.iKeyboard,
            color: "#8e8e93"
        },
        {
            id: "custom/system",
            title: qsTr("CPU & Memory"),
            glyph: Theme.iDisk,
            color: "#8e8e93"
        },
        {
            id: "bluetooth",
            title: qsTr("Bluetooth"),
            glyph: Theme.iBluetooth,
            color: "#0a84ff"
        },
        {
            id: "network",
            title: qsTr("Wi-Fi"),
            glyph: Theme.iWifi,
            color: "#0a84ff"
        },
        {
            id: "pulseaudio",
            title: qsTr("Sound"),
            glyph: Theme.iVolumeHigh,
            color: "#ff375f"
        },
        {
            id: "backlight",
            title: qsTr("Display Brightness"),
            glyph: Theme.iBrightness,
            color: "#0a84ff"
        },
        {
            id: "battery",
            title: qsTr("Battery"),
            glyph: Theme.iBattery,
            color: "#30d158"
        },
        {
            id: "custom/notifications",
            title: qsTr("Notifications"),
            glyph: Theme.iBell,
            color: "#ff453a"
        }
    ]
    readonly property var hidden: Store.get("controlCenter", "hidden", [])
    readonly property var clock: Store.get("controlCenter", "clock", {})

    spacing: 10

    function setShown(id, shown) {
        const next = hidden.filter(h => h !== id);
        if (!shown)
            next.push(id);
        Store.set("controlCenter", "hidden", next);
        // The clock always ends the menu bar, as on macOS.
        const list = [...modules.map(m => m.id).filter(m => !next.includes(m)), "custom/date"];
        Store.runQueued("waybar", ["python3", Store.script("waybar-config.py"), "modules", JSON.stringify(list)]);
    }

    function setClock(key, value) {
        const next = Object.assign({
            date: true,
            weekday: true,
            hours24: false,
            seconds: false
        }, clock);
        next[key] = value;
        Store.set("controlCenter", "clock", next);
        // As on macOS: "Fri Oct 31  9:41 AM"
        const time = (next.hours24 ? "%H:%M" : "%-l:%M") + (next.seconds ? ":%S" : "") + (next.hours24 ? "" : " %p");
        const day = [next.weekday ? "%a" : "", next.date ? "%b %-d" : ""].filter(p => p).join(" ");
        const format = [day, time].filter(p => p).join("  ");
        Store.runQueued("waybar", ["python3", Store.script("waybar-config.py"), "clock", format, next.seconds ? "1" : "60"]);
    }

    GroupTitle {
        text: qsTr("Menu Bar")
    }

    SettingsGroup {
        Repeater {
            model: pane.modules

            SettingRow {
                id: moduleRow

                required property var modelData

                title: modelData.title
                glyph: modelData.glyph
                tileColor: modelData.color

                Toggle {
                    anchors.verticalCenter: parent.verticalCenter
                    checked: !pane.hidden.includes(moduleRow.modelData.id)
                    onToggled: on => pane.setShown(moduleRow.modelData.id, on)
                }
            }
        }
    }

    Caption {
        text: qsTr("Waybar reloads right away. The Arch menu and the app name stay on the left, the workspaces in the middle and the clock at the end.")
    }

    GroupTitle {
        text: qsTr("Clock")
    }

    SettingsGroup {
        SettingRow {
            title: qsTr("Show the date")

            Toggle {
                anchors.verticalCenter: parent.verticalCenter
                checked: pane.clock.date !== false
                onToggled: on => pane.setClock("date", on)
            }
        }

        SettingRow {
            title: qsTr("Show the day of the week")

            Toggle {
                anchors.verticalCenter: parent.verticalCenter
                checked: pane.clock.weekday !== false
                onToggled: on => pane.setClock("weekday", on)
            }
        }

        SettingRow {
            title: qsTr("Use a 24-hour clock")

            Toggle {
                anchors.verticalCenter: parent.verticalCenter
                checked: pane.clock.hours24 === true
                onToggled: on => pane.setClock("hours24", on)
            }
        }

        SettingRow {
            title: qsTr("Display the time with seconds")

            Toggle {
                anchors.verticalCenter: parent.verticalCenter
                checked: pane.clock.seconds === true
                onToggled: on => pane.setClock("seconds", on)
            }
        }
    }
}
