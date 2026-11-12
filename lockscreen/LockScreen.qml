import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

// The macOS-style lock screen for one monitor, used by both the lock screen (shell.qml) and the
// login screen (greeter.qml). The main monitor gets everything; the others only the wallpaper and clock.
Item {
    id: root

    property bool primary: true
    property string wallpaper: Config.wallpaper
    property string face: Config.face
    // Desktop picture taken just before locking, revealed by the slide-up when unlocking.
    property string desktopImage: ""
    // Media, calendar and notifications: lock screen only (the login screen can't see them).
    property bool showPrivate: false
    // How many notifications arrived while locked, and from which apps (a few names; empty when
    // previews are off). Their text stays in the Notification Center, behind the password.
    property int notificationCount: 0
    property var notificationApps: []
    property var nextEvent: null
    property bool doNotDisturb: false
    // While true, any key or click unlocks without a password.
    property bool graceActive: false
    property bool busy: false
    property string errorText: ""
    // Hides errorText once you start typing again
    property bool errorDismissed: false
    // Set to play the slide-up; the owner unlocks once it's done (`unlockDuration`).
    property bool unlocking: false
    // Increment to shake the password field and clear it.
    property int failures: 0

    readonly property int unlockDuration: 550

    signal submitted(string password)
    signal graceUnlock
    signal powerAction(string action)

    anchors.fill: parent

    onFailuresChanged: {
        errorDismissed = false;
        input.text = "";
        shake.restart();
    }

    onUnlockingChanged: {
        if (unlocking)
            slideUp.start();
    }

    // During the grace period the field is hidden and the screen itself takes the keys.
    function focusInput() {
        if (!primary)
            return;
        if (graceActive)
            root.forceActiveFocus();
        else
            input.forceActiveFocus();
    }

    Component.onCompleted: focusInput()
    onPrimaryChanged: focusInput()
    onGraceActiveChanged: focusInput()

    Keys.onPressed: event => {
        if (root.graceActive) {
            root.graceUnlock();
            event.accepted = true;
        }
    }

    SystemClock {
        id: clock

        precision: SystemClock.Seconds
    }

    // Full name from the account, falling back to the user name.
    property string fullName: Config.user

    Process {
        running: true
        command: ["sh", "-c", 'getent passwd "$1" | cut -d: -f5 | cut -d, -f1', "sh", Config.user]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "")
                    root.fullName = text.trim();
            }
        }
    }

    // Caps Lock state from the keyboard LEDs (one per keyboard), read while the field can take input.
    // The LED files are found once; after that they're only read again, without starting a program.
    property var capsLeds: []
    property var capsStates: ({})
    readonly property bool capsLock: Object.values(capsStates).some(v => v > 0)

    Process {
        running: root.primary
        command: ["sh", "-c", "ls /sys/class/leds/*::capslock/brightness 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: root.capsLeds = text.split("\n").filter(p => p.startsWith("/sys/class/leds/"))
        }
    }

    Instantiator {
        model: root.capsLeds

        FileView {
            required property string modelData

            path: modelData
            printErrors: false
            onLoaded: {
                const next = Object.assign({}, root.capsStates);
                next[modelData] = Number(text().trim()) || 0;
                root.capsStates = next;
            }
        }

        onObjectAdded: (index, object) => capsTimer.views = [...capsTimer.views, object]
        onObjectRemoved: (index, object) => capsTimer.views = capsTimer.views.filter(v => v !== object)
    }

    Timer {
        id: capsTimer

        property var views: []

        interval: 300
        repeat: true
        running: root.primary && !root.unlocking && views.length > 0
        onTriggered: views.forEach(v => v.reload())
    }

    // The desktop as it was, uncovered by the slide-up. Only drawn while unlocking.
    Image {
        anchors.fill: parent
        visible: root.unlocking && root.desktopImage !== ""
        source: root.desktopImage ? "file://" + root.desktopImage : ""
        cache: false
        fillMode: Image.PreserveAspectCrop
    }

    Item {
        id: scene

        width: root.width
        height: root.height
        clip: true

        NumberAnimation {
            id: slideUp

            target: scene
            property: "y"
            to: -root.height
            duration: root.unlockDuration
            easing.type: Easing.InOutCubic
        }

        Rectangle {
            anchors.fill: parent
            color: "black"
        }

        // Blurred, slightly dimmed wallpaper. Drawn larger than the screen so the blur's
        // see-through edges stay off screen. A blurred picture needs little detail, so it's decoded
        // and blurred at 1/4 of this screen's size and scaled up: it looks the same as blurring at full
        // size but takes a fraction of the video memory. How blurry: blurMax below (in reduced pixels,
        // so 12 here blurs about 48 screen pixels; higher is blurrier).
        Item {
            readonly property real reduction: 4

            x: -80
            y: -80
            width: (root.width + 160) / reduction
            height: (root.height + 160) / reduction
            scale: reduction
            transformOrigin: Item.TopLeft

            Image {
                id: wallpaperImage

                anchors.fill: parent
                // Not before the screen has a size: a 0×0 sourceSize would decode the full picture.
                source: root.wallpaper && root.width > 0 ? "file://" + root.wallpaper : ""
                sourceSize: Qt.size(Math.ceil(width), Math.ceil(height))
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: false
            }

            MultiEffect {
                anchors.fill: wallpaperImage
                source: wallpaperImage
                blurEnabled: true
                blur: 1.0
                blurMax: 12
                brightness: -0.12
                saturation: 0.15
            }
        }

        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: 0.12
        }

        // During the grace period a click anywhere unlocks.
        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (root.graceActive)
                    root.graceUnlock();
                root.focusInput();
            }
        }

        // Date and clock
        Column {
            id: clockColumn

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 70
            spacing: -6

            Text {
                textFormat: Text.PlainText
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDate(clock.date, "dddd, MMMM d")
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 26
                font.weight: Font.DemiBold
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowOpacity: 0.25
                    shadowBlur: 0.6
                }
            }

            Text {
                textFormat: Text.PlainText
                anchors.horizontalCenter: parent.horizontalCenter
                // 12-hour without AM/PM, like macOS
                text: Qt.formatTime(clock.date, "h:mm")
                color: Theme.text
                font.family: "SF Pro Rounded"
                font.pixelSize: 140
                font.weight: Font.Bold
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowOpacity: 0.25
                    shadowBlur: 0.8
                }
            }
        }

        // Widgets under the clock: media, next event, notifications
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: clockColumn.bottom
            anchors.topMargin: 16
            visible: root.primary && root.showPrivate
            spacing: 10

            NowPlaying {}

            UpNext {
                event: root.nextEvent
            }

            // Notifications that arrived while locked: how many, and from which apps. What they say
            // is in the Notification Center once unlocked.
            Rectangle {
                visible: root.notificationCount > 0
                width: 380
                height: 58
                radius: 18
                color: Qt.rgba(1, 1, 1, 0.16)

                Rectangle {
                    id: bell

                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: 34
                    height: 34
                    radius: 8
                    color: Qt.rgba(1, 1, 1, 0.15)

                    Text {
                        textFormat: Text.PlainText
                        anchors.centerIn: parent
                        text: Theme.iBell
                        color: Theme.text
                        font.family: Theme.iconFont
                        font.pixelSize: 18
                    }
                }

                Column {
                    anchors.left: bell.right
                    anchors.leftMargin: 10
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        textFormat: Text.PlainText
                        width: parent.width
                        text: qsTr("%n notification(s)", "", root.notificationCount)
                        elide: Text.ElideRight
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                    }

                    Text {
                        textFormat: Text.PlainText
                        width: parent.width
                        visible: text !== ""
                        text: root.notificationApps.join(", ")
                        elide: Text.ElideRight
                        color: Theme.textSecondary
                        font.family: Theme.font
                        font.pixelSize: 12
                    }
                }
            }
        }

        StatusIcons {
            doNotDisturb: root.doNotDisturb
            anchors.top: parent.top
            anchors.topMargin: 14
            anchors.right: parent.right
            anchors.rightMargin: 22
            visible: root.primary
        }

        // Message, picture, name, password
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: powerRow.top
            anchors.bottomMargin: 48
            visible: root.primary
            spacing: 10

            Text {
                textFormat: Text.PlainText
                anchors.horizontalCenter: parent.horizontalCenter
                visible: Config.message !== ""
                bottomPadding: 14
                text: Config.message
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 15
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowOpacity: 0.3
                    shadowBlur: 0.5
                }
            }

            ClippingRectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 76
                height: 76
                radius: width / 2
                color: Qt.rgba(1, 1, 1, 0.25)

                Image {
                    id: faceImage

                    anchors.fill: parent
                    source: root.face ? "file://" + root.face : ""
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(152, 152)
                    cache: false
                }

                // No picture: initials, like macOS
                Text {
                    textFormat: Text.PlainText
                    anchors.centerIn: parent
                    visible: faceImage.status !== Image.Ready
                    text: root.fullName.split(/\s+/).filter(w => w).slice(0, 2).map(w => w[0].toUpperCase()).join("")
                    color: Theme.text
                    font.family: "SF Pro Rounded"
                    font.pixelSize: 30
                    font.weight: Font.DemiBold
                }
            }

            Text {
                textFormat: Text.PlainText
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.fullName
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 16
                font.weight: Font.DemiBold
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowOpacity: 0.3
                    shadowBlur: 0.5
                }
            }

            // In place of the field during the grace period
            Text {
                textFormat: Text.PlainText
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.graceActive
                height: 34
                verticalAlignment: Text.AlignVCenter
                text: qsTr("Press any key to unlock")
                color: Theme.textSecondary
                font.family: Theme.font
                font.pixelSize: 13
            }

            // Password pill; shakes on a wrong password
            Item {
                id: field

                property real shakeOffset: 0

                visible: !root.graceActive
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.horizontalCenterOffset: shakeOffset
                width: 210
                height: 34

                SequentialAnimation {
                    id: shake

                    NumberAnimation { target: field; property: "shakeOffset"; to: -14; duration: 50; easing.type: Easing.OutQuad }
                    NumberAnimation { target: field; property: "shakeOffset"; to: 14; duration: 80; easing.type: Easing.InOutQuad }
                    NumberAnimation { target: field; property: "shakeOffset"; to: -10; duration: 70; easing.type: Easing.InOutQuad }
                    NumberAnimation { target: field; property: "shakeOffset"; to: 10; duration: 70; easing.type: Easing.InOutQuad }
                    NumberAnimation { target: field; property: "shakeOffset"; to: -5; duration: 60; easing.type: Easing.InOutQuad }
                    NumberAnimation { target: field; property: "shakeOffset"; to: 0; duration: 50; easing.type: Easing.OutQuad }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: Qt.rgba(1, 1, 1, root.busy ? 0.12 : 0.22)

                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }
                }

                TextInput {
                    id: input

                    anchors.fill: parent
                    leftPadding: 16
                    rightPadding: 16 + trailing.width
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: TextInput.Password
                    passwordCharacter: "●"
                    passwordMaskDelay: 0
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 13
                    font.letterSpacing: 1
                    selectByMouse: false
                    readOnly: root.busy || root.unlocking
                    clip: true

                    Keys.onPressed: event => {
                        if (root.graceActive) {
                            root.graceUnlock();
                            event.accepted = true;
                        }
                    }
                    onAccepted: {
                        if (text !== "" && !root.busy)
                            root.submitted(text);
                    }
                    onTextChanged: {
                        if (text !== "")
                            root.errorDismissed = true;
                    }
                }

                Text {
                    textFormat: Text.PlainText
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    visible: input.text === ""
                    text: qsTr("Enter Password")
                    color: Theme.textSecondary
                    font.family: Theme.font
                    font.pixelSize: 13
                }

                // Caps Lock symbol and the submit arrow, inside the pill on the right
                Row {
                    id: trailing

                    anchors.right: parent.right
                    anchors.rightMargin: 5
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Text {
                        textFormat: Text.PlainText
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.capsLock
                        text: Theme.iCapsLock
                        color: Theme.text
                        font.family: Theme.iconFont
                        font.pixelSize: 17
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 24
                        height: 24
                        radius: 12
                        visible: input.text !== ""
                        color: Qt.rgba(1, 1, 1, root.busy ? 0.15 : 0.3)

                        Text {
                            textFormat: Text.PlainText
                            anchors.centerIn: parent
                            text: Theme.iArrowRight
                            color: Theme.text
                            font.family: Theme.iconFont
                            font.pixelSize: 16
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: input.accepted()
                        }
                    }
                }
            }

            // Errors, and a clear Caps Lock warning
            Text {
                textFormat: Text.PlainText
                anchors.horizontalCenter: parent.horizontalCenter
                height: 18
                readonly property bool showError: root.errorText !== "" && !root.errorDismissed

                text: showError ? root.errorText : root.capsLock ? Theme.iCapsLock + "  " + qsTr("Caps Lock is on") : ""
                color: showError ? Theme.text : "#ffd60a"
                font.family: showError ? Theme.font : Theme.font + ", " + Theme.iconFont
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }
        }

        // Sleep, Restart, Shut Down
        Row {
            id: powerRow

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 36
            visible: root.primary
            spacing: 36

            Repeater {
                model: [
                    { action: "sleep", label: qsTr("Sleep"), glyph: Theme.iSleep },
                    { action: "restart", label: qsTr("Restart"), glyph: Theme.iRestart },
                    { action: "shutdown", label: qsTr("Shut Down"), glyph: Theme.iPower }
                ]

                Column {
                    id: powerButton

                    required property var modelData

                    spacing: 6

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 40
                        height: 40
                        radius: 20
                        color: Qt.rgba(1, 1, 1, powerMouse.pressed ? 0.35 : powerMouse.containsMouse ? 0.28 : 0.18)

                        Text {
                            textFormat: Text.PlainText
                            anchors.centerIn: parent
                            text: powerButton.modelData.glyph
                            color: Theme.text
                            font.family: Theme.iconFont
                            font.pixelSize: 20
                        }

                        MouseArea {
                            id: powerMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.powerAction(powerButton.modelData.action)
                        }
                    }

                    Text {
                        textFormat: Text.PlainText
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: powerButton.modelData.label
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: 12
                    }
                }
            }
        }
    }
}
