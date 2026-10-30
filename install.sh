#!/bin/sh
# Installs these dotfiles on Arch + Hyprland.
# Usage: ./install.sh [--copy] [--no-packages]
#   --copy         copy the folders into ~/.config instead of symlinking them to this repo
#   --no-packages  skip installing packages
# Existing folders in ~/.config are moved to <name>.bak-<date> first.
set -eu

repo=$(cd "$(dirname "$0")" && pwd)
config=${XDG_CONFIG_HOME:-$HOME/.config}
dirs="hypr lockscreen sway-dock waybar waybar-widgets system-settings"
stamp=$(date +%Y%m%d-%H%M%S)
copy=false
packages=true

for arg in "$@"; do
    case "$arg" in
        --copy) copy=true ;;
        --no-packages) packages=false ;;
        *) echo "Unknown option: $arg" >&2; exit 1 ;;
    esac
done

# Official repos
pacman_pkgs="hyprland quickshell waybar hyprpaper hypridle hyprsunset
    foot fuzzel yazi grim playerctl brightnessctl
    pipewire wireplumber libpulse power-profiles-daemon upower mpd mpc
    wpa_supplicant bluez bluez-utils
    python python-gobject python-dbus glib2 libnotify xdg-utils
    ttf-firacode-nerd"
# AUR
aur_pkgs="pwvucontrol apple-fonts"

if $packages; then
    echo "==> Installing packages"
    # shellcheck disable=SC2086
    sudo pacman -S --needed $pacman_pkgs
    helper=$(command -v paru || command -v yay || true)
    if [ -n "$helper" ]; then
        # shellcheck disable=SC2086
        "$helper" -S --needed $aur_pkgs
    else
        echo "No AUR helper found; install these yourself: $aur_pkgs"
    fi
fi

# The config is written in Lua, which older Hyprland versions can't read.
if have=$(pacman -Q hyprland 2>/dev/null | cut -d' ' -f2) && [ "$(vercmp "$have" 0.56)" -lt 0 ]; then
    echo "Warning: Hyprland $have is installed; this config was written for 0.56 or newer." >&2
fi

echo "==> Linking folders into $config"
mkdir -p "$config"
for d in $dirs; do
    target=$config/$d
    if [ -L "$target" ] && [ "$(readlink -f "$target")" = "$repo/$d" ]; then
        echo "    $d already linked"
        continue
    fi
    backup=
    if [ -e "$target" ] || [ -L "$target" ]; then
        backup=$target.bak-$stamp
        mv "$target" "$backup"
        echo "    $d: moved the old one to $backup"
    fi
    if $copy; then
        cp -a "$repo/$d" "$target"
    else
        ln -s "$repo/$d" "$target"
    fi
    echo "    $d -> $target"
    # Keep this machine's settings (they're not in git) from the old folder
    if [ -n "$backup" ]; then
        for f in system-settings/settings.json hypr/hypridle.conf hypr/hyprpaper.conf hypr/hyprsunset.conf hypr/system-settings.lua; do
            case "$f" in "$d"/*) ;; *) continue ;; esac
            name=${f#"$d"/}
            if [ -f "$backup/$name" ] && [ ! -f "$target/$name" ]; then
                cp "$backup/$name" "$target/$name"
                echo "    kept your $f"
            fi
        done
    fi
done

# App launcher entry for System Settings
mkdir -p "$HOME/.local/share/applications"
cp "$repo/system-settings/system-settings.desktop" "$HOME/.local/share/applications/"

# Files System Settings writes; these defaults are used until you change something there.
wallpapers=$HOME/Pictures/Wallpapers
mkdir -p "$wallpapers"
[ -f "$config/hypr/hypridle.conf" ] || cat > "$config/hypr/hypridle.conf" <<EOF
# Written by System Settings → Lock Screen; changes here are overwritten.
general {
    lock_cmd = qs -p $config/lockscreen ipc call lock lock
    before_sleep_cmd = qs -p $config/lockscreen ipc call lock lockNow
    after_sleep_cmd = hyprctl dispatch 'hl.dsp.dpms({ action = "on" })'
}
EOF
[ -f "$config/hypr/hyprpaper.conf" ] || cat > "$config/hypr/hyprpaper.conf" <<EOF
# Written by System Settings → Wallpaper; changes here are overwritten.
splash = false

wallpaper {
    monitor =
    path = $wallpapers/wallpaper.jpg
    fit_mode = cover
}
EOF
[ -f "$config/hypr/hyprsunset.conf" ] || cat > "$config/hypr/hyprsunset.conf" <<EOF
# Written by System Settings → Displays → Night Shift; changes here are overwritten.

profile {
    time = 0:00
    identity = true
}
EOF

cat <<EOF

Done. Next steps:
  - Put a wallpaper at $wallpapers/wallpaper.jpg (or pick one in System Settings → Wallpaper).
  - Install the MacTahoe GTK, icon and cursor themes:
      https://github.com/vinceliuice/MacTahoe-gtk-theme
      https://github.com/vinceliuice/MacTahoe-icon-theme
  - Enable services:  sudo systemctl enable --now power-profiles-daemon bluetooth
  - Wi-Fi uses wpa_supplicant (wpa_cli). With NetworkManager or iwd the Wi-Fi panels stay empty.
  - Optional title bars, from inside Hyprland:
      hyprpm add https://github.com/hyprwm/hyprland-plugins && hyprpm enable hyprbars
  - Optional login screen:  sudo sh $repo/lockscreen/greetd/install.sh
  - Log out and back in (or reload Hyprland with Super+Shift+R).
EOF
