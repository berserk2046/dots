pragma Singleton
import QtQuick
import Quickshell
import qs.common

// Switcher colors, light or dark following the GTK color scheme that System Settings → Appearance sets.
// The panel is the same frosted glass as the menu bar and the Dock (sway-dock/DockTheme.qml, waybar's
// colors-light.css / colors-dark.css); Hyprland blurs what's behind it.
Singleton {
    id: theme

    readonly property bool light: Appearance.light

    readonly property color panel: light ? "#9ef6f6f6" : "#e6000000"
    readonly property color border: light ? "#1f000000" : "#26ffffff"
    // The rounded square behind the selected window, as in macOS's app switcher
    readonly property color selection: light ? "#24000000" : "#33ffffff"
    readonly property color hover: light ? "#12000000" : "#1affffff"
    readonly property color text: light ? "#e6000000" : "#ffffff"
    readonly property color textDim: light ? "#80000000" : "#99ffffff"
    // Behind a preview while it loads, or for a window that can't be captured
    readonly property color well: light ? "#14000000" : "#17ffffff"
    readonly property color shadow: light ? "#40000000" : "#80000000"

    readonly property string font: "SF Pro Text"
}
