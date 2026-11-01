# sway-dock

A small macOS-style dock for Quickshell on Hyprland.

- Pinned apps plus running apps, with a dot under running ones (brighter when focused)
- Magnification on hover, app name tooltip
- Left click: launch, focus, or cycle through the app's windows
- Middle click: launch a new instance
- Right click: menu with New Window and Pin/Unpin
- Drop files on an icon to open them with that app; only apps whose `.desktop` `MimeType=`
  covers the file type highlight and accept the drop (`MimeIndex.qml`, `mime-index.sh`)
- One dock per monitor, on the bottom, left, right or top edge, reserving its space there; or auto-hidden,
  sliding in when the pointer rests on that edge
- Hot corners: resting the pointer in a screen corner runs an action (`HotCorners.qml`)
- Appearance "Auto": switches GTK between light (7:00–19:00) and dark (`AppearanceSchedule.qml`)
- Hides while the focused window is fullscreen on that monitor
- Right-click → Quit closes the app's windows; hold Alt for Force Quit (kills its processes; process IDs come from `hyprctl clients`)
- Launch bounce while an app starts; attention bounce while one of its windows is urgent
- Badge counts and progress bars from apps using the Unity LauncherEntry D-Bus API (`LauncherBadges.qml`)
- Trash: click to open, drop files to trash them, right-click to empty (`TrashItem.qml`)

Uses Quickshell built-ins plus `gio`, `busctl` and `hyprctl`. Urgent windows and Force Quit go through Hyprland IPC
(`HyprlandEvents.qml`).

## Run

```sh
qs -p /path/to/sway-dock
```

Autostart from your Hyprland config (`hyprland.lua`):

```lua
hl.on("hyprland.start", function()
    hl.exec_cmd("qs -p /path/to/sway-dock")
end)
```

## Configure

Most of it is in System Settings → Desktop & Dock (position, size, magnification, auto-hide, indicators,
hot corners, terminal), saved in `~/.config/system-settings/settings.json` and read by `Settings.qml`;
changes apply right away.

- Pinned apps: right-click to pin/unpin. Saved to `~/.local/state/quickshell/by-shell/sway-dock/pinned.json`;
  `defaultPinnedApps` in `shell.qml` is only used before that file exists.
- Terminal apps (e.g. nvim): the terminal picked in System Settings; foot runs as `foot --app-id={appId}`.
- Spacing, padding and the defaults for size and magnification: properties at the top of `Dock.qml`.
- Icon theme: System Settings → Appearance, which rewrites the `//@ pragma IconTheme` line in `shell.qml`
  (default `MacTahoe-dark`) and restarts the Dock.
- Colors: `DockTheme.qml`, light or dark following System Settings → Appearance (the color scheme).
- Font: `font.family` on the labels in `Dock.qml`, `DockItem.qml` and `TrashItem.qml` (default `SF Pro`).
