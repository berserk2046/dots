import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Widgets

// macOS lock screen media card: artwork, title and artist, previous / play-pause / next.
// Prefers Spotify, then whichever player is playing. Hidden while no player has a track.
Rectangle {
    id: card

    readonly property var players: Mpris.players.values
    readonly property var player: players.find(p => p.identity === "Spotify" && p.trackTitle) ?? players.find(p => p.isPlaying) ?? players.find(p => p.trackTitle) ?? null

    visible: player !== null
    width: 380
    height: 84
    radius: 20
    color: Qt.rgba(1, 1, 1, 0.16)

    ClippingRectangle {
        id: artFrame

        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        width: 60
        height: 60
        radius: 10
        color: Qt.rgba(1, 1, 1, 0.12)

        Image {
            anchors.fill: parent
            source: card.player?.trackArtUrl ?? ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize: Qt.size(120, 120)
        }

        Text {
            anchors.centerIn: parent
            visible: !(card.player?.trackArtUrl)
            text: Theme.iMusic
            color: Theme.textSecondary
            font.family: Theme.iconFont
            font.pixelSize: 26
        }
    }

    Column {
        anchors.left: artFrame.right
        anchors.leftMargin: 12
        anchors.right: controls.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Text {
            width: parent.width
            text: card.player?.trackTitle ?? ""
            elide: Text.ElideRight
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 14
            font.weight: Font.DemiBold
        }

        Text {
            width: parent.width
            text: card.player?.trackArtist ?? ""
            elide: Text.ElideRight
            color: Theme.textSecondary
            font.family: Theme.font
            font.pixelSize: 13
        }
    }

    Row {
        id: controls

        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        Repeater {
            model: [
                { glyph: Theme.iPrevious, size: 22, enabled: card.player?.canGoPrevious ?? false, action: () => card.player.previous() },
                { glyph: card.player?.isPlaying ? Theme.iPause : Theme.iPlay, size: 26, enabled: card.player?.canTogglePlaying ?? false, action: () => card.player.togglePlaying() },
                { glyph: Theme.iNext, size: 22, enabled: card.player?.canGoNext ?? false, action: () => card.player.next() }
            ]

            Text {
                required property var modelData

                width: 30
                height: 30
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: modelData.glyph
                color: modelData.enabled ? Theme.text : Theme.textTertiary
                font.family: Theme.iconFont
                font.pixelSize: modelData.size

                MouseArea {
                    anchors.fill: parent
                    enabled: parent.modelData.enabled
                    cursorShape: Qt.PointingHandCursor
                    onClicked: parent.modelData.action()
                }
            }
        }
    }
}
