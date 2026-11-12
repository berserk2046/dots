import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

// The Dock: one per screen (or per screen it's turned on for), hot corners and the automatic
// light/dark switch. Loaded by desktop-shell, together with the window switcher, the menu bar panels,
// the desktop and the notifications, in one process.
Scope {
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

    // Pinned apps persist in ~/.local/state/quickshell/by-shell/sway-dock/pinned.json (a fixed folder,
    // where they have always been, rather than Quickshell.statePath()).
    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state")
                                       + "/quickshell/by-shell/sway-dock"

    FileView {
        path: root.stateDir + "/pinned.json"
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: pins

            property list<string> pinned: root.defaultPinnedApps
        }
    }

    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", root.stateDir])

    MimeIndex {
        id: mimes
    }

    LauncherBadges {
        id: launcherBadges
    }

    HyprlandEvents {
        id: hyprlandEvents
    }

    // Apps, focus history and launch state, once for every display's Dock
    DockModel {
        id: dockModel

        pinnedApps: pins.pinned
    }

    // Position, size, magnification and the rest come from System Settings → Desktop & Dock (Settings,
    // shared with the other parts).
    //
    // Per display (System Settings → Desktop & Dock → Displays): {enabled, custom, iconSize,
    // magnification, maxIconSize, position, autoHide}. `enabled: false` leaves that display without a
    // Dock; with `custom` its own values replace the ones every display uses. Kept per monitor (make,
    // model and serial, see Displays), so they follow a monitor to another port.
    readonly property var displaySettings: Settings.get("dock", "monitors", {})
    function ownSettings(screen) {
        return Displays.pick(displaySettings, screen?.name);
    }

    function dockShown(screen) {
        return ownSettings(screen)?.enabled !== false;
    }

    function dockSetting(screen, key, fallback) {
        const own = ownSettings(screen);
        if (own?.custom === true && own[key] !== undefined && own[key] !== null)
            return own[key];
        return Settings.get("dock", key, fallback);
    }

    Variants {
        // Turning a display's Dock off or on adds or removes just that one. Not before the settings
        // are read, so a Dock that's turned off (or elsewhere, or another size) doesn't flash by.
        model: Settings.loaded ? Quickshell.screens.filter(s => root.dockShown(s)) : []

        Dock {
            required property var modelData

            screen: modelData
            position: root.dockSetting(modelData, "position", "bottom")
            iconSize: root.dockSetting(modelData, "iconSize", 40)
            maxIconSize: root.dockSetting(modelData, "magnification", true) ? Math.max(iconSize, root.dockSetting(modelData, "maxIconSize", 64))
                                                                          : iconSize
            autoHide: root.dockSetting(modelData, "autoHide", false)
            showIndicators: Settings.get("dock", "showIndicators", true)
            ownWindowsOnly: Settings.get("dock", "ownWindowsOnly", false)
            terminal: Settings.get("general", "terminal", "foot") === "foot" ? ["foot", "--app-id={appId}"]
                                                                             : [Settings.get("general", "terminal", "foot"), "-e"]
            shared: dockModel
            mimeIndex: mimes
            badges: launcherBadges
            hyprland: hyprlandEvents
            onPinRequested: id => root.pin(id)
            onUnpinRequested: id => root.unpin(id)
            onPinnedOrderRequested: ids => pins.pinned = ids
        }
    }

    AppearanceSchedule {
        mode: Settings.get("appearance", "mode", "dark")
    }

    Variants {
        model: Quickshell.screens

        HotCorners {
            required property var modelData

            screen: modelData
            actions: Settings.data.hotCorners ?? {}
        }
    }
}
