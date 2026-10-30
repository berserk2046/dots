import QtQuick
import qs.shared

// Copies the lock screen, your picture, the wallpaper and these settings to the login screen
// (greetd), which can't read your home folder. Runs lockscreen/greetd/install.sh with sudo.
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
            Store.run(["sudo", "-n", "sh", Store.lockscreenDir + "/greetd/install.sh", wallpaper], (code, out, err) => {
                row.running = false;
                row.status = code === 0 ? qsTr("Updated") : qsTr("Failed: %1").arg(err.trim().split("\n").pop() || qsTr("sudo needs a password?"));
            });
        }
    }
}
