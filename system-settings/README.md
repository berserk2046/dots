# system-settings

macOS-style System Settings for this Hyprland desktop, built with Quickshell. It shares the look of
waybar-widgets (it imports that folder through the `shared` symlink) and drives the Dock, the lock screen,
waybar and Hyprland.

- Sidebar with search (Ctrl+F), your picture and name at the top; back button and Esc for pages
- **Wi-Fi**, **Network** (Ethernet), **Sound** and **Battery**: the waybar panels, full size
- **Bluetooth**: on/off, your devices (connect, disconnect, forget, battery), nearby devices to pair.
  While the pane is open `bt-agent.py` (in the shared folder, via `BluetoothPairing.qml`) is the pairing agent, so codes to confirm, PINs to type and
  passkeys to enter on a keyboard show up as sheets
- **Sound Effects**: alert sound for notifications (six built-in sounds from `make-sounds.py`, plus
  anything in `~/.local/share/sounds`) and alert volume
- **Notifications**: Do Not Disturb, previews (Always / When Unlocked / Never), banner duration, history
  size, Clear All; per app: allow, sound, banners, lock screen, allow during Do Not Disturb
- **Focus**: Do Not Disturb by hand or on a daily schedule, and the apps that may still notify
- **General**: About (hardware, rename the computer), Storage, Date & Time (automatic time, time zone,
  the menu bar's calendars), Login Items (apps and commands started with Hyprland)
- **Appearance**: Light / Dark / Auto for GTK and libadwaita apps (Auto: light 7:00–19:00, switched by the
  Dock's shell), GTK theme, icon theme (also the Dock's and notifications'), cursor theme and size
- **Control Center**: which waybar modules show, and the clock (date, weekday, 24-hour, seconds), formatted as
  on macOS
- **Desktop & Dock**: Dock size, magnification, position (left, bottom, right, top), auto-hide, indicators;
  default browser, file manager, mail and terminal; floating windows, title bars, gaps, corners, borders;
  Hot Corners (lock, Notification Center, launcher, display sleep, System Settings)
- **Displays**: drag displays to arrange them, resolution, refresh rate, scale, rotation, mirroring, main
  display; changes revert after 15 seconds unless kept. Brightness, and Night Shift (hyprsunset) on a
  schedule or by hand with a color temperature
- **Wallpaper**: pictures from `~/Pictures/Wallpapers` (and folders you add), Fill / Fit / Tile, per display
- **Lock Screen**: lock, display off and sleep when inactive, lock before sleep (hypridle), password grace
  period, message, its own wallpaper, and updating the login screen
- **Users & Groups**: picture (`~/.face`) and full name

## Run

```sh
qs -p ~/.config/system-settings -n -d          # or the System Settings icon in the Dock
qs -p ~/.config/system-settings ipc call settings open displays ""   # open a pane (and page)
qs -p ~/.config/system-settings ipc call settings show               # bring the window up
```

`~/.local/share/applications/system-settings.desktop` starts it; closing the window quits it. The window's
class is `system-settings` (`//@ pragma AppId` in `shell.qml`), which matches that entry, so the Dock shows the
running app on its pinned icon.

## Where settings go

Everything is kept in `settings.json` here. The Dock and the lock screen read it directly and follow
changes; the rest is written out:

| What | File | Applied with |
|---|---|---|
| Hyprland (displays, keyboard, pointer, windows, cursor, terminal, login items) | `~/.config/hypr/system-settings.lua`, loaded by `hyprland.lua` | `hyprctl reload config-only`; displays live with `hyprctl eval` |
| Wallpaper | `~/.config/hypr/hyprpaper.conf` | `hyprctl hyprpaper wallpaper` |
| Idle, lock before sleep | `~/.config/hypr/hypridle.conf` | restarts hypridle |
| Night Shift | `~/.config/hypr/hyprsunset.conf` | restarts hyprsunset |
| Menu bar | `~/.config/waybar/config` (`waybar-config.py` edits only modules-right and the clock) | SIGUSR2 |
| Appearance | gsettings, `~/.config/gtk-{3,4}.0/settings.ini`, the theme's GTK 4 CSS linked into `~/.config/gtk-4.0`, waybar's `colors.css` (`appearance.sh`) | Hyprland reload (title bars), waybar SIGUSR2 |
| Icon theme of the shells | the `//@ pragma IconTheme` line of the Dock, lock screen and this app | restarts them |
| Default apps | `xdg-mime` (`default-apps.py`) | — |
| Calendars | `~/.config/waybar-widgets-calendars.conf` (private) | — |

Changes that need root (time zone, hostname, full name, login screen) use `sudo -n`.

## Files

- `shell.qml` window, sidebar and search, and `fontScale` (text size of the whole window, 1.15); `Ui.qml` navigation and menus; `Store.qml` settings and commands
- `*Pane.qml` one per sidebar entry; `SettingsGroup`, `SettingRow`, `Dropdown`, `SettingSlider`, `Sheet`,
  `MenuLayer`, `IconTile`, `Avatar`, `GroupTitle`, `Caption` are the building blocks
- Scripts: `about.sh`, `list-themes.sh`, `icon-preview.sh`, `appearance.sh`, `default-apps.py`,
  `waybar-config.py`, `make-sounds.py`
