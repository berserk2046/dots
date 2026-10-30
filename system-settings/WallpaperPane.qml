import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import qs.shared

// Wallpaper: pick a picture from your wallpaper folders, how it fits, and which display gets it.
// Set through hyprpaper (Store.writeWallpaper); the lock screen uses it too unless it has its own.
Column {
    id: pane

    property string pageTitle: ""
    property var monitorNames: []
    // "" = all displays, or one display's name
    property string target: ""

    readonly property var folders: Store.get("wallpaper", "folders", [Store.home + "/Pictures/Wallpapers"])
    readonly property string fit: Store.get("wallpaper", "fit", "cover")
    readonly property var perMonitor: Store.get("wallpaper", "monitors", {})
    readonly property string current: target !== "" && perMonitor[target] ? perMonitor[target]
                                                                         : Store.get("wallpaper", "path", Store.defaultWallpaper)

    spacing: 10

    Component.onCompleted: Store.run(["hyprctl", "monitors", "-j"], (code, out) => {
        try {
            pane.monitorNames = JSON.parse(out).map(m => m.name);
        } catch (error) {}
    })

    function choose(path) {
        if (target === "") {
            // One picture everywhere: drop the per-display ones.
            Store.setMany("wallpaper", {
                path: path,
                monitors: {}
            });
        } else {
            const next = Object.assign({}, perMonitor);
            next[target] = path;
            Store.set("wallpaper", "monitors", next);
        }
        Store.writeWallpaper(monitorNames);
    }

    function fileName(path) {
        return path.split("/").pop().replace(/\.[^.]+$/, "");
    }

    // ---- Current ----

    SettingsGroup {
        Item {
            width: parent.width
            height: 150

            Rectangle {
                id: previewFrame

                x: 14
                y: 14
                width: 196
                height: 122
                radius: 8
                color: "#000000"
                clip: true

                Image {
                    anchors.fill: parent
                    source: "file://" + pane.current
                    sourceSize.width: 392
                    fillMode: pane.fit === "contain" ? Image.PreserveAspectFit : pane.fit === "tile" ? Image.Tile : Image.PreserveAspectCrop
                    asynchronous: true
                }
            }

            Column {
                anchors.left: previewFrame.right
                anchors.leftMargin: 16
                anchors.right: parent.right
                anchors.rightMargin: 14
                y: 18
                spacing: 10

                Text {
                    width: parent.width
                    elide: Text.ElideMiddle
                    text: pane.fileName(pane.current)
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                }

                Row {
                    spacing: 8

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("Fit")
                        color: Theme.textSecondary
                        font.family: Theme.font
                        font.pixelSize: 12
                    }

                    Dropdown {
                        options: [
                            {
                                label: qsTr("Fill Screen"),
                                value: "cover"
                            },
                            {
                                label: qsTr("Fit to Screen"),
                                value: "contain"
                            },
                            {
                                label: qsTr("Tile"),
                                value: "tile"
                            }
                        ]
                        value: pane.fit
                        onPicked: v => {
                            Store.set("wallpaper", "fit", v);
                            Store.writeWallpaper(pane.monitorNames);
                        }
                    }
                }

                Row {
                    spacing: 8
                    visible: pane.monitorNames.length > 1

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("Show on")
                        color: Theme.textSecondary
                        font.family: Theme.font
                        font.pixelSize: 12
                    }

                    Dropdown {
                        options: [
                            {
                                label: qsTr("All Displays"),
                                value: ""
                            },
                            ...pane.monitorNames.map(n => ({
                                        label: n,
                                        value: n
                                    }))
                        ]
                        value: pane.target
                        onPicked: v => pane.target = v
                    }
                }

                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: Store.get("lockScreen", "wallpaper", "") ? qsTr("The lock screen has its own picture (Lock Screen settings).")
                                                                   : qsTr("Also shown on the lock screen.")
                    color: Theme.textSecondary
                    font.family: Theme.font
                    font.pixelSize: 11
                }
            }
        }
    }

    // ---- Folders ----

    Repeater {
        model: pane.folders

        Column {
            id: folderSection

            required property string modelData
            required property int index

            width: pane.width
            spacing: 8

            GroupTitle {
                text: folderSection.modelData.replace(Store.home, "~")

                TextButton {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: pane.folders.length > 1
                    text: qsTr("Remove")
                    onClicked: Store.set("wallpaper", "folders", pane.folders.filter((f, i) => i !== folderSection.index))
                }
            }

            FolderListModel {
                id: images

                folder: "file://" + folderSection.modelData
                nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.JPG", "*.JPEG", "*.PNG"]
                showDirs: false
                sortField: FolderListModel.Name
            }

            Flow {
                width: parent.width
                spacing: 10

                Repeater {
                    model: images

                    Rectangle {
                        id: thumb

                        required property string filePath
                        readonly property bool isCurrent: filePath === pane.current

                        width: (pane.width - 30) / 4
                        height: width * 0.625
                        radius: 7
                        color: "#1c1c1e"
                        border.width: isCurrent ? 3 : 0
                        border.color: Theme.accent

                        Image {
                            anchors.fill: parent
                            anchors.margins: thumb.isCurrent ? 4 : 0
                            source: "file://" + thumb.filePath
                            sourceSize.width: 300
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: thumbMouse.containsMouse ? "#26ffffff" : "transparent"
                        }

                        MouseArea {
                            id: thumbMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: pane.choose(thumb.filePath)
                        }
                    }
                }
            }

            Caption {
                visible: images.status === FolderListModel.Ready && images.count === 0
                text: qsTr("No pictures in this folder.")
            }
        }
    }

    Row {
        spacing: 8

        TextButton {
            text: qsTr("Add Folder…")
            onClicked: Store.run(["zenity", "--file-selection", "--directory", "--title=" + qsTr("Choose a wallpaper folder")], (code, out) => {
                const folder = out.trim();
                if (code === 0 && folder !== "" && !pane.folders.includes(folder))
                    Store.set("wallpaper", "folders", [...pane.folders, folder]);
            })
        }

        TextButton {
            text: qsTr("Choose a Picture…")
            onClicked: Store.run(["zenity", "--file-selection", "--title=" + qsTr("Choose a wallpaper"), "--file-filter=" + qsTr("Pictures") + " | *.jpg *.jpeg *.png *.webp"], (code, out) => {
                if (code === 0 && out.trim() !== "")
                    pane.choose(out.trim());
            })
        }
    }
}
