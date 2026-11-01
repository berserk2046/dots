import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Widgets

// Trash at the end of the dock: click to open, drop files to move them to the trash,
// right-click for Open / Empty Trash. Uses the freedesktop trash through `gio`.
Item {
    id: trash

    property real size: 48
    property bool showLabel: true
    property bool menuOpen: false
    property string edge: "bottom" // screen edge the dock sits on

    readonly property string filesDir: (Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share")
                                       + "/Trash/files"
    readonly property int itemCount: files.count
    readonly property bool full: itemCount > 0
    readonly property string iconSource: Quickshell.iconPath(full ? "user-trash-full" : "user-trash")

    signal menuRequested
    signal dismissRequested

    width: size
    height: size

    Behavior on size {
        NumberAnimation {
            duration: 90
            easing.type: Easing.OutCubic
        }
    }

    function open() {
        Quickshell.execDetached(["gio", "open", "trash:///"]);
    }

    function empty() {
        Quickshell.execDetached(["gio", "trash", "--empty"]);
    }

    function fileUrls(urls) {
        return urls.map(String).filter(url => url.startsWith("file://"));
    }

    FolderListModel {
        id: files

        folder: "file://" + trash.filesDir
        showHidden: true
        showDotAndDotDot: false
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: -3
        radius: 12
        color: DockTheme.dropHighlight
        visible: dropArea.containsDrag
    }

    // Plain Image with a fixed sourceSize: IconImage ties sourceSize to its current size, so
    // every magnification step reloaded the icon (asynchronously, blank meanwhile) and it blinked.
    Image {
        anchors.fill: parent
        sourceSize.width: 128 // render resolution; scaled down to the current size
        sourceSize.height: 128
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        source: trash.iconSource
        asynchronous: true
    }

    // Name label, on the inner side of the icon.
    Rectangle {
        x: trash.edge === "left" ? parent.width + 8 : trash.edge === "right" ? -width - 8 : (parent.width - width) / 2
        y: trash.edge === "top" ? parent.height + 8 : trash.edge === "bottom" ? -height - 8 : (parent.height - height) / 2
        width: label.implicitWidth + 16
        height: label.implicitHeight + 8
        radius: 6
        color: DockTheme.menu
        visible: trash.showLabel && (mouse.containsMouse || dropArea.containsDrag)

        Text {
            id: label

            anchors.centerIn: parent
            text: qsTr("Trash")
            color: DockTheme.text
            font.family: "SF Pro"
            font.pixelSize: 12
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: event => {
            // As on macOS, any click while a menu is open only closes it.
            if (trash.menuOpen)
                trash.dismissRequested();
            else if (event.button === Qt.RightButton)
                trash.menuRequested();
            else
                trash.open();
        }
    }

    DropArea {
        id: dropArea

        anchors.fill: parent
        onEntered: drag => drag.accepted = drag.hasUrls && trash.fileUrls(drag.urls).length > 0
        onDropped: drop => {
            const urls = trash.fileUrls(drop.urls);
            if (urls.length === 0) {
                drop.accepted = false;
                return;
            }
            Quickshell.execDetached(["gio", "trash", ...urls]);
            drop.acceptProposedAction();
        }
    }
}
