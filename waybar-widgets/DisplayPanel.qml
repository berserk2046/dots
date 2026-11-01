import QtQuick

// Display menu, like macOS's Control Center Display module: brightness, then Night Shift with what
// System Settings → Displays offers (on/off, schedule with From/To steppers as in macOS's Night Shift
// settings, color temperature), and a link to the full pane.
Column {
    id: panel

    required property Display disp
    property bool shown: false
    signal closeRequested

    readonly property var night: disp.night

    width: parent?.width ?? 0
    spacing: 2

    function nightStatus() {
        if (night.manual)
            return qsTr("On until turned off");
        if (night.schedule === "custom")
            return disp.inSchedule ? qsTr("On until %1").arg(disp.timeLabel(night.to)) : qsTr("Off until %1").arg(disp.timeLabel(night.from));
        return qsTr("Off");
    }

    // macOS's time field with stepper arrows; scrolling over it works too. Steps of 30 minutes.
    component TimeStepper: Rectangle {
        id: stepper

        property string time
        signal picked(string time)

        function step(delta) {
            picked(panel.disp.shiftTime(time, delta));
        }

        width: 108
        height: 26
        radius: 7
        color: Theme.field

        MouseArea {
            anchors.fill: parent
            onWheel: event => stepper.step(event.angleDelta.y > 0 ? 30 : -30)
        }

        Glyph {
            id: earlier

            anchors.left: parent.left
            width: 24
            height: parent.height
            text: Theme.iChevronLeft
            size: 16
            color: earlierMouse.containsMouse ? Theme.text : Theme.textSecondary

            MouseArea {
                id: earlierMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: stepper.step(-30)
            }
        }

        Text {
            anchors.centerIn: parent
            text: panel.disp.timeLabel(stepper.time)
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: Theme.fontSize(12)
            font.features: {
                "tnum": 1
            }
        }

        Glyph {
            anchors.right: parent.right
            width: 24
            height: parent.height
            text: Theme.iChevronRight
            size: 16
            color: laterMouse.containsMouse ? Theme.text : Theme.textSecondary

            MouseArea {
                id: laterMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: stepper.step(30)
            }
        }
    }

    // ---- Brightness ----

    Item {
        width: parent.width
        height: 34

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: qsTr("Display")
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: Theme.fontSize(14)
            font.weight: Font.Bold
        }
    }

    Item {
        width: parent.width
        height: 34
        visible: panel.disp.brightness >= 0

        PillSlider {
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.right: brightnessPercent.left
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            value: panel.disp.brightness
            glyph: Theme.iBrightness
            onMoved: v => panel.disp.setBrightness(v)
        }

        Text {
            id: brightnessPercent

            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 34
            horizontalAlignment: Text.AlignRight
            text: Math.round(panel.disp.brightness * 100) + "%"
            color: Theme.textSecondary
            font.family: Theme.font
            font.pixelSize: Theme.fontSize(11)
            font.features: {
                "tnum": 1
            }
        }
    }

    Text {
        x: 8
        height: 28
        visible: panel.disp.brightness < 0
        verticalAlignment: Text.AlignVCenter
        text: qsTr("No adjustable display found")
        color: Theme.textTertiary
        font.family: Theme.font
        font.pixelSize: Theme.fontSize(12)
    }

    Separator {}

    // ---- Night Shift ----

    ListRow {
        title: qsTr("Night Shift")
        subtitle: panel.nightStatus()
        icon: IconCircle {
            active: panel.disp.nightShiftOn
            glyph: Theme.iMoon
        }
        trailing: Toggle {
            anchors.verticalCenter: parent.verticalCenter
            checked: panel.night.manual === true
            onToggled: on => panel.disp.setNight("manual", on)
        }
        onClicked: panel.disp.setNight("manual", !panel.night.manual)
    }

    Item {
        width: 1
        height: 2
    }

    SectionLabel {
        text: qsTr("Schedule")
    }

    Segmented {
        x: 8
        width: parent.width - 16
        options: [qsTr("Off"), qsTr("Custom")]
        current: panel.night.schedule === "custom" ? 1 : 0
        onPicked: index => panel.disp.setNight("schedule", index === 1 ? "custom" : "off")
    }

    Row {
        x: 8
        width: parent.width - 16
        visible: panel.night.schedule === "custom"
        topPadding: 6
        bottomPadding: 2

        Repeater {
            model: [
                {
                    key: "from",
                    label: qsTr("From")
                },
                {
                    key: "to",
                    label: qsTr("To")
                }
            ]

            Item {
                required property var modelData

                width: parent.width / 2
                height: 26

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: parent.modelData.label
                    color: Theme.textSecondary
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize(12)
                }

                TimeStepper {
                    anchors.right: parent.right
                    anchors.rightMargin: parent.modelData.key === "from" ? 8 : 0
                    time: panel.night[parent.modelData.key]
                    onPicked: t => panel.disp.setNight(parent.modelData.key, t)
                }
            }
        }
    }

    Item {
        width: 1
        height: 4
    }

    SectionLabel {
        text: qsTr("Color Temperature")

        Text {
            text: panel.night.temperature + " K"
            color: Theme.textSecondary
            font.family: Theme.font
            font.pixelSize: Theme.fontSize(11)
            font.features: {
                "tnum": 1
            }
        }
    }

    // Left is less warm (higher kelvin), as on macOS: 6500 K to 2500 K in steps of 100.
    PillSlider {
        x: 8
        width: parent.width - 16
        value: (6500 - panel.night.temperature) / 4000
        onMoved: v => panel.disp.setNight("temperature", Math.round((6500 - v * 4000) / 100) * 100)
    }

    Item {
        x: 8
        width: parent.width - 16
        height: 18

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: qsTr("Less Warm")
            color: Theme.textTertiary
            font.family: Theme.font
            font.pixelSize: Theme.fontSize(10)
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: qsTr("More Warm")
            color: Theme.textTertiary
            font.family: Theme.font
            font.pixelSize: Theme.fontSize(10)
        }
    }

    Separator {}

    SettingsLink {
        text: qsTr("Display Settings…")
        pane: "displays"
        onOpened: panel.closeRequested()
    }
}
