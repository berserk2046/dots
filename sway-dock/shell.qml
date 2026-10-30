// Icon theme used for app icons; must match a folder name in ~/.local/share/icons or /usr/share/icons.
//@ pragma IconTheme MacTahoe-dark
// Fixed ID so saved state (pinned.json) stays put wherever this folder lives.
//@ pragma ShellId sway-dock
import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    id: root

    // Desktop entry IDs (file name without .desktop) or Wayland app_ids, in dock order.
    // Only used until you first pin/unpin from the dock; after that pinned.json is the source.
    readonly property var defaultPinnedApps: ["org.gnome.Nautilus", "firefox", "foot", "nvim"]

    function pin(id) {
        if (pins.pinned.indexOf(id) < 0)
            pins.pinned = [...pins.pinned, id];
    }

    function unpin(id) {
        pins.pinned = pins.pinned.filter(pinned => pinned !== id);
    }

    // Pinned apps persist in ~/.local/state/quickshell/by-shell/sway-dock/pinned.json.
    FileView {
        path: Quickshell.statePath("pinned.json")
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: pins

            property list<string> pinned: root.defaultPinnedApps
        }
    }

    Component.onCompleted: Quickshell.execDetached(["sh", "-c", 'mkdir -p "${1#file://}"', "sh", Quickshell.stateDir])

    MimeIndex {
        id: mimes
    }

    LauncherBadges {
        id: launcherBadges
    }

    HyprlandEvents {
        id: hyprlandEvents
    }

    // Position, size, magnification and the rest, from System Settings → Desktop & Dock.
    Settings {
        id: settings
    }

    Variants {
        model: Quickshell.screens

        Dock {
            required property var modelData

            screen: modelData
            position: settings.get("dock", "position", "bottom")
            iconSize: settings.get("dock", "iconSize", 40)
            maxIconSize: settings.get("dock", "magnification", true) ? Math.max(iconSize, settings.get("dock", "maxIconSize", 64))
                                                                     : iconSize
            autoHide: settings.get("dock", "autoHide", false)
            showIndicators: settings.get("dock", "showIndicators", true)
            terminal: settings.get("general", "terminal", "foot") === "foot" ? ["foot", "--app-id={appId}"]
                                                                             : [settings.get("general", "terminal", "foot"), "-e"]
            pinnedApps: pins.pinned
            mimeIndex: mimes
            badges: launcherBadges
            hyprland: hyprlandEvents
            onPinRequested: id => root.pin(id)
            onUnpinRequested: id => root.unpin(id)
            onPinnedOrderRequested: ids => pins.pinned = ids
        }
    }

    AppearanceSchedule {
        mode: settings.get("appearance", "mode", "dark")
    }

    Variants {
        model: Quickshell.screens

        HotCorners {
            required property var modelData

            screen: modelData
            actions: settings.data.hotCorners ?? {}
        }
    }
}
