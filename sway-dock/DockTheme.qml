pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Dock colors, light or dark following the GTK color scheme that System Settings → Appearance sets
// (as on macOS, the Dock turns light frosted glass in Light mode; Hyprland blurs behind it).
Singleton {
    id: theme

    property string scheme: "" // org.gnome.desktop.interface color-scheme
    readonly property bool light: scheme === "prefer-light"

    // The same glass as the menu bar (bar_bg and border in waybar's colors-light.css / colors-dark.css)
    readonly property color bar: light ? "#9ef6f6f6" : "#e6000000"
    readonly property color border: light ? "#1f000000" : "#26ffffff"
    // Menus, previews and name labels, like the menu bar's tooltips
    readonly property color menu: light ? "#f5f6f6f6" : "#f5000000"
    readonly property color text: light ? "#e6000000" : "#ffffff"
    readonly property color textDim: light ? "#80000000" : "#99ffffff"
    readonly property color hover: light ? "#1a000000" : "#29ffffff"
    readonly property color danger: light ? "#ff3b30" : "#ff6961"
    // Running dots: the focused app's is stronger
    readonly property color indicator: light ? "#cc000000" : "#ffffff"
    readonly property color indicatorDim: light ? "#59000000" : "#88ffffff"
    readonly property color dropHighlight: light ? "#26000000" : "#40ffffff"

    Process {
        running: true
        command: ["sh", "-c", "gsettings get org.gnome.desktop.interface color-scheme; gsettings monitor org.gnome.desktop.interface color-scheme"]
        stdout: SplitParser {
            // "'prefer-dark'" from get, "color-scheme: 'prefer-dark'" from monitor
            onRead: line => theme.scheme = line.replace(/^color-scheme:\s*/, "").replace(/'/g, "").trim()
        }
    }
}
