import QtQuick

// System menu in the spirit of Activity Monitor and About This Mac: CPU load graph (system in red,
// user in blue), per-core bars, memory with pressure color, storage, and the busiest processes.
Column {
    id: panel

    required property System sys
    property bool shown: false

    readonly property color systemColor: "#ff453a"
    readonly property color userColor: "#0a84ff"
    // Activity Monitor's memory pressure colors.
    readonly property color pressureColor: sys.memRatio < 0.7 ? Theme.success : sys.memRatio < 0.85 ? "#ffd60a" : "#ff453a"

    width: parent?.width ?? 0
    spacing: 2

    function percent(value) {
        return Math.round(value * 100) + "%";
    }

    component Legend: Row {
        property color dot
        property string text

        spacing: 5

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 7
            height: 7
            radius: 3.5
            color: parent.dot
        }

        Text {
            text: parent.text
            color: Theme.textSecondary
            font.family: Theme.font
            font.pixelSize: Theme.fontSize(11)
            font.features: {
                "tnum": 1
            }
        }
    }

    component Value: Text {
        color: Theme.textSecondary
        font.family: Theme.font
        font.pixelSize: Theme.fontSize(12)
        font.features: {
            "tnum": 1
        }
    }

    // ---- Header ----

    Item {
        width: parent.width
        height: 40

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                text: qsTr("System")
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: Theme.fontSize(14)
                font.weight: Font.Bold
            }

            Text {
                width: parent.width
                elide: Text.ElideRight
                text: [panel.sys.cpuModel, panel.sys.uptime > 0 ? qsTr("up %1").arg(panel.sys.duration(panel.sys.uptime / 3600)) : ""]
                      .filter(x => x).join("  ·  ")
                color: Theme.textSecondary
                font.family: Theme.font
                font.pixelSize: Theme.fontSize(11)
            }
        }
    }

    // ---- CPU ----

    SectionLabel {
        text: qsTr("CPU")

        Value {
            text: panel.percent(panel.sys.cpuTotal)
            color: Theme.text
            font.weight: Font.DemiBold
        }
    }

    Rectangle {
        x: 8
        width: parent.width - 16
        height: 60
        radius: 8
        color: Theme.field
        clip: true

        Canvas {
            id: graph

            anchors.fill: parent
            anchors.margins: 1

            Connections {
                target: panel.sys

                function onHistoryChanged() {
                    graph.requestPaint();
                }
            }

            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const samples = panel.sys.history;
                const slots = panel.sys.historyLength - 1;
                const step = width / slots;
                // Grid lines at 25 / 50 / 75 %.
                ctx.strokeStyle = Theme.light ? "rgba(0,0,0,0.08)" : "rgba(255,255,255,0.06)";
                ctx.lineWidth = 1;
                for (let g = 1; g < 4; g++) {
                    const y = Math.round(height * g / 4) + 0.5;
                    ctx.beginPath();
                    ctx.moveTo(0, y);
                    ctx.lineTo(width, y);
                    ctx.stroke();
                }
                if (samples.length < 2)
                    return;
                const xAt = i => width - (samples.length - 1 - i) * step;
                // Stacked areas: system at the bottom, user on top of it.
                const layers = [{
                        top: s => s.system + s.user,
                        bottom: s => s.system,
                        color: panel.userColor
                    }, {
                        top: s => s.system,
                        bottom: s => 0,
                        color: panel.systemColor
                    }];
                for (const layer of layers) {
                    ctx.beginPath();
                    for (let i = 0; i < samples.length; i++) {
                        const y = height * (1 - Math.min(1, layer.top(samples[i])));
                        i === 0 ? ctx.moveTo(xAt(i), y) : ctx.lineTo(xAt(i), y);
                    }
                    for (let i = samples.length - 1; i >= 0; i--)
                        ctx.lineTo(xAt(i), height * (1 - Math.min(1, layer.bottom(samples[i]))));
                    ctx.closePath();
                    ctx.fillStyle = Qt.rgba(layer.color.r, layer.color.g, layer.color.b, 0.55);
                    ctx.fill();
                    // Bright edge along the top of each area.
                    ctx.beginPath();
                    for (let i = 0; i < samples.length; i++) {
                        const y = height * (1 - Math.min(1, layer.top(samples[i])));
                        i === 0 ? ctx.moveTo(xAt(i), y) : ctx.lineTo(xAt(i), y);
                    }
                    ctx.strokeStyle = layer.color;
                    ctx.lineWidth = 1.2;
                    ctx.stroke();
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: panel.sys.history.length < 2
            text: qsTr("Measuring…")
            color: Theme.textTertiary
            font.family: Theme.font
            font.pixelSize: Theme.fontSize(11)
        }
    }

    Item {
        x: 8
        width: parent.width - 16
        height: 22

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            Legend {
                dot: panel.systemColor
                text: qsTr("System %1").arg(panel.percent(panel.sys.cpuSystem))
            }
            Legend {
                dot: panel.userColor
                text: qsTr("User %1").arg(panel.percent(panel.sys.cpuUser))
            }
            Legend {
                dot: Theme.track
                text: qsTr("Idle %1").arg(panel.percent(Math.max(0, 1 - panel.sys.cpuTotal)))
            }
        }

        Value {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: panel.sys.temperature > 0
            text: Math.round(panel.sys.temperature) + " °C"
            font.pixelSize: Theme.fontSize(11)
        }
    }

    // One bar per core.
    Row {
        id: cores

        x: 8
        width: parent.width - 16
        height: 20
        spacing: 3
        visible: panel.sys.coreUsage.length > 0

        Repeater {
            model: panel.sys.coreUsage

            Rectangle {
                required property real modelData

                width: (cores.width - cores.spacing * (panel.sys.coreUsage.length - 1)) / panel.sys.coreUsage.length
                height: cores.height
                radius: 2
                color: Theme.track

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: Math.max(2, parent.height * Math.min(1, parent.modelData))
                    radius: 2
                    color: panel.userColor

                    Behavior on height {
                        NumberAnimation {
                            duration: 250
                        }
                    }
                }
            }
        }
    }

    Column {
        x: 8
        width: parent.width - 16
        topPadding: 6
        spacing: 4

        DetailLine {
            label: qsTr("Load Average")
            value: panel.sys.load.map(l => l.toFixed(2)).join("   ")
        }
    }

    // ---- Memory ----

    Separator {}

    SectionLabel {
        text: qsTr("Memory")

        Value {
            text: panel.sys.memTotal > 0 ? qsTr("%1 of %2").arg(panel.sys.memory(panel.sys.memUsed)).arg(panel.sys.memory(panel.sys.memTotal)) : ""
        }
    }

    Column {
        x: 8
        width: parent.width - 16
        spacing: 6

        Meter {
            value: panel.sys.memRatio
            secondary: panel.sys.memTotal > 0 ? panel.sys.memCached / panel.sys.memTotal : 0
            barColor: panel.pressureColor
        }

        Row {
            spacing: 12

            Legend {
                dot: panel.pressureColor
                text: qsTr("Used %1").arg(panel.sys.memory(panel.sys.memUsed))
            }
            Legend {
                dot: Theme.textTertiary
                text: qsTr("Cached %1").arg(panel.sys.memory(panel.sys.memCached))
            }
        }

        DetailLine {
            label: qsTr("Memory Pressure")
            value: panel.sys.memRatio < 0.7 ? qsTr("Normal") : panel.sys.memRatio < 0.85 ? qsTr("Elevated") : qsTr("High")
        }
        DetailLine {
            label: qsTr("Swap Used")
            value: panel.sys.swapTotal > 0 ? qsTr("%1 of %2").arg(panel.sys.memory(panel.sys.swapUsed)).arg(panel.sys.memory(panel.sys.swapTotal)) : ""
        }
    }

    // ---- Storage ----

    Separator {}

    SectionLabel {
        text: qsTr("Storage")
    }

    Repeater {
        model: panel.sys.disks

        Column {
            id: disk

            required property var modelData
            readonly property real ratio: modelData.size > 0 ? modelData.used / modelData.size : 0

            x: 8
            width: panel.width - 16
            spacing: 5
            bottomPadding: 6

            Item {
                width: parent.width
                height: 18

                Text {
                    anchors.left: parent.left
                    anchors.right: mountLabel.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: disk.modelData.model || disk.modelData.device.replace("/dev/", "")
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize(13)
                    font.weight: Font.DemiBold
                }

                Text {
                    id: mountLabel

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: disk.modelData.mount + "  ·  " + disk.modelData.fstype
                    color: Theme.textTertiary
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize(11)
                }
            }

            Meter {
                implicitHeight: 10
                value: disk.ratio
                barColor: disk.ratio < 0.9 ? Theme.accent : "#ff453a"
            }

            Item {
                width: parent.width
                height: 16

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("%1 available of %2").arg(panel.sys.bytes(disk.modelData.avail)).arg(panel.sys.bytes(disk.modelData.size))
                    color: Theme.textSecondary
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize(12)
                }

                Value {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("%1 used").arg(panel.percent(disk.ratio))
                    font.pixelSize: Theme.fontSize(11)
                }
            }
        }
    }

    // ---- Processes ----

    Separator {}

    SectionLabel {
        text: qsTr("Top Processes")
    }

    Repeater {
        model: panel.sys.processes.slice(0, 5)

        AppRow {
            required property var modelData

            name: modelData.name
            iconName: modelData.icon
            value: modelData.cpu.toFixed(0) + "%"
            detail: panel.sys.memory(modelData.mem)
        }
    }
}
