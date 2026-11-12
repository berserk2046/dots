pragma Singleton
import QtQuick
import Quickshell
import qs.common

// Settings for the lock screen (shell.qml) and the login screen (greeter.qml). They come from the
// System Settings app (Settings: ~/.config/system-settings/settings.json, re-read when it changes); the
// values here are the defaults. The login screen reads the few values greetd-install.sh copies next to
// greeter.qml.
Singleton {
    id: config

    function get(section, key, fallback) {
        return Settings.get(section, key, fallback);
    }

    readonly property bool greeter: Settings.greeter

    // Shown above your picture on the lock and login screens. Empty hides it.
    readonly property string message: get("lockScreen", "message", "")

    // Seconds after locking during which any key or click unlocks without a password. 0 always asks.
    // Only the idle lock (`ipc call lock lock`) has it; `lockNow` and `lockForSleep` always ask.
    readonly property int graceSeconds: get("lockScreen", "graceSeconds", 15)

    // Monitor that gets the password field (System Settings → Displays → main display), as its port
    // name ("DP-1"); empty when none is picked or it isn't connected: then the monitor that was focused
    // when locking. The others show only the wallpaper and clock.
    readonly property string mainScreen: Displays.mainName(get("displays", "main", ""))

    // Account the login screen signs in: yours, which greetd-install.sh writes next to the settings
    // (the login screen itself runs as the "greeter" user).
    readonly property string user: greeter && get("login", "user", "") ? get("login", "user", "") : Quickshell.env("USER")

    // Lock screen images: its own wallpaper if one is picked, otherwise the desktop's. The login screen
    // can't read your home folder, so it uses the copies greetd-install.sh puts next to greeter.qml instead.
    readonly property string wallpaper: get("lockScreen", "wallpaper", "") || get("wallpaper", "path", Quickshell.env("HOME") + "/Pictures/Wallpapers/wallpaper.jpg")
    readonly property string face: Quickshell.env("HOME") + "/.face"

    // The lock screen picture for one display: the lock screen's own if one is picked, otherwise the
    // display's desktop picture (System Settings → Wallpaper can give each display its own).
    function wallpaperFor(screenName) {
        if (get("lockScreen", "wallpaper", ""))
            return wallpaper;
        return Displays.pick(get("wallpaper", "monitors", {}), screenName) || wallpaper;
    }

    // Short names for keyboard layouts in the top right corner; others show their first word.
    readonly property var layoutNames: ({
            "English (US)": "US",
            "Spanish (Latin American)": "LA"
        })

    // Command the login screen starts after a successful login.
    readonly property var session: ["start-hyprland"]
}
