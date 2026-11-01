import QtQuick
import Quickshell
import qs.shared

// Users & Groups: your picture (~/.face) and full name, shown in the power menu, on the lock screen
// and on the login screen.
Column {
    id: pane

    property string pageTitle: ""
    property string fullName: ""
    property string shell: ""
    property string status: ""

    spacing: 10

    Component.onCompleted: load()

    function load() {
        Store.run(["sh", "-c", 'getent passwd "$USER"'], (code, out) => {
            const fields = out.trim().split(":");
            pane.fullName = (fields[4] ?? "").split(",")[0];
            pane.shell = fields[6] ?? "";
        });
    }

    Item {
        width: parent.width
        height: 150

        Avatar {
            id: avatar

            anchors.horizontalCenter: parent.horizontalCenter
            y: 4
            width: 96
            height: 96
            name: pane.fullName || Quickshell.env("USER")
            version: Ui.userVersion

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: 46
                height: 18
                radius: 9
                color: "#cc000000"
                visible: avatarMouse.containsMouse

                Text {
                    anchors.centerIn: parent
                    text: qsTr("Edit")
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize(11)
                }
            }

            MouseArea {
                id: avatarMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Store.run(["zenity", "--file-selection", "--title=" + qsTr("Choose a picture"), "--file-filter=" + qsTr("Pictures") + " | *.jpg *.jpeg *.png *.webp"], (code, out) => {
                    const file = out.trim();
                    if (code !== 0 || file === "")
                        return;
                    Store.run(["cp", file, Store.home + "/.face"], () => Ui.userVersion++);
                })
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: avatar.bottom
            anchors.topMargin: 10
            text: pane.fullName || Quickshell.env("USER")
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: Theme.fontSize(18)
            font.weight: Font.DemiBold
        }
    }

    SettingsGroup {
        SettingRow {
            title: qsTr("Full name")
            subtitle: pane.status

            Field {
                anchors.verticalCenter: parent.verticalCenter
                width: 220
                text: pane.fullName
                onAccepted: {
                    const name = text.trim();
                    if (name === pane.fullName || /[:,=]/.test(name))
                        return;
                    pane.status = qsTr("Saving…");
                    Store.run(["sudo", "-n", "chfn", "-f", name, Quickshell.env("USER")], (code, out, err) => {
                        pane.status = code === 0 ? "" : qsTr("Failed: %1").arg(err.trim() || qsTr("sudo needs a password?"));
                        pane.load();
                        Ui.userVersion++;
                    });
                }
            }
        }

        SettingRow {
            title: qsTr("Account name")

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Quickshell.env("USER")
                color: Theme.textSecondary
                font.family: Theme.font
                font.pixelSize: Theme.fontSize(12)
            }
        }

        SettingRow {
            title: qsTr("Home folder")

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Store.home
                color: Theme.textSecondary
                font.family: Theme.font
                font.pixelSize: Theme.fontSize(12)
            }
        }

        SettingRow {
            title: qsTr("Login shell")

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: pane.shell
                color: Theme.textSecondary
                font.family: Theme.font
                font.pixelSize: Theme.fontSize(12)
            }
        }
    }

    Caption {
        text: qsTr("Click the picture to change it, and press Enter to save the name. Both show in the power menu and on the lock screen.")
    }

    SettingsGroup {
        LoginScreenRow {}
    }
}
