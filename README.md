# dotfiles

A macOS-style Hyprland desktop for Arch Linux, built mostly with [Quickshell](https://quickshell.org).

| Folder | What it is |
| --- | --- |
| `hypr/` | Hyprland config (Lua, `hyprland.lua`) |
| `waybar/` | Menu bar config and style |
| `waybar-widgets/` | Control Center style dropdowns for the menu bar (Wi-Fi, sound, battery, date, power) |
| `sway-dock/` | Dock, hot corners, automatic light/dark appearance |
| `app-switcher/` | Window switcher (Alt+Tab), with previews or macOS-style icons |
| `desktop/` | The desktop: wallpaper and the files of `~/Desktop` on every display, each monitor with its own arrangement |
| `notifications/` | Notification daemon, banners and Notification Center |
| `polkit-agent/` | The password dialog shown when something needs an administrator (polkit agent) |
| `shell-common/` | What the parts share: the settings, light or dark, which monitor is which |
| `desktop-shell/` | Runs all of the above in one Quickshell process |
| `lockscreen/` | Lock screen and login screen (greetd), in a process of its own |
| `system-settings/` | System Settings app that writes the settings for everything above |
| `system/` | The two helpers that run as root (network settings, installing the login screen) and their polkit policy |

Each folder has its own README with details.

## Install

```sh
git clone <this repo> ~/dotfiles
cd ~/dotfiles
./install.sh
```

`install.sh` installs the packages, moves any existing `~/.config/<folder>` to `<folder>.bak-<date>`, then
symlinks each folder into `~/.config`, so `git pull` updates your desktop. Use `--copy` to copy instead,
`--no-packages` to skip the packages and `--no-helpers` to skip the root-owned helpers. It also writes default
`hypridle.conf`, `hyprpaper.conf` and `hyprsunset.conf`, and adds System Settings to the app launcher. Then log
out and back in.

The login screen is optional: `sudo /usr/local/libexec/desktop-helpers/greetd-install [wallpaper]`, or System
Settings → Lock Screen → Login screen → Update.

## What runs as root

Nothing in your home folder does, and nothing needs `sudo` without a password. `install.sh` runs
`sudo sh system/install.sh` once, which puts two root-owned helpers in `/usr/local/libexec/desktop-helpers`
(`net-admin`: Ethernet settings; `greetd-install`: the login screen) and a polkit policy for them in
`/usr/share/polkit-1/actions`. When System Settings needs one of them, or changes the time zone, the computer's
name or your full name, polkit asks for an administrator's password in the desktop's own dialog
(`polkit-agent/`). Run `sudo sh system/install.sh` again after pulling changes to `system/`;
`sudo sh system/install.sh --remove` removes them.

## Requirements

- **Hyprland 0.56 or newer.** The config is written in Lua, which older versions can't read.
- **Quickshell** 0.3 or newer
- **Wi-Fi through wpa_supplicant** (`wpa_cli`). With NetworkManager or iwd the Wi-Fi panels stay empty.
- Packages (official repos): `hyprland quickshell waybar hyprpaper hypridle hyprsunset foot fuzzel yazi
  grim hyprshot playerctl brightnessctl pipewire wireplumber libpulse power-profiles-daemon upower mpd mpc
  wpa_supplicant bluez bluez-utils python python-gobject python-dbus glib2 libnotify xdg-utils polkit
  ttf-firacode-nerd curl 7zip fontconfig`
- AUR: `pwvucontrol`
- SF Pro Text, Display and Rounded: `install.sh` downloads them from Apple into `~/.local/share/fonts/SF-Pro`
  (the AUR's `apple-fonts` fails whenever Apple updates the download). The variable "SF Pro" fonts are left
  out: every program using one kept all 20 MB of it in memory
- Themes: [MacTahoe GTK](https://github.com/vinceliuice/MacTahoe-gtk-theme) and
  [MacTahoe icons and cursors](https://github.com/vinceliuice/MacTahoe-icon-theme)
- Optional: the `hyprbars` plugin for title bars
  (`hyprpm add https://github.com/hyprwm/hyprland-plugins && hyprpm enable hyprbars`)

## Things you may want to change

- **Wallpaper:** put one at `~/Pictures/Wallpapers/wallpaper.jpg`, or pick one in System Settings → Wallpaper.
- **Keyboard layouts:** `us,latam` by default (`hypr/hyprland.lua`), or set them in System Settings →
  Keyboard. The login screen takes them, and your displays' arrangement, when it's installed or updated.
- **Your picture** on the lock and login screens: `~/.face`.
- **Floating window sizes:** a floating app reopens at the size you last resized it to. The sizes live in
  `~/.local/state/hypr-float-sizes.tsv`; delete it to start over.
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
| Alt+Tab | Switch windows (hold Alt; Shift+Tab goes back, Q closes, Esc cancels) |
| Super+I | Files (yazi) |
| Super+Q | Close window |
| Super+Ctrl+Q | Lock screen (asks for the password right away) |
| Super+N | Notification Center |
| Super+U | Next keyboard layout |
| Print | Screenshot of the focused display to the clipboard |
| Super+Print | Screenshot of the focused display to a file (~/Pictures) |
| Super+Shift+S | Screenshot of a region to the clipboard |
| Super+Shift+R | Reload Hyprland |
| Super+Shift+E | Exit Hyprland |

`hypr/hyprland.lua` has the full list.
