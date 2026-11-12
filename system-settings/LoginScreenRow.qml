import QtQuick
import qs.shared

// Copies the lock screen, your picture, the wallpaper and these settings to the login screen
// (greetd), which can't read your home folder. Runs the root-owned helper greetd-install (from
// system/greetd-install.sh, installed by system/install.sh) through pkexec, which asks for an
// administrator's password in the desktop's dialog.
SettingRow {
    id: row

    property string status: ""
    property bool running: false

    title: qsTr("Login screen")
    subtitle: status || qsTr("Copy the picture, message and wallpaper to the login screen")

    Spinner {
        anchors.verticalCenter: parent.verticalCenter
        running: row.running
    }

    TextButton {
        anchors.verticalCenter: parent.verticalCenter
        text: qsTr("Update")
        enabled: !row.running
        onClicked: {
            row.running = true;
            row.status = qsTr("Updating…");
            const wallpaper = Store.get("lockScreen", "wallpaper", "") || Store.get("wallpaper", "path", Store.defaultWallpaper);
            Store.run(["pkexec", "/usr/local/libexec/desktop-helpers/greetd-install", wallpaper], (code, out, err) => {
                row.running = false;
                row.status = code === 0 ? qsTr("Updated") : code === 126 ? "" : code === 127 ? qsTr("Not allowed, or the helper isn't installed (sudo sh system/install.sh)")
                                                                                             : qsTr("Failed: %1").arg(err.trim().split("\n").pop());
            });
        }
    }
}
