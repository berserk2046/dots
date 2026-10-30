pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Settings for the lock screen (shell.qml) and the login screen (greeter.qml). They come from the
// System Settings app (~/.config/system-settings/settings.json, re-read when it changes); the values
// here are the defaults. The login screen reads the copy greetd/install.sh puts next to greeter.qml.
Singleton {
    id: config

    property var data: ({})

    function get(section, key, fallback) {
        const value = data?.[section]?.[key];
        return value === undefined || value === null ? fallback : value;
    }

    readonly property bool greeter: Quickshell.shellDir.startsWith("/etc/")

    FileView {
        path: config.greeter ? Quickshell.shellDir + "/settings.json"
                             : Quickshell.env("HOME") + "/.config/system-settings/settings.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                config.data = JSON.parse(text());
            } catch (error) {
                config.data = {};
            }
        }
        onLoadFailed: config.data = {}
    }

    // Shown above your picture on the lock and login screens. Empty hides it.
    readonly property string message: get("lockScreen", "message", "")

    // Seconds after locking during which any key or click unlocks without a password. 0 always asks.
    // `ipc call lock lockNow` (used before sleep) always asks.
    readonly property int graceSeconds: get("lockScreen", "graceSeconds", 15)

    // Monitor that gets the password field, e.g. "DP-1" (see `hyprctl monitors`).
    // Empty uses the monitor that was focused when locking. The others show only the wallpaper and clock.
    readonly property string mainScreen: get("displays", "main", "")

    // Account the login screen signs in.
    readonly property string user: Quickshell.env("USER")

    // Lock screen images: its own wallpaper if one is picked, otherwise the desktop's. The login screen
    // can't read your home folder, so it uses the copies greetd/install.sh puts next to greeter.qml instead.
    readonly property string wallpaper: get("lockScreen", "wallpaper", "") || get("wallpaper", "path", Quickshell.env("HOME") + "/Pictures/Wallpapers/wallpaper.jpg")
    readonly property string face: Quickshell.env("HOME") + "/.face"

    // Notification text: "always", "unlocked" (only the app name on the lock screen, like macOS's
    // "Show previews: When unlocked") or "never".
    readonly property string previews: get("notifications", "previews", "always")
    readonly property bool notificationPreviews: previews === "always"

    // Seconds a banner stays on screen (critical ones stay until closed).
    readonly property int bannerSeconds: get("notifications", "bannerSeconds", 5)

    // Notifications kept in the Notification Center (oldest are dropped first).
    readonly property int historyLimit: get("notifications", "historyLimit", 200)

    // Per app (by app name): {allow, banners, lockScreen}; apps not listed get everything.
    readonly property var appRules: get("notifications", "apps", {})

    // Scheduled Do Not Disturb: {enabled, from: "22:00", to: "07:00"}, and apps that still notify
    // during Do Not Disturb.
    readonly property var focusSchedule: get("focus", "schedule", {})
    readonly property var focusAllowedApps: get("focus", "allowedApps", [])

    // Alert sound for notifications: a sound from System Settings' sounds folder (by name) or a file
    // path; "" plays nothing. Volume is 0..1.
    readonly property string alertSound: get("sound", "alert", "Ping")
    readonly property real alertVolume: get("sound", "alertVolume", 0.6)
    readonly property string alertSoundPath: alertSound === "" ? "" : alertSound.startsWith("/") ? alertSound
                                             : Quickshell.env("HOME") + "/.config/system-settings/sounds/" + alertSound + ".wav"

    // Short names for keyboard layouts in the top right corner; others show their first word.
    readonly property var layoutNames: ({
            "English (US)": "US",
            "Spanish (Latin American)": "LA"
        })

    // Command the login screen starts after a successful login.
    readonly property var session: ["start-hyprland"]
}
