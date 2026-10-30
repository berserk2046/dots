import QtQuick
import Quickshell
import Quickshell.Widgets

// One notification in the macOS style: app icon, app name and time, title and text.
// Used on the lock screen and for the banners while unlocked.
Rectangle {
    id: card

    required property var notification
    // When it arrived, for the "now" / "5m ago" label
    property date received: new Date()
    property bool showText: true
    property bool closable: false
    // Ticks to refresh the relative time
    property int now: Date.now()

    signal clicked
    signal closeClicked

    function ago(date) {
        const minutes = Math.floor((now - date) / 60000);
        if (minutes < 1)
            return qsTr("now");
        if (minutes < 60)
            return qsTr("%1m ago").arg(minutes);
        const today = new Date(now);
        today.setHours(0, 0, 0, 0);
        if (date >= today)
            return Qt.formatTime(date, "h:mm AP");
        if (date >= today - 86400000)
            return qsTr("Yesterday");
        return Qt.formatDate(date, "MMM d");
    }

    readonly property string iconSource: {
        const n = notification;
        if (n.image)
            return n.image;
        if (n.appIcon)
            return n.appIcon.startsWith("/") || n.appIcon.includes("://") ? n.appIcon : Quickshell.iconPath(n.appIcon, true);
        return n.desktopEntry ? Quickshell.iconPath(n.desktopEntry, true) : "";
    }

    width: 380
    height: content.implicitHeight + 24
    radius: 18
    color: Qt.rgba(1, 1, 1, 0.16)

    MouseArea {
        id: hover

        anchors.fill: parent
        hoverEnabled: true
        onClicked: card.clicked()
    }

    ClippingRectangle {
        id: icon

        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.top: parent.top
        anchors.topMargin: 12
        width: 34
        height: 34
        radius: 8
        color: card.iconSource ? "transparent" : Qt.rgba(1, 1, 1, 0.15)

        Image {
            anchors.fill: parent
            source: card.iconSource
            fillMode: Image.PreserveAspectFit
            sourceSize: Qt.size(68, 68)
            asynchronous: true
        }

        Text {
            anchors.centerIn: parent
            visible: !card.iconSource
            text: Theme.iApp
            color: Theme.text
            font.family: Theme.iconFont
            font.pixelSize: 18
        }
    }

    Column {
        id: content

        anchors.left: icon.right
        anchors.leftMargin: 10
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.top: parent.top
        anchors.topMargin: 12
        spacing: 2

        Item {
            width: parent.width
            height: appName.implicitHeight

            Text {
                id: appName

                anchors.left: parent.left
                anchors.right: time.left
                anchors.rightMargin: 8
                text: card.notification.appName || qsTr("Notification")
                elide: Text.ElideRight
                color: Theme.textSecondary
                font.family: Theme.font
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }

            Text {
                id: time

                anchors.right: parent.right
                visible: !(card.closable && hover.containsMouse)
                text: card.ago(card.received)
                color: Theme.textSecondary
                font.family: Theme.font
                font.pixelSize: 12
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: card.closable && hover.containsMouse
                text: Theme.iClose
                color: Theme.text
                font.family: Theme.iconFont
                font.pixelSize: 15

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: card.closeClicked()
                }
            }
        }

        Text {
            width: parent.width
            visible: card.showText && text !== ""
            text: card.notification.summary
            elide: Text.ElideRight
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 14
            font.weight: Font.DemiBold
        }

        Text {
            width: parent.width
            visible: card.showText && text !== ""
            text: card.notification.body
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            maximumLineCount: 3
            elide: Text.ElideRight
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 13
        }
    }
}
