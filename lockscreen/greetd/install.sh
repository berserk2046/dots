#!/bin/sh
# Installs the login screen: greetd, the greeter files in /etc/greetd/lockscreen, and greetd's config.
# Run as root:  sudo sh install.sh [wallpaper]
# Run it again after changing the lock screen to update the login screen's copy.
# It only enables greetd; it starts on the next boot.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
src=$(dirname "$here")

if [ "$(id -u)" -ne 0 ] || [ -z "${SUDO_USER:-}" ]; then
    echo "Run with sudo from your own account: sudo sh $0" >&2
    exit 1
fi

# The account the login screen signs in
user=$SUDO_USER
user_home=$(getent passwd "$user" | cut -d: -f6)
# Wallpaper: the argument, else the one picked in System Settings, else ~/Pictures/Wallpapers/wallpaper.jpg
settings=$user_home/.config/system-settings/settings.json
picked=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("wallpaper", {}).get("path", ""))' "$settings" 2>/dev/null || true)
wallpaper=${1:-${picked:-$user_home/Pictures/Wallpapers/wallpaper.jpg}}
[ -f "$wallpaper" ] || { echo "Wallpaper not found: $wallpaper (pass one: sudo sh $0 /path/to/image)" >&2; exit 1; }

pacman -Q greetd >/dev/null 2>&1 || pacman -S --needed --noconfirm greetd

# The greeter user can't read your home folder, so it gets its own copy of everything it shows.
install -d -m 755 /etc/greetd/lockscreen
install -m 644 "$src"/*.qml /etc/greetd/lockscreen/
# The greeter runs as the "greeter" user, so give it your account name
sed -i "s|Quickshell.env(\"USER\")|\"$user\"|" /etc/greetd/lockscreen/Config.qml
install -m 755 "$src"/wifi-status.sh /etc/greetd/lockscreen/
install -m 644 "$wallpaper" /etc/greetd/lockscreen/wallpaper.jpg
# Lock screen message and other System Settings values (read by Config.qml)
if [ -f "$settings" ]; then
    install -m 644 "$settings" /etc/greetd/lockscreen/settings.json
else
    rm -f /etc/greetd/lockscreen/settings.json
fi
if [ -f "$user_home/.face" ]; then
    install -m 644 "$user_home/.face" /etc/greetd/lockscreen/face
else
    rm -f /etc/greetd/lockscreen/face
fi

[ -f /etc/greetd/config.toml ] && [ ! -f /etc/greetd/config.toml.orig ] && cp /etc/greetd/config.toml /etc/greetd/config.toml.orig
install -m 644 "$here"/config.toml /etc/greetd/config.toml
install -m 644 "$here"/hyprland.lua /etc/greetd/hyprland.lua

systemctl enable greetd.service

echo "Done. The login screen starts on the next boot (greetd on tty1)."
echo "Undo: sudo systemctl disable greetd.service"
