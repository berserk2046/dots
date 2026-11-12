//@ pragma ShellId lockscreen-greeter
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Greetd
import Quickshell.Wayland
// Registers the folder's singletons (Settings, Displays), which Config.qml uses
import qs.common

// Login screen for greetd, with the same look as the lock screen. greetd starts it inside a
// minimal Hyprland (greetd/hyprland.lua); after a successful login it starts Config.session and quits.
ShellRoot {
    id: root

    property bool awaitingPassword: false
    property string pendingPassword: ""
    property bool busy: false
    property string errorText: ""
    property int failures: 0
    property bool unlocking: false

    readonly property string primaryName: {
        const names = Quickshell.screens.map(s => s.name);
        const wanted = Config.mainScreen || Hyprland.focusedMonitor?.name || "";
        return names.includes(wanted) ? wanted : names[0] ?? "";
    }

    function startSession() {
        awaitingPassword = false;
        Greetd.createSession(Config.user);
    }

    function submit(password) {
        if (busy || unlocking)
            return;
        busy = true;
        pendingPassword = password;
        if (awaitingPassword) {
            awaitingPassword = false;
            Greetd.respond(password);
        }
    }

    function fail(message) {
        busy = false;
        pendingPassword = "";
        errorText = message;
        failures++;
        if (Greetd.state !== GreetdState.Inactive)
            Greetd.cancelSession();
        // A moment later: greetd refuses a new session while it's still closing the cancelled one
        restartTimer.restart();
    }

    Timer {
        id: restartTimer

        interval: 150
        onTriggered: root.startSession()
    }

    function power(action) {
        const commands = {
            "sleep": ["systemctl", "suspend"],
            "restart": ["systemctl", "reboot"],
            "shutdown": ["systemctl", "poweroff"]
        };
        Quickshell.execDetached(commands[action]);
    }

    // Not before the settings are read: the account to sign in (yours) is in them. Until then
    // Config.user is the login screen's own account ("greeter"), and a session started for that one
    // can't be signed in to.
    property bool started: false

    function begin() {
        if (started || !Settings.loaded)
            return;
        started = true;
        startSession();
    }

    Component.onCompleted: begin()

    Connections {
        target: Settings

        function onLoadedChanged() {
            root.begin();
        }
    }

    Connections {
        target: Greetd

        function onAuthMessage(message, error, responseRequired, echoResponse) {
            if (!responseRequired)
                return;
            // The password may have been typed before greetd asked for it.
            if (root.busy && root.pendingPassword !== "")
                Greetd.respond(root.pendingPassword);
            else
                root.awaitingPassword = true;
        }

        function onAuthFailure(message) {
            root.fail("");
        }

        function onError(error) {
            root.fail(error);
        }

        function onReadyToLaunch() {
            root.busy = false;
            root.pendingPassword = "";
            root.unlocking = true;
            launchTimer.restart();
        }
    }

    // Let the slide-up finish, then start the session and quit (greetd/hyprland.lua then exits Hyprland).
    Timer {
        id: launchTimer

        interval: 570
        onTriggered: Greetd.launch(Config.session, ["XDG_SESSION_TYPE=wayland"], true)
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: window

            required property var modelData
            readonly property bool primary: modelData.name === root.primaryName

            screen: modelData
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            color: "black"

            WlrLayershell.namespace: "lockscreen-greeter"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: primary ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            LockScreen {
                primary: window.primary
                wallpaper: Quickshell.shellDir + "/wallpaper.jpg"
                face: Quickshell.shellDir + "/face"
                busy: root.busy
                errorText: root.errorText
                failures: root.failures
                unlocking: root.unlocking
                onSubmitted: password => root.submit(password)
                onPowerAction: action => root.power(action)
            }
        }
    }
}
