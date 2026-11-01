import QtQuick

// Wi-Fi menu: switch, joined network with details, known and other networks, Ethernet.
Column {
    id: panel

    required property Network net
    property bool shown: false
    property bool showWifi: true
    property bool showEthernet: true

    // SSID (or "eth:<iface>", "other") whose row is expanded.
    property string expanded: ""

    width: parent?.width ?? 0
    spacing: 2

    onShownChanged: {
        if (!shown)
            expanded = "";
    }

    function toggleExpanded(key) {
        expanded = expanded === key ? "" : key;
    }

    function frequencyBand(freqs) {
        const list = Array.isArray(freqs) ? freqs : [freqs];
        const bands = [];
        if (list.some(f => f >= 2400 && f < 2500))
            bands.push("2.4");
        if (list.some(f => f >= 4900 && f < 5900))
            bands.push("5");
        if (list.some(f => f >= 5925))
            bands.push("6");
        return bands.length ? bands.join(" / ") + " GHz" : "";
    }

    component ErrorText: Text {
        width: parent?.width ?? 0
        wrapMode: Text.WordWrap
        color: Theme.danger
        font.family: Theme.font
        font.pixelSize: Theme.fontSize(12)
    }

    // A network in the known/other lists. Secured networks not yet saved expand to ask for
    // a password; saved ones join on click and have an info button with Forget.
    component NetworkRow: ListRow {
        id: netRow

        required property var modelData
        readonly property bool isKnown: panel.net.knownIdFor(modelData.ssid) >= 0
        readonly property bool isJoining: panel.net.joining?.ssid === modelData.ssid
        readonly property string error: panel.net.joinError?.ssid === modelData.ssid ? panel.net.joinError.message : ""
        readonly property bool open: panel.expanded === modelData.ssid

        title: modelData.ssid
        highlight: open
        icon: IconCircle {
            WifiGlyph {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: 1
                bars: netRow.modelData.bars
            }
        }
        trailing: [
            Spinner {
                anchors.verticalCenter: parent.verticalCenter
                running: netRow.isJoining
            },
            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                visible: netRow.modelData.secured
                text: Theme.iLock
                color: Theme.textSecondary
                size: 13
            },
            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                visible: netRow.isKnown
                text: Theme.iInfo
                color: infoMouse.containsMouse ? Theme.text : Theme.textTertiary
                size: 15

                MouseArea {
                    id: infoMouse

                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: panel.toggleExpanded(netRow.modelData.ssid)
                }
            }
        ]

        onClicked: {
            if (isKnown || !modelData.secured || modelData.enterprise) {
                if (modelData.enterprise && !isKnown)
                    panel.toggleExpanded(modelData.ssid);
                else
                    panel.net.join(modelData, "");
            } else {
                panel.toggleExpanded(modelData.ssid);
            }
        }
        onRightClicked: if (isKnown)
            panel.toggleExpanded(modelData.ssid)

        // Saved network: details + forget
        DetailLine {
            visible: netRow.open && netRow.isKnown
            label: qsTr("Signal")
            value: netRow.modelData.signal + " dBm"
        }
        DetailLine {
            visible: netRow.open && netRow.isKnown
            label: qsTr("Band")
            value: panel.frequencyBand(netRow.modelData.freqs)
        }
        Row {
            visible: netRow.open && netRow.isKnown
            spacing: 6

            TextButton {
                text: qsTr("Join")
                primary: true
                onClicked: panel.net.join(netRow.modelData, "")
            }
            TextButton {
                text: qsTr("Forget This Network")
                destructive: true
                onClicked: {
                    panel.net.forget(netRow.modelData.ssid);
                    panel.expanded = "";
                }
            }
        }

        // New secured network: password prompt
        Text {
            visible: netRow.open && !netRow.isKnown && netRow.modelData.enterprise
            width: parent.width
            wrapMode: Text.WordWrap
            text: qsTr("Enterprise (802.1X) networks need to be set up in wpa_supplicant.conf.")
            color: Theme.textSecondary
            font.family: Theme.font
            font.pixelSize: Theme.fontSize(12)
        }
        Field {
            id: password

            visible: netRow.open && !netRow.isKnown && !netRow.modelData.enterprise
            width: parent.width
            secret: true
            placeholder: qsTr("Password")
            onVisibleChanged: {
                if (visible) {
                    text = "";
                    input.forceActiveFocus();
                }
            }
            onAccepted: joinButton.clicked()
        }
        Row {
            visible: password.visible
            spacing: 6
            layoutDirection: Qt.RightToLeft
            width: parent.width

            TextButton {
                id: joinButton

                text: qsTr("Join")
                primary: true
                enabled: password.text.length >= 8 && !netRow.isJoining
                onClicked: {
                    if (enabled)
                        panel.net.join(netRow.modelData, password.text);
                }
            }
            TextButton {
                text: qsTr("Cancel")
                onClicked: panel.expanded = ""
            }
        }
        ErrorText {
            visible: netRow.error !== ""
            text: netRow.error
        }
    }

    // Wi-Fi and Ethernet halves; System Settings shows them on separate panes.
    Column {
        width: parent.width
        spacing: 2
        visible: panel.showWifi

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
                text: qsTr("Wi-Fi")
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: Theme.fontSize(14)
                font.weight: Font.Bold
            }

            Text {
                text: panel.net.wifi || qsTr("No wireless interface")
                color: Theme.textSecondary
                font.family: Theme.font
                font.pixelSize: Theme.fontSize(11)
            }
        }

        Toggle {
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            enabled: panel.net.wifi !== "" && !panel.net.wifiHardBlocked
            checked: panel.net.wifiEnabled
            onToggled: on => panel.net.setWifiEnabled(on)
        }
    }

    Text {
        x: 8
        width: parent.width - 16
        visible: panel.net.wifi !== "" && panel.net.wifiEnabled && !panel.net.wpaReachable
        wrapMode: Text.WordWrap
        text: qsTr("Can't reach wpa_supplicant on %1. Is it running, and are you in its ctrl_interface_group?").arg(panel.net.wifi)
        color: Theme.textSecondary
        font.family: Theme.font
        font.pixelSize: Theme.fontSize(12)
        bottomPadding: 6
    }

    Text {
        x: 8
        visible: panel.net.wifiHardBlocked
        text: qsTr("Wi-Fi is disabled by a hardware switch.")
        color: Theme.textSecondary
        font.family: Theme.font
        font.pixelSize: Theme.fontSize(12)
        bottomPadding: 6
    }

    // ---- Joined network ----

    Column {
        width: parent.width
        spacing: 2
        visible: panel.net.wifiEnabled && panel.net.connected

        ListRow {
            id: currentRow

            readonly property bool open: panel.expanded === "current"
            readonly property string security: (panel.net.status.key_mgmt ?? "").replace("NONE", qsTr("None"))
            readonly property int freq: parseInt(panel.net.status.freq ?? "0")

            title: panel.net.currentSsid
            subtitle: [qsTr("Connected"), panel.frequencyBand(freq)].filter(s => s).join("  ·  ")
            bold: true
            highlight: open
            icon: IconCircle {
                active: true

                WifiGlyph {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 1
                    bars: panel.net.currentBars
                }
            }
            trailing: [
                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: currentRow.security !== "" && currentRow.security !== qsTr("None")
                    text: Theme.iLock
                    color: Theme.textSecondary
                    size: 13
                },
                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    text: currentRow.open ? Theme.iChevronDown : Theme.iChevronRight
                    color: Theme.textTertiary
                    size: 15
                }
            ]
            onClicked: panel.toggleExpanded("current")

            DetailLine {
                visible: currentRow.open
                label: qsTr("Interface")
                value: panel.net.wifi
            }
            DetailLine {
                visible: currentRow.open
                label: qsTr("IP Address")
                value: panel.net.wifiAddress
            }
            DetailLine {
                visible: currentRow.open
                label: qsTr("IPv6")
                value: (panel.net.addresses6[panel.net.wifi] ?? [])[0] ?? ""
            }
            DetailLine {
                visible: currentRow.open
                label: qsTr("Router")
                value: panel.net.gateways[panel.net.wifi] ?? ""
            }
            DetailLine {
                visible: currentRow.open
                label: qsTr("DNS")
                value: panel.net.dns.filter(d => d.indexOf(":") < 0).join(", ")
            }
            DetailLine {
                visible: currentRow.open
                label: qsTr("Signal")
                value: panel.net.rssi ? panel.net.rssi + " dBm" : ""
            }
            DetailLine {
                visible: currentRow.open
                label: qsTr("Channel")
                value: currentRow.freq ? currentRow.freq + " MHz" : ""
            }
            DetailLine {
                visible: currentRow.open
                label: qsTr("Security")
                value: currentRow.security
            }
            DetailLine {
                visible: currentRow.open
                label: qsTr("BSSID")
                value: panel.net.status.bssid ?? ""
            }
            Row {
                visible: currentRow.open
                spacing: 6
                topPadding: 2

                TextButton {
                    text: qsTr("Disconnect")
                    onClicked: {
                        panel.net.disconnect();
                        panel.expanded = "";
                    }
                }
                TextButton {
                    text: qsTr("Forget")
                    destructive: true
                    onClicked: {
                        panel.net.forget(panel.net.currentSsid);
                        panel.expanded = "";
                    }
                }
            }
        }
    }

    // ---- Known networks in range ----

    Column {
        width: parent.width
        spacing: 2
        visible: panel.net.wifiEnabled && panel.net.knownInRange.length > 0

        SectionLabel {
            text: qsTr("Known Networks")
        }

        Repeater {
            model: panel.net.knownInRange

            NetworkRow {}
        }
    }

    // ---- Other networks ----

    Column {
        width: parent.width
        spacing: 2
        visible: panel.net.wifiEnabled && panel.net.wpaReachable

        SectionLabel {
            text: qsTr("Other Networks")

            Spinner {
                anchors.verticalCenter: parent.verticalCenter
                running: panel.net.scanning
            }

            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                visible: !panel.net.scanning
                text: Theme.iRefresh
                color: refreshMouse.containsMouse ? Theme.text : Theme.textSecondary
                size: 14

                MouseArea {
                    id: refreshMouse

                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: panel.net.scan()
                }
            }
        }

        Flickable {
            width: parent.width
            height: Math.min(contentHeight, Theme.rowHeight * 6.5)
            contentHeight: otherColumn.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height

            Column {
                id: otherColumn

                width: parent.width
                spacing: 2

                Repeater {
                    model: panel.net.otherNetworks

                    NetworkRow {}
                }

                Text {
                    x: 8
                    visible: panel.net.otherNetworks.length === 0
                    height: 28
                    verticalAlignment: Text.AlignVCenter
                    text: panel.net.scanning ? qsTr("Searching…") : qsTr("No other networks found")
                    color: Theme.textTertiary
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize(12)
                }
            }
        }

        // Hidden network
        ListRow {
            id: otherRow

            readonly property bool open: panel.expanded === "other"
            readonly property bool isJoining: panel.net.joining?.ssid === hiddenSsid.text && hiddenSsid.text !== ""

            title: qsTr("Other Network…")
            highlight: open
            icon: IconCircle {
                glyph: "…"
            }
            onClicked: panel.toggleExpanded("other")

            Field {
                id: hiddenSsid

                visible: otherRow.open
                width: parent.width
                placeholder: qsTr("Network name")
                onVisibleChanged: {
                    if (visible) {
                        text = "";
                        input.forceActiveFocus();
                    }
                }
                onAccepted: hiddenPassword.input.forceActiveFocus()
            }
            Field {
                id: hiddenPassword

                visible: otherRow.open
                width: parent.width
                secret: true
                placeholder: qsTr("Password (leave empty for open networks)")
                onVisibleChanged: if (visible)
                    text = ""
                onAccepted: hiddenJoin.clicked()
            }
            Row {
                visible: otherRow.open
                spacing: 6
                layoutDirection: Qt.RightToLeft
                width: parent.width

                TextButton {
                    id: hiddenJoin

                    text: qsTr("Join")
                    primary: true
                    enabled: hiddenSsid.text !== "" && (hiddenPassword.text === "" || hiddenPassword.text.length >= 8)
                             && !otherRow.isJoining
                    onClicked: {
                        if (!enabled)
                            return;
                        panel.net.join({
                            ssid: hiddenSsid.text,
                            secured: hiddenPassword.text !== "",
                            sae: false,
                            psk: true
                        }, hiddenPassword.text, true);
                    }
                }
                TextButton {
                    text: qsTr("Cancel")
                    onClicked: panel.expanded = ""
                }
                Spinner {
                    anchors.verticalCenter: parent.verticalCenter
                    running: otherRow.isJoining
                }
            }
            ErrorText {
                visible: otherRow.open && panel.net.joinError !== null && panel.net.joinError.ssid === hiddenSsid.text
                text: panel.net.joinError?.message ?? ""
            }
        }
    }

    }

    Column {
        width: parent.width
        spacing: 2
        visible: panel.showEthernet

    // ---- Ethernet ----

    Separator {
        visible: panel.showWifi
    }

    SectionLabel {
        text: qsTr("Ethernet")
    }

    ListRow {
        visible: panel.net.ethernet.length === 0
        clickable: false
        title: qsTr("No Ethernet adapter")
        icon: IconCircle {
            glyph: Theme.iLanOff
        }
    }

    Repeater {
        model: panel.net.ethernet

        ListRow {
            id: ethRow

            required property var modelData
            readonly property string key: "eth:" + modelData.name
            readonly property bool open: panel.expanded === key
            readonly property bool linked: modelData.up && modelData.carrier
            readonly property bool busy: panel.net.ethernetBusy === modelData.name
            property int mode: modelData.manual ? 1 : 0

            onOpenChanged: {
                if (open) {
                    mode = modelData.manual ? 1 : 0;
                    ipField.text = modelData.manual?.address ?? modelData.addr;
                    routerField.text = modelData.manual?.router ?? modelData.gateway;
                    dnsField.text = modelData.manual?.dns ?? "";
                }
            }

            title: modelData.name
            subtitle: {
                if (!modelData.up)
                    return qsTr("Turned off");
                if (!modelData.carrier)
                    return qsTr("Cable unplugged");
                const parts = [modelData.addr ? qsTr("Connected") : qsTr("No IP address")];
                if (modelData.speed > 0)
                    parts.push(modelData.speed >= 1000 ? modelData.speed / 1000 + " Gb/s" : modelData.speed + " Mb/s");
                if (modelData.addr)
                    parts.push(modelData.addr.split("/")[0]);
                return parts.join("  ·  ");
            }
            bold: linked
            highlight: open
            icon: IconCircle {
                active: ethRow.linked && ethRow.modelData.addr !== ""
                glyph: ethRow.linked ? Theme.iEthernet : Theme.iLanOff
            }
            trailing: [
                Spinner {
                    anchors.verticalCenter: parent.verticalCenter
                    running: ethRow.busy
                },
                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    text: ethRow.open ? Theme.iChevronDown : Theme.iChevronRight
                    color: Theme.textTertiary
                    size: 15
                }
            ]
            onClicked: panel.toggleExpanded(key)

            DetailLine {
                visible: ethRow.open
                label: qsTr("MAC Address")
                value: ethRow.modelData.mac
            }
            DetailLine {
                visible: ethRow.open
                label: qsTr("Router")
                value: ethRow.modelData.gateway
            }

            Text {
                visible: ethRow.open
                text: qsTr("Configure IPv4")
                color: Theme.textSecondary
                font.family: Theme.font
                font.pixelSize: Theme.fontSize(12)
            }
            Segmented {
                visible: ethRow.open
                options: [qsTr("Using DHCP"), qsTr("Manually")]
                current: ethRow.mode
                onPicked: index => ethRow.mode = index
            }
            Field {
                id: ipField

                visible: ethRow.open && ethRow.mode === 1
                width: parent.width
                placeholder: qsTr("IP address, e.g. 192.168.1.50/24")
            }
            Field {
                id: routerField

                visible: ethRow.open && ethRow.mode === 1
                width: parent.width
                placeholder: qsTr("Router")
            }
            Field {
                id: dnsField

                visible: ethRow.open && ethRow.mode === 1
                width: parent.width
                placeholder: qsTr("DNS servers, e.g. 1.1.1.1 8.8.8.8")
            }
            ErrorText {
                visible: ethRow.open && panel.net.ethernetError !== ""
                text: panel.net.ethernetError
            }
            Row {
                visible: ethRow.open
                spacing: 6

                TextButton {
                    text: qsTr("Apply")
                    primary: true
                    enabled: !ethRow.busy && (ethRow.mode === 0 ? ethRow.modelData.manual !== null : ipField.text !== "")
                    onClicked: {
                        if (ethRow.mode === 0)
                            panel.net.useDhcp(ethRow.modelData.name);
                        else
                            panel.net.useManual(ethRow.modelData.name, ipField.text, routerField.text, dnsField.text);
                    }
                }
                TextButton {
                    visible: ethRow.mode === 0 && ethRow.modelData.manual === null
                    enabled: !ethRow.busy && ethRow.linked
                    text: qsTr("Renew Lease")
                    onClicked: panel.net.renew(ethRow.modelData.name)
                }
                TextButton {
                    enabled: !ethRow.busy
                    text: ethRow.modelData.up ? qsTr("Turn Off") : qsTr("Turn On")
                    onClicked: panel.net.setLink(ethRow.modelData.name, !ethRow.modelData.up)
                }
            }
        }
    }
    }
}
