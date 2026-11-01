import QtQuick

// What a Bluetooth pairing request asks for: a code to compare, a PIN to type, a code to type on the
// device, or permission to connect. Shown in System Settings' sheet and inline in the Bluetooth panel.
Column {
    id: prompt

    required property BluetoothPairing pairing
    readonly property var request: pairing.request

    width: parent?.width ?? 0
    spacing: 10

    Text {
        width: parent.width
        wrapMode: Text.WordWrap
        text: {
            const r = prompt.request;
            if (!r)
                return "";
            switch (r.type) {
            case "confirm":
                return qsTr("Pair with “%1”?").arg(r.device);
            case "pin":
            case "passkey":
                return qsTr("Enter the PIN for “%1”").arg(r.device);
            case "authorize":
                return qsTr("Allow “%1” to connect?").arg(r.device);
            default:
                return qsTr("Type this code on “%1”").arg(r.device);
            }
        }
        color: Theme.text
        font.family: Theme.font
        font.pixelSize: Theme.fontSize(15)
        font.weight: Font.DemiBold
    }

    Text {
        width: parent.width
        wrapMode: Text.WordWrap
        visible: text !== ""
        text: {
            const r = prompt.request;
            if (r?.type === "confirm")
                return qsTr("Make sure this code matches the one on the device:");
            if (r?.type === "displayPasskey" || r?.type === "displayPin")
                return qsTr("Then press Return on it.");
            if (r?.type === "pin" || r?.type === "passkey")
                return qsTr("Often 0000 or 1234, or the code shown on the device.");
            return "";
        }
        color: Theme.textSecondary
        font.family: Theme.font
        font.pixelSize: Theme.fontSize(12)
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        visible: prompt.request?.passkey !== undefined
        text: (prompt.request?.passkey ?? "").replace(/(\d{3})(\d{3})/, "$1 $2")
        color: Theme.text
        font.family: Theme.font
        font.pixelSize: Theme.fontSize(34)
        font.weight: Font.DemiBold
        font.letterSpacing: 4
    }

    Field {
        id: pinField

        width: parent.width
        visible: prompt.request?.type === "pin" || prompt.request?.type === "passkey"
        placeholder: qsTr("PIN")
        onVisibleChanged: {
            text = "";
            if (visible)
                input.forceActiveFocus();
        }
        onAccepted: prompt.pairing.answer(true, text)
    }

    Row {
        anchors.right: parent.right
        spacing: 8

        TextButton {
            text: qsTr("Cancel")
            onClicked: prompt.pairing.answer(false)
        }

        TextButton {
            primary: true
            visible: prompt.request?.type !== "displayPasskey" && prompt.request?.type !== "displayPin"
            text: prompt.request?.type === "authorize" ? qsTr("Allow") : prompt.request?.type === "confirm" ? qsTr("Pair") : qsTr("Connect")
            enabled: !pinField.visible || pinField.text.trim() !== ""
            onClicked: prompt.pairing.answer(true, pinField.text.trim())
        }
    }
}
