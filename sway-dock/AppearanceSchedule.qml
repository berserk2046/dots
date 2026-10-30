import QtQuick
import Quickshell

// Appearance "Auto" from System Settings: light from 7:00 to 19:00, dark otherwise. Checked every
// minute while Auto is picked; the switch itself is System Settings' appearance.sh.
Scope {
    id: schedule

    property string mode: "dark"
    property string applied: ""

    function check() {
        if (mode !== "auto") {
            applied = "";
            return;
        }
        const hour = new Date().getHours();
        const wanted = hour >= 7 && hour < 19 ? "light" : "dark";
        if (wanted === applied)
            return;
        applied = wanted;
        Quickshell.execDetached(["sh", Quickshell.env("HOME") + "/.config/system-settings/appearance.sh", "scheme", wanted]);
    }

    onModeChanged: check()
    Component.onCompleted: check()

    Timer {
        interval: 60000
        repeat: true
        running: schedule.mode === "auto"
        onTriggered: schedule.check()
    }
}
