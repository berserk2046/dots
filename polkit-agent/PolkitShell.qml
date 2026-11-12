import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Polkit
import Quickshell.Wayland
import qs.widgets

// The desktop's authentication dialog, macOS style: when something needs an administrator's password
// (a network change, the login screen, the time zone, any `pkexec`), polkit asks this agent, and the
// password is typed here. It goes to polkit and nowhere else. With this, nothing on the desktop needs
// `sudo` without a password.
// Loaded by desktop-shell. Only one polkit agent can serve a session: if another is running (e.g.
// hyprpolkitagent), this one stays idle.
Scope {
    id: root

    PolkitAgent {
        id: agent
    }

    readonly property var flow: agent.flow
    readonly property bool active: agent.isActive && flow !== null

    PanelWindow {
        id: window

        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0] ?? null
        visible: root.active
        color: "#59000000"
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "polkit-agent"
        WlrLayershell.layer: WlrLayer.Overlay
        // The password goes to this dialog and nothing else while it's up
        WlrLayershell.keyboardFocus: root.active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        onVisibleChanged: {
            input.text = "";
            if (visible)
                input.forceActiveFocus();
        }

        function submit() {
            if (!root.flow || !root.flow.isResponseRequired)
                return;
            const value = input.text;
            input.text = "";
            root.flow.submit(value);
        }

        function cancel() {
            input.text = "";
            root.flow?.cancelAuthenticationRequest();
        }

        // Clicks outside the card do nothing: the dialog is answered or cancelled
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }

        Rectangle {
            id: card

            anchors.centerIn: parent
            anchors.verticalCenterOffset: -parent.height * 0.08
            width: 300
            height: column.implicitHeight + 40
            radius: 16
            color: Theme.light ? "#f2f2f2" : "#262628"
            border.width: 1
            border.color: Theme.border

            Column {
                id: column

                x: 20
                y: 22
                width: parent.width - 40
                spacing: 10

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 56
                    height: 56
                    radius: 14
                    color: Theme.solidCircle

                    Text {
                        anchors.centerIn: parent
                        textFormat: Text.PlainText
                        text: Theme.iLock
                        color: Theme.text
                        font.family: Theme.iconFont
                        font.pixelSize: 30
                    }
                }

                // What is asked for, in polkit's words (from the action's own description)
                Text {
                    width: parent.width
                    textFormat: Text.PlainText
                    text: root.flow?.message ?? ""
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    maximumLineCount: 5
                    elide: Text.ElideRight
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }

                Text {
                    width: parent.width
                    textFormat: Text.PlainText
                    text: qsTr("Enter an administrator's password to allow this.")
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    color: Theme.textSecondary
                    font.family: Theme.font
                    font.pixelSize: 12
                }

                // The action, small, so it's clear what exactly is being allowed
                Text {
                    width: parent.width
                    visible: text !== ""
                    textFormat: Text.PlainText
                    text: root.flow?.actionId ?? ""
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideMiddle
                    color: Theme.textTertiary
                    font.family: Theme.font
                    font.pixelSize: 10
                }

                Rectangle {
                    width: parent.width
                    height: 30
                    radius: 7
                    color: Theme.field
                    border.width: input.activeFocus ? 2 : 1
                    border.color: input.activeFocus ? Theme.accent : Theme.border
                    opacity: root.flow?.isResponseRequired ? 1 : 0.5

                    TextInput {
                        id: input

                        anchors.fill: parent
                        leftPadding: 10
                        rightPadding: 10
                        verticalAlignment: TextInput.AlignVCenter
                        echoMode: root.flow?.responseVisible ? TextInput.Normal : TextInput.Password
                        passwordCharacter: "●"
                        passwordMaskDelay: 0
                        readOnly: !(root.flow?.isResponseRequired ?? false)
                        selectByMouse: false
                        clip: true
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: 13
                        onAccepted: window.submit()
                        Keys.onEscapePressed: window.cancel()
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        visible: input.text === ""
                        textFormat: Text.PlainText
                        // "Password:" as PAM asks for it, without the colon
                        text: (root.flow?.inputPrompt ?? "").replace(/:\s*$/, "") || qsTr("Password")
                        color: Theme.textTertiary
                        font.family: Theme.font
                        font.pixelSize: 13
                    }
                }

                // A wrong password, or what PAM has to say (e.g. a lockout after too many tries)
                Text {
                    width: parent.width
                    visible: text !== ""
                    textFormat: Text.PlainText
                    text: root.flow?.supplementaryMessage || (root.flow?.failed ? qsTr("That password didn't work. Try again.") : "")
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    color: root.flow?.supplementaryIsError || root.flow?.failed ? Theme.danger : Theme.textSecondary
                    font.family: Theme.font
                    font.pixelSize: 12
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    topPadding: 4
                    spacing: 10

                    DialogButton {
                        label: qsTr("Cancel")
                        onClicked: window.cancel()
                    }

                    DialogButton {
                        label: qsTr("Allow")
                        primary: true
                        enabled: input.text !== "" && (root.flow?.isResponseRequired ?? false)
                        onClicked: window.submit()
                    }
                }
            }
        }
    }

    component DialogButton: Rectangle {
        id: button

        property string label
        property bool primary: false
        signal clicked

        width: 124
        height: 30
        radius: 7
        opacity: enabled ? 1 : 0.5
        color: primary ? Theme.accent : mouse.containsMouse ? Theme.buttonHover : Theme.button
        border.width: primary ? 0 : 1
        border.color: Theme.buttonBorder

        Text {
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: button.label
            color: button.primary ? "#ffffff" : Theme.text
            font.family: Theme.font
            font.pixelSize: 13
        }

        MouseArea {
            id: mouse

            anchors.fill: parent
            hoverEnabled: true
            onClicked: button.clicked()
        }
    }
}
