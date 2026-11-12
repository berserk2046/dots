import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import Quickshell.Bluetooth

// Sound menu: output and input volume and device, Now Playing, and per-app volume.
Column {
    id: panel

    property bool shown: false

    readonly property var nodes: Pipewire.nodes.values
    // Filter on node type: properties (media.class etc.) only arrive once a node is tracked.
    readonly property var sinks: nodes.filter(n => n.type === PwNodeType.AudioSink)
    readonly property var sources: nodes.filter(n => n.type === PwNodeType.AudioSource)
    readonly property var streams: nodes.filter(n => n.type === PwNodeType.AudioOutStream)
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    // Paired Bluetooth audio devices that aren't connected, so they can be picked as outputs.
    readonly property var bluetoothAudio: (Bluetooth.devices.values ?? []).filter(d => d.paired && !d.connected
                                                                                 && (d.icon ?? "").startsWith("audio"))
    readonly property var players: Mpris.players.values

    width: parent?.width ?? 0
    spacing: 2

    // Device name without the ALSA profile suffix ("... Analog Stereo").
    function label(node) {
        if (!node)
            return "";
        const name = node.description || node.nickname || node.name;
        return name.replace(/ (Analog|Digital|Pro)( Stereo| Surround [\d.]+| Mono)?( \(.*\))?$/, "") || name;
    }

    function prop(node, ...keys) {
        for (const key of keys) {
            const value = node?.properties?.[key];
            if (value)
                return String(value).toLowerCase();
        }
        return "";
    }

    function deviceGlyph(node, input) {
        const kind = prop(node, "device.form-factor", "device.form_factor") + " "
                     + prop(node, "device.icon-name", "device.icon_name") + " " + (node?.name ?? "").toLowerCase();
        const bluetooth = prop(node, "device.api") === "bluez5" || kind.indexOf("bluez") >= 0;
        if (kind.indexOf("headset") >= 0 || kind.indexOf("hands-free") >= 0)
            return Theme.iHeadset;
        if (input)
            return Theme.iMic;
        if (kind.indexOf("headphone") >= 0)
            return Theme.iHeadphones;
        if (bluetooth)
            return Theme.iSpeakerBluetooth;
        if (kind.indexOf("hdmi") >= 0 || kind.indexOf("displayport") >= 0 || kind.indexOf("video-display") >= 0)
            return Theme.iMonitor;
        return Theme.iSpeaker;
    }

    function volumeGlyph(node) {
        const audio = node?.audio;
        if (!audio || audio.muted || audio.volume <= 0.001)
            return Theme.iVolumeMute;
        if (audio.volume < 0.34)
            return Theme.iVolumeLow;
        if (audio.volume < 0.67)
            return Theme.iVolumeMedium;
        return Theme.iVolumeHigh;
    }

    function setVolume(node, value) {
        if (!node?.audio)
            return;
        node.audio.volume = value;
        if (value > 0 && node.audio.muted)
            node.audio.muted = false;
    }

    // Volume and mute are only available for nodes bound by a tracker.
    PwObjectTracker {
        objects: [...panel.sinks, ...panel.sources, ...panel.streams]
    }

    PwNodePeakMonitor {
        id: inputPeak

        node: panel.source
        enabled: panel.shown && panel.source !== null
    }

    component Percent: Text {
        textFormat: Text.PlainText
        property PwNode node

        width: 34
        horizontalAlignment: Text.AlignRight
        text: node?.audio ? Math.round(node.audio.volume * 100) + "%" : ""
        color: Theme.textSecondary
        font.family: Theme.font
        font.pixelSize: Theme.fontSize(11)
        font.features: {
            "tnum": 1
        }
    }

    component DeviceRow: ListRow {
        id: deviceRow

        required property var modelData
        property bool input: false
        readonly property bool selected: modelData === (input ? panel.source : panel.sink)

        title: panel.label(modelData)
        bold: selected
        icon: IconCircle {
            active: deviceRow.selected
            glyph: panel.deviceGlyph(deviceRow.modelData, deviceRow.input)
        }
        onClicked: {
            if (input)
                Pipewire.preferredDefaultAudioSource = modelData;
            else
                Pipewire.preferredDefaultAudioSink = modelData;
        }
    }

    // ---- Output ----

    Item {
        width: parent.width
        height: 34

        Text {
            textFormat: Text.PlainText
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: qsTr("Sound")
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: Theme.fontSize(14)
            font.weight: Font.Bold
        }
    }

    Item {
        width: parent.width
        height: 34

        PillSlider {
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.right: outPercent.left
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            enabled: panel.sink?.audio != null
            value: panel.sink?.audio?.volume ?? 0
            dimmed: panel.sink?.audio?.muted ?? false
            glyph: panel.volumeGlyph(panel.sink)
            onMoved: v => panel.setVolume(panel.sink, v)
            onGlyphClicked: if (panel.sink?.audio)
                panel.sink.audio.muted = !panel.sink.audio.muted
        }

        Percent {
            id: outPercent

            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            node: panel.sink
        }
    }

    SectionLabel {
        text: qsTr("Output")
    }

    Repeater {
        model: panel.sinks

        DeviceRow {}
    }

    Repeater {
        model: panel.bluetoothAudio

        ListRow {
            id: btRow

            required property var modelData
            readonly property bool connecting: modelData.state === BluetoothDeviceState.Connecting

            title: modelData.name || modelData.deviceName
            subtitle: connecting ? qsTr("Connecting…") : qsTr("Bluetooth · not connected")
            icon: IconCircle {
                glyph: (btRow.modelData.icon ?? "").indexOf("head") >= 0 ? Theme.iHeadphones : Theme.iSpeakerBluetooth
                opacity: 0.7
            }
            trailing: Spinner {
                anchors.verticalCenter: parent.verticalCenter
                running: btRow.connecting
            }
            onClicked: {
                const adapter = modelData.adapter ?? Bluetooth.defaultAdapter;
                if (adapter && !adapter.enabled)
                    adapter.enabled = true;
                modelData.connect();
            }
        }
    }

    Text {
        textFormat: Text.PlainText
        x: 8
        visible: panel.sinks.length === 0
        height: 28
        verticalAlignment: Text.AlignVCenter
        text: Pipewire.ready ? qsTr("No output devices") : qsTr("Connecting to PipeWire…")
        color: Theme.textTertiary
        font.family: Theme.font
        font.pixelSize: Theme.fontSize(12)
    }

    // ---- Input ----

    Separator {}

    SectionLabel {
        text: qsTr("Input")
    }

    Item {
        width: parent.width
        height: 38
        visible: panel.source !== null

        PillSlider {
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.right: inPercent.left
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -2
            value: panel.source?.audio?.volume ?? 0
            dimmed: panel.source?.audio?.muted ?? false
            glyph: panel.source?.audio?.muted ? Theme.iMicOff : Theme.iMic
            level: panel.source?.audio?.muted ? 0 : Math.min(1, inputPeak.peak)
            onMoved: v => panel.setVolume(panel.source, v)
            onGlyphClicked: if (panel.source?.audio)
                panel.source.audio.muted = !panel.source.audio.muted
        }

        Percent {
            id: inPercent

            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -2
            node: panel.source
        }
    }

    Repeater {
        model: panel.sources

        DeviceRow {
            input: true
        }
    }

    Text {
        textFormat: Text.PlainText
        x: 8
        visible: panel.sources.length === 0
        height: 28
        verticalAlignment: Text.AlignVCenter
        text: qsTr("No input devices")
        color: Theme.textTertiary
        font.family: Theme.font
        font.pixelSize: Theme.fontSize(12)
    }

    // ---- Now Playing ----

    Separator {
        visible: panel.players.length > 0
    }

    SectionLabel {
        visible: panel.players.length > 0
        text: qsTr("Now Playing")
    }

    Repeater {
        model: panel.players

        PlayerCard {
            required property MprisPlayer modelData

            p: modelData
            shown: panel.shown
            width: panel.width
        }
    }

    // ---- Applications ----

    Separator {
        visible: panel.streams.length > 0
    }

    SectionLabel {
        visible: panel.streams.length > 0
        text: qsTr("Applications")
    }

    Repeater {
        model: panel.streams

        Item {
            id: stream

            required property PwNode modelData
            readonly property string appName: modelData.properties?.["application.name"] || modelData.name
            readonly property string iconName: modelData.properties?.["application.icon-name"]
                                               || modelData.properties?.["application.icon_name"]
                                               || DesktopEntries.heuristicLookup(appName)?.icon || ""

            width: panel.width
            height: 46

            Item {
                id: appIcon

                x: 6
                anchors.verticalCenter: parent.verticalCenter
                width: 26
                height: 26

                IconImage {
                    id: appImage

                    anchors.fill: parent
                    source: stream.iconName ? Quickshell.iconPath(stream.iconName, true) : ""
                    visible: source != ""
                }

                IconCircle {
                    visible: !appImage.visible
                    glyph: Theme.iApp
                }
            }

            Text {
                textFormat: Text.PlainText
                anchors.left: appIcon.right
                anchors.leftMargin: 10
                anchors.right: parent.right
                anchors.rightMargin: 8
                y: 4
                elide: Text.ElideRight
                text: {
                    const media = stream.modelData.properties?.["media.name"] ?? "";
                    return media && media !== stream.appName ? stream.appName + "  ·  " + media : stream.appName;
                }
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: Theme.fontSize(12)
            }

            PillSlider {
                anchors.left: appIcon.right
                anchors.leftMargin: 10
                anchors.right: streamPercent.left
                anchors.rightMargin: 6
                y: 22
                height: 16
                value: stream.modelData.audio?.volume ?? 0
                dimmed: stream.modelData.audio?.muted ?? false
                onMoved: v => panel.setVolume(stream.modelData, v)
            }

            Percent {
                id: streamPercent

                anchors.right: parent.right
                anchors.rightMargin: 8
                y: 22
                height: 16
                verticalAlignment: Text.AlignVCenter
                node: stream.modelData
            }
        }
    }
}
