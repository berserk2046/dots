# dotfiles

A macOS-style Hyprland desktop for Arch Linux, built mostly with [Quickshell](https://quickshell.org).

| Folder | What it is |
| --- | --- |
| `hypr/` | Hyprland config (Lua, `hyprland.lua`) |
| `waybar/` | Menu bar config and style |
| `waybar-widgets/` | Control Center style dropdowns for the menu bar (Wi-Fi, sound, battery, date, power) |
| `sway-dock/` | Dock, hot corners, automatic light/dark appearance |
| `lockscreen/` | Lock screen, login screen (greetd), notification daemon and Notification Center |
| `system-settings/` | System Settings app that writes the settings for everything above |

Each folder has its own README with details.

## Install

```sh
git clone <this repo> ~/dotfiles
cd ~/dotfiles
./install.sh
```

`install.sh` installs the packages, moves any existing `~/.config/<folder>` to `<folder>.bak-<date>`, then
symlinks each folder into `~/.config`, so `git pull` updates your desktop. Use `--copy` to copy instead, and
`--no-packages` to skip the packages. It also writes default `hypridle.conf`, `hyprpaper.conf` and
`hyprsunset.conf`, and adds System Settings to the app launcher. Then log out and back in.

The login screen is optional: `sudo sh lockscreen/greetd/install.sh [wallpaper]`.

## Requirements

- **Hyprland 0.56 or newer.** The config is written in Lua, which older versions can't read.
- **Quickshell** 0.3 or newer
- **Wi-Fi through wpa_supplicant** (`wpa_cli`). With NetworkManager or iwd the Wi-Fi panels stay empty.
- Packages (official repos): `hyprland quickshell waybar hyprpaper hypridle hyprsunset foot fuzzel yazi
  grim playerctl brightnessctl pipewire wireplumber libpulse power-profiles-daemon upower mpd mpc
  wpa_supplicant bluez bluez-utils python python-gobject python-dbus glib2 libnotify xdg-utils
  ttf-firacode-nerd curl 7zip fontconfig`
- AUR: `pwvucontrol`
- SF Pro and SF Pro Rounded: `install.sh` downloads them from Apple into `~/.local/share/fonts/SF-Pro`
  (the AUR's `apple-fonts` fails whenever Apple updates the download)
- Themes: [MacTahoe GTK](https://github.com/vinceliuice/MacTahoe-gtk-theme) and
  [MacTahoe icons and cursors](https://github.com/vinceliuice/MacTahoe-icon-theme)
- Optional: the `hyprbars` plugin for title bars
  (`hyprpm add https://github.com/hyprwm/hyprland-plugins && hyprpm enable hyprbars`)

## Things you may want to change

- **Wallpaper:** put one at `~/Pictures/Wallpapers/wallpaper.jpg`, or pick one in System Settings → Wallpaper.
- **Keyboard layouts:** `us,latam` by default (`hypr/hyprland.lua` and `lockscreen/greetd/hyprland.lua`), or set
  them in System Settings → Keyboard.
- **Your picture** on the lock and login screens: `~/.face`.
- **Google Calendar** in the date panel: see `waybar-widgets/README.md`. Your calendar addresses go in
  `~/.config/waybar-widgets-calendars.conf`, which is outside this repo. Keep it private.

## Not in git

System Settings saves this machine's choices in `system-settings/settings.json` and writes
`hypr/hypridle.conf`, `hypr/hyprpaper.conf`, `hypr/hyprsunset.conf` and `hypr/system-settings.lua`.
These are in `.gitignore`.

## Keys

`Super` is the modifier. The common ones:

| Keys | Action |
| --- | --- |
| Super+Return | Terminal (foot) |
| Super+P | App launcher (fuzzel) |
| Super+I | Files (yazi) |
| Super+Q | Close window |
| Super+Ctrl+Q | Lock screen |
| Super+N | Notification Center |
| Super+U | Next keyboard layout |
| Super+Shift+R | Reload Hyprland |
| Super+Shift+E | Exit Hyprland |

`hypr/hyprland.lua` has the full list.
