import QtQuick

// Battery menu: level and time remaining, health (capacity, cycles), live details, energy mode
// and the apps using significant energy, like the macOS battery menu.
Column {
    id: panel

    required property System sys
    property bool shown: false

    readonly property var bat: sys.battery
    readonly property bool charging: bat?.status === "Charging"
    readonly property bool discharging: bat?.status === "Discharging"
    // Apps above this share of one CPU count as "significant", as on macOS.
    readonly property real significantCpu: 10

    width: parent?.width ?? 0
    spacing: 2

    function stateText(status) {
        switch (status) {
        case "Charging":
            return qsTr("Charging");
        case "Discharging":
            return qsTr("Discharging");
        case "Full":
            return qsTr("Fully Charged");
        case "Not charging":
            return qsTr("Not Charging");
        default:
            return qsTr("Unknown");
        }
    }

    function timeText() {
        if (!bat)
            return "";
        if (bat.status === "Full")
            return qsTr("Fully Charged");
        if (bat.status === "Not charging")
            return qsTr("Not Charging");
        if (bat.remaining < 0)
            return qsTr("Calculating…");
        return sys.duration(bat.remaining);
    }

    function timeCaption() {
        if (!bat || bat.remaining < 0)
            return bat?.status === "Not charging" ? qsTr("Plugged in, holding the charge level") : "";
        return charging ? qsTr("until fully charged") : qsTr("remaining at current usage");
    }

    // power-profiles-daemon names in macOS's Energy Mode words.
    function profileLabel(name) {
        const labels = {
            "power-saver": qsTr("Low Power"),
            "low-power": qsTr("Low Power"),
            "quiet": qsTr("Quiet"),
            "cool": qsTr("Cool"),
            "balanced": qsTr("Automatic"),
            "balanced-performance": qsTr("Balanced+"),
            "performance": qsTr("High Power")
        };
        return labels[name] ?? name.charAt(0).toUpperCase() + name.slice(1);
    }

    // ---- Header ----

    Item {
        width: parent.width
        height: 40

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                text: qsTr("Battery")
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 14
                font.weight: Font.Bold
            }

            Text {
                text: panel.bat ? (panel.bat.acOnline ? qsTr("Power Source: Power Adapter") : qsTr("Power Source: Battery")) : ""
                color: Theme.textSecondary
                font.family: Theme.font
                font.pixelSize: 11
            }
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: panel.bat ? panel.bat.level + "%" : ""
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 14
            font.weight: Font.DemiBold
        }
    }

    Text {
        x: 8
        visible: panel.sys.loaded && !panel.bat
        text: qsTr("No battery found")
        color: Theme.textSecondary
        font.family: Theme.font
        font.pixelSize: 12
        bottomPadding: 6
    }

    // ---- Level and time ----

    Rectangle {
        visible: panel.bat !== null
        width: parent.width
        height: 68
        radius: 10
        color: Theme.field

        BatteryGlyph {
            id: bigGlyph

            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            width: 58
            height: 28
            level: (panel.bat?.level ?? 0) / 100
            charging: panel.charging
            low: panel.discharging && (panel.bat?.level ?? 100) <= 20
        }

        Column {
            anchors.left: bigGlyph.right
            anchors.leftMargin: 16
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                width: parent.width
                elide: Text.ElideRight
                text: panel.timeText()
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 20
                font.weight: Font.DemiBold
            }

            Text {
                width: parent.width
                visible: text !== ""
                elide: Text.ElideRight
                text: panel.timeCaption()
                color: Theme.textSecondary
                font.family: Theme.font
                font.pixelSize: 12
            }
        }
    }

    // ---- Health ----

    Column {
        width: parent.width
        spacing: 2
        visible: panel.bat !== null

        Item {
            width: 1
            height: 4
        }

        SectionLabel {
            text: qsTr("Battery Health")
        }

        Column {
            x: 8
            width: parent.width - 16
            spacing: 4

            DetailLine {
                label: qsTr("Condition")
                value: !panel.bat || panel.bat.health < 0 ? "" : panel.bat.health >= 0.8 ? qsTr("Normal") : qsTr("Service Recommended")
            }
            DetailLine {
                label: qsTr("Maximum Capacity")
                value: panel.bat && panel.bat.health >= 0 ? Math.round(panel.bat.health * 100) + "%" : ""
            }
            DetailLine {
                label: qsTr("Cycle Count")
                value: panel.bat && panel.bat.cycles >= 0 ? String(panel.bat.cycles) : ""
            }
            DetailLine {
                label: qsTr("Full Charge")
                value: panel.bat && panel.bat.full > 0 ? qsTr("%1 Wh of %2 Wh design").arg(panel.bat.full.toFixed(1)).arg(panel.bat.design.toFixed(1)) : ""
            }
        }

        Item {
            width: 1
            height: 4
        }

        SectionLabel {
            text: qsTr("Details")
        }

        Column {
            x: 8
            width: parent.width - 16
            spacing: 4

            DetailLine {
                label: qsTr("State")
                value: panel.stateText(panel.bat?.status)
            }
            DetailLine {
                label: panel.charging ? qsTr("Charging Rate") : qsTr("Power Draw")
                value: panel.bat && panel.bat.watts > 0.05 ? panel.bat.watts.toFixed(1) + " W" : ""
            }
            DetailLine {
                label: qsTr("Charge")
                value: panel.bat && panel.bat.full > 0 ? qsTr("%1 of %2 Wh").arg(panel.bat.now.toFixed(1)).arg(panel.bat.full.toFixed(1)) : ""
            }
            DetailLine {
                label: qsTr("Voltage")
                value: panel.bat && panel.bat.volts > 0 ? panel.bat.volts.toFixed(2) + " V" : ""
            }
            DetailLine {
                label: qsTr("Battery")
                value: panel.bat ? [panel.bat.model, panel.bat.technology].filter(x => x).join("  ·  ") : ""
            }
        }
    }

    // ---- Energy mode ----

    Column {
        width: parent.width
        spacing: 4
        visible: panel.sys.profiles.length > 1

        Separator {}

        SectionLabel {
            text: qsTr("Energy Mode")
        }

        Segmented {
            x: 8
            width: parent.width - 16
            options: panel.sys.profiles.map(p => panel.profileLabel(p))
            current: panel.sys.profiles.indexOf(panel.sys.profile)
            onPicked: index => panel.sys.setProfile(panel.sys.profiles[index])
        }

        Text {
            x: 8
            width: parent.width - 16
            visible: panel.sys.profileError !== ""
            wrapMode: Text.WordWrap
            text: panel.sys.profileError
            color: Theme.danger
            font.family: Theme.font
            font.pixelSize: 12
        }
    }

    // ---- Battery conservation ----

    Column {
        width: parent.width
        spacing: 2
        visible: panel.sys.chargeLimitSupported

        Separator {
            visible: panel.sys.profiles.length <= 1
        }

        Item {
            width: parent.width
            height: 46

            Column {
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.right: conservationToggle.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    text: qsTr("Battery Conservation")
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 13
                }

                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: qsTr("Stops charging before full to extend battery life")
                    color: Theme.textSecondary
                    font.family: Theme.font
                    font.pixelSize: 11
                }
            }

            Toggle {
                id: conservationToggle

                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                checked: panel.sys.chargeLimitEnabled
                onToggled: on => panel.sys.setChargeLimit(on)
            }
        }

        Text {
            x: 8
            width: parent.width - 16
            visible: panel.sys.chargeError !== ""
            wrapMode: Text.WordWrap
            text: panel.sys.chargeError
            color: Theme.danger
            font.family: Theme.font
            font.pixelSize: 12
        }
    }

    // ---- Apps using significant energy ----

    Separator {}

    SectionLabel {
        text: qsTr("Using Significant Energy")
    }

    Repeater {
        model: panel.sys.processes.filter(p => p.cpu >= panel.significantCpu).slice(0, 5)

        AppRow {
            required property var modelData

            name: modelData.name
            iconName: modelData.icon
        }
    }

    Text {
        x: 8
        height: 26
        visible: panel.sys.loaded && !panel.sys.processes.some(p => p.cpu >= panel.significantCpu)
        verticalAlignment: Text.AlignVCenter
        text: qsTr("No Apps Using Significant Energy")
        color: Theme.textTertiary
        font.family: Theme.font
        font.pixelSize: 12
    }
}
