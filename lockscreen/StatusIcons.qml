import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.UPower

// Top right corner, like the macOS menu bar extras on the lock screen:
// Do Not Disturb moon, keyboard layout (click to switch), Wi-Fi network and signal, battery level and charging state.
Row {
    id: icons

    spacing: 16

    property bool doNotDisturb: false

    // Moon while Do Not Disturb is on
    Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: icons.doNotDisturb
        text: Theme.iMoon
        color: Theme.text
        font.family: Theme.iconFont
        font.pixelSize: 16
    }

    // Keyboard layout, from `hyprctl devices` and Hyprland's activelayout events.
    property string layout: ""

    function shortLayout(name) {
        return Config.layoutNames[name] ?? name.split(" ")[0];
    }

    Process {
        running: true
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const keyboards = JSON.parse(text).keyboards ?? [];
                    const main = keyboards.find(k => k.main) ?? keyboards[0];
                    if (main)
                        icons.layout = icons.shortLayout(main.active_keymap);
                } catch (error) {}
            }
        }
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name !== "activelayout")
                return;
            const name = event.data.slice(event.data.indexOf(",") + 1);
            icons.layout = icons.shortLayout(name);
        }
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: icons.layout !== ""
        text: icons.layout
        color: Theme.text
        font.family: Theme.font
        font.pixelSize: 13
        font.weight: Font.DemiBold

        MouseArea {
            anchors.fill: parent
            anchors.margins: -6
            cursorShape: Qt.PointingHandCursor
            onClicked: Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", "next"])
        }
    }

    // Wi-Fi, polled every 10 seconds
    property int wifiBars: -1 // -1: no wireless interface
    property string wifiName: ""

    Process {
        id: wifiProc

        running: true
        command: ["sh", Quickshell.shellDir + "/wifi-status.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                const line = text.trim();
                if (line === "") {
                    icons.wifiBars = -1;
                    return;
                }
                const [bars, name] = line.split("\t");
                icons.wifiBars = Number(bars);
                icons.wifiName = name ?? "";
            }
        }
    }

    Timer {
        interval: 10000
        repeat: true
        running: true
        onTriggered: wifiProc.running = true
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        visible: icons.wifiBars >= 0
        spacing: 6

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: icons.wifiBars > 0 && icons.wifiName !== ""
            text: icons.wifiName
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 13
        }

        WifiGlyph {
            anchors.verticalCenter: parent.verticalCenter
            visible: icons.wifiBars > 0
            bars: icons.wifiBars
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: icons.wifiBars === 0
            text: Theme.iWifiOff
            color: Theme.textSecondary
            font.family: Theme.iconFont
            font.pixelSize: 16
        }
    }

    // Battery, from UPower; hidden on machines without one.
    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery !== null && battery.isLaptopBattery && battery.isPresent
    // UPower reports 0-100; Quickshell may already scale it to 0-1.
    readonly property real level: hasBattery ? (battery.percentage > 1 ? battery.percentage / 100 : battery.percentage) : 0
    readonly property bool charging: hasBattery && (battery.state === UPowerDeviceState.Charging || battery.state === UPowerDeviceState.FullyCharged || battery.state === UPowerDeviceState.PendingCharge)

    Row {
        anchors.verticalCenter: parent.verticalCenter
        visible: icons.hasBattery
        spacing: 6

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(icons.level * 100) + "%"
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 13
        }

        BatteryGlyph {
            anchors.verticalCenter: parent.verticalCenter
            level: icons.level
            charging: icons.charging
            low: icons.level <= 0.2
        }
    }
}
