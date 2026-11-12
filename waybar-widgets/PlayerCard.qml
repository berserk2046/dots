import QtQuick
import Quickshell
import qs.common
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Services.Mpris

// One MPRIS player: artwork, title, artist, app, previous / play-pause / next and a seek bar.
// Used by the Sound panel and, larger, by the Now Playing popup.
Item {
    id: player

    required property MprisPlayer p
    property bool shown: false
    // 1 in the Sound panel; larger in the Now Playing popup of the bar's Spotify item.
    property real zoom: 1
    // The song before and after this one, from Spotify's Web API (spotify-queue.py; needs a one-time login).
    property bool showQueue: false
    property var queue: ({})

    function formatTime(seconds) {
        if (!(seconds >= 0) || !isFinite(seconds))
            return "0:00";
        const s = Math.floor(seconds);
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }

    component MediaButton: Rectangle {
        id: mediaButton

        property string glyph
        property int size: 18 * player.zoom
        signal clicked

        width: 30 * player.zoom
        height: width
        radius: width / 2
        opacity: enabled ? 1 : 0.35
        color: buttonMouse.pressed ? Theme.pressed : buttonMouse.containsMouse ? Theme.hover : "transparent"

        Glyph {
            anchors.centerIn: parent
            text: mediaButton.glyph
            size: mediaButton.size
        }

        MouseArea {
            id: buttonMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: mediaButton.clicked()
        }
    }

    readonly property bool hasLength: p.lengthSupported && p.length > 0
    // Spotify track ID; the title and artist then open the track and the artist page in Spotify.
    readonly property string spotifyTrack: /open\.spotify\.com\/track\/(\w+)/.exec(p.metadata["xesam:url"] ?? "")?.[1] ?? ""

    // MPRIS has no artist ID, so it is read from the track's public page (music:musician);
    // falls back to searching the artist's name.
    function openInSpotify(artist) {
        Quickshell.execDetached(["sh", "-c", artist
            ? 'id=$(curl -sL -m 5 -A Mozilla/5.0 "https://open.spotify.com/track/$1" | grep -oE "music:musician\" content=\"[^\"]+" | head -n 1 | sed "s#.*/artist/##"); '
              + 'if [ -n "$id" ]; then xdg-open "spotify:artist:$id"; else xdg-open "spotify:search:$2"; fi'
            : 'xdg-open "spotify:track:$1"', "sh", spotifyTrack, p.trackArtist]);
        Quickshell.execDetached(["hyprctl", "dispatch", 'hl.dsp.focus({ window = "class:^(spotify|Spotify)$" })']);
    }

    component SpotifyLink: MouseArea {
        property bool artist: false

        anchors.fill: parent
        enabled: player.spotifyTrack !== ""
        cursorShape: Qt.PointingHandCursor
        onClicked: player.openInSpotify(artist)
    }

    height: (64 + (hasLength ? 18 : 0)) * zoom + (queueColumn.visible ? queueColumn.height + 10 : 0)

    // MPRIS doesn't push position updates; ask for them while visible.
    Timer {
        interval: 1000
        repeat: true
        running: player.shown && player.p.isPlaying && player.p.positionSupported
        onTriggered: player.p.positionChanged()
    }

    ClippingRectangle {
        id: art

        x: 8
        y: 8
        width: 48 * player.zoom
        height: width
        radius: 8 * player.zoom
        color: Theme.circle

        Glyph {
            anchors.centerIn: parent
            visible: cover.status !== Image.Ready
            text: Theme.iMusic
            size: 22 * player.zoom
            color: Theme.textSecondary
        }

        Image {
            id: cover

            anchors.fill: parent
            source: player.p.trackArtUrl ?? ""
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 192
            sourceSize.height: 192
            asynchronous: true
            visible: status === Image.Ready
        }
    }

    Column {
        anchors.left: art.right
        anchors.leftMargin: 10
        anchors.right: controls.left
        anchors.rightMargin: 6
        anchors.verticalCenter: art.verticalCenter
        spacing: 1

        Text {
            textFormat: Text.PlainText
            width: parent.width
            elide: Text.ElideRight
            text: player.p.trackTitle || player.p.identity
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: Theme.fontSize(13 * player.zoom)
            font.weight: Font.DemiBold

            SpotifyLink {}
        }

        Text {
            textFormat: Text.PlainText
            width: parent.width
            elide: Text.ElideRight
            text: player.p.trackArtist || player.p.trackAlbum || player.p.identity
            color: Theme.textSecondary
            font.family: Theme.font
            font.pixelSize: Theme.fontSize(12 * player.zoom)

            SpotifyLink {
                artist: true
            }
        }

        Text {
            textFormat: Text.PlainText
            width: parent.width
            elide: Text.ElideRight
            visible: (player.p.trackArtist || player.p.trackAlbum) !== ""
            text: player.p.identity
            color: Theme.textTertiary
            font.family: Theme.font
            font.pixelSize: Theme.fontSize(11 * player.zoom)
        }
    }

    Row {
        id: controls

        anchors.right: parent.right
        anchors.rightMargin: 4
        anchors.verticalCenter: art.verticalCenter

        MediaButton {
            glyph: Theme.iPrevious
            enabled: player.p.canGoPrevious
            onClicked: player.p.previous()
        }
        MediaButton {
            glyph: player.p.isPlaying ? Theme.iPause : Theme.iPlay
            size: 22 * player.zoom
            enabled: player.p.canTogglePlaying
            onClicked: player.p.togglePlaying()
        }
        MediaButton {
            glyph: Theme.iNext
            enabled: player.p.canGoNext
            onClicked: player.p.next()
        }
    }

    // Progress; click to seek.
    Item {
        id: progress

        visible: player.hasLength
        anchors.top: art.bottom
        anchors.topMargin: 6 * player.zoom
        x: 8
        width: parent.width - 16
        height: 14

        Text {
            textFormat: Text.PlainText
            id: elapsed

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 34 * player.zoom
            text: player.formatTime(player.p.position)
            color: Theme.textTertiary
            font.family: Theme.font
            font.pixelSize: Theme.fontSize(10 * player.zoom)
            font.features: {
                "tnum": 1
            }
        }

        Rectangle {
            id: bar

            anchors.left: elapsed.right
            anchors.right: total.left
            anchors.verticalCenter: parent.verticalCenter
            height: 4
            radius: 2
            color: Theme.track

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, player.p.position / player.p.length))
                height: parent.height
                radius: 2
                color: Theme.textSecondary
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                enabled: player.p.canSeek
                cursorShape: Qt.PointingHandCursor
                onClicked: event => player.p.position = player.p.length * Math.max(0, Math.min(1, (event.x - 6) / bar.width))
            }
        }

        Text {
            textFormat: Text.PlainText
            id: total

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 34 * player.zoom
            horizontalAlignment: Text.AlignRight
            text: player.formatTime(player.p.length)
            color: Theme.textTertiary
            font.family: Theme.font
            font.pixelSize: Theme.fontSize(10 * player.zoom)
            font.features: {
                "tnum": 1
            }
        }
    }

    // Asked when the card opens and a moment after the song changes (the binding restarts it), once
    // Spotify has recorded the previous song.
    Timer {
        interval: 1500
        running: player.showQueue && player.shown && player.spotifyTrack !== ""
        onTriggered: queueProc.running = true
    }

    Process {
        id: queueProc

        command: ["python3", decodeURIComponent(Qt.resolvedUrl("spotify-queue.py").toString().replace(/^file:\/\//, ""))]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    player.queue = JSON.parse(text);
                } catch (e) {
                    player.queue = {};
                }
            }
        }
    }

    Column {
        id: queueColumn

        visible: player.showQueue && player.spotifyTrack !== "" && !!(player.queue.previous || player.queue.next)
        anchors.top: player.hasLength ? progress.bottom : art.bottom
        anchors.topMargin: 10
        x: 8
        width: parent.width - 16
        spacing: 6

        Repeater {
            model: [
                { label: qsTr("Previously"), track: player.queue.previous },
                { label: qsTr("Up Next"), track: player.queue.next }
            ].filter(row => row.track)

            Item {
                required property var modelData

                width: parent.width
                height: 36 * player.zoom

                ClippingRectangle {
                    id: rowArt

                    anchors.verticalCenter: parent.verticalCenter
                    width: 32 * player.zoom
                    height: width
                    radius: 5 * player.zoom
                    color: Theme.circle

                    Image {
                        anchors.fill: parent
                        source: modelData.track.art
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                }

                Column {
                    anchors.left: rowArt.right
                    anchors.leftMargin: 10
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        textFormat: Text.PlainText
                        width: parent.width
                        elide: Text.ElideRight
                        text: modelData.label
                        color: Theme.textTertiary
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize(10 * player.zoom)
                    }

                    Text {
                        textFormat: Text.PlainText
                        width: parent.width
                        elide: Text.ElideRight
                        text: modelData.track.title + "  ·  " + modelData.track.artist
                        color: Theme.textSecondary
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize(11 * player.zoom)
                    }
                }

                // Opens that song in Spotify
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Launch.app(["xdg-open", modelData.track.uri])
                }
            }
        }
    }
}
