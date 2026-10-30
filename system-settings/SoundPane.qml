import QtQuick
import Quickshell
import Quickshell.Io
import qs.shared

// Sound: the waybar Sound panel (output/input volume and device, input level, Now Playing, app volumes),
// plus the alert sound and alert volume that notifications play (lock screen shell, through pw-play).
Column {
    id: pane

    property string pageTitle: ""
    property var userSounds: [] // paths in ~/.local/share/sounds
    readonly property string alert: Store.get("sound", "alert", "Ping")
    readonly property real alertVolume: Store.get("sound", "alertVolume", 0.6)

    spacing: 10

    Component.onCompleted: Store.run(["sh", "-c", 'find "$HOME/.local/share/sounds" -maxdepth 2 -type f \\( -name "*.wav" -o -name "*.ogg" -o -name "*.oga" -o -name "*.flac" -o -name "*.mp3" \\) 2>/dev/null | sort'],
                                     (code, out) => pane.userSounds = out.split("\n").filter(p => p))

    function pathOf(sound) {
        return sound.startsWith("/") ? sound : Store.dir + "/sounds/" + sound + ".wav";
    }

    function preview(sound, volume) {
        if (sound !== "")
            Quickshell.execDetached(["pw-play", "--volume", String(volume), pathOf(sound)]);
    }

    SettingsGroup {
        Item {
            width: parent.width
            height: panel.implicitHeight + 16

            AudioPanel {
                id: panel

                x: 8
                y: 8
                width: parent.width - 16
                shown: true
            }
        }
    }

    GroupTitle {
        text: qsTr("Sound Effects")
    }

    SettingsGroup {
        SettingRow {
            title: qsTr("Alert sound")
            subtitle: qsTr("Played for notifications")

            Dropdown {
                anchors.verticalCenter: parent.verticalCenter
                options: [
                    {
                        label: qsTr("None"),
                        value: ""
                    },
                    ...["Bell", "Bubble", "Chime", "Ping", "Pop", "Tick"].map(n => ({
                                label: n,
                                value: n
                            })),
                    ...pane.userSounds.map(p => ({
                                label: p.split("/").pop().replace(/\.[^.]+$/, ""),
                                value: p
                            }))
                ]
                value: pane.alert
                onPicked: v => {
                    Store.set("sound", "alert", v);
                    pane.preview(v, pane.alertVolume);
                }
            }
        }

        SettingRow {
            title: qsTr("Alert volume")
            enabled: pane.alert !== ""
            opacity: enabled ? 1 : 0.4
            below: SettingSlider {
                id: volumeSlider

                width: parent.width
                from: 0.05
                to: 1
                value: pane.alertVolume
                onMoved: v => Store.set("sound", "alertVolume", Math.round(v * 100) / 100)
                // Preview once the knob is let go
                onDraggingChanged: {
                    if (!dragging)
                        pane.preview(pane.alert, pane.alertVolume);
                }
            }
        }
    }

    Caption {
        text: qsTr("Silent during Do Not Disturb, and for apps with sounds turned off in Notifications. Add your own sounds to ~/.local/share/sounds.")
    }

    SettingsGroup {
        SettingRow {
            title: qsTr("Advanced Sound Settings…")
            subtitle: qsTr("Profiles, ports and every stream, in pwvucontrol")
            chevron: true
            onClicked: Store.launch("pwvucontrol")
        }
    }
}
