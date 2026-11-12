#!/bin/sh
# Installs the parts of this desktop that run as root, owned by root so only an administrator can
# change them:
#   /usr/local/libexec/desktop-helpers/net-admin        Ethernet settings, Wi-Fi rfkill fallback
#   /usr/local/libexec/desktop-helpers/greetd-install   installs or updates the login screen
#   /usr/local/share/desktop-helpers/greetd/            the login screen's greetd and Hyprland config
#   /usr/share/polkit-1/actions/org.dotfiles.desktop.policy
# The desktop runs the two helpers through pkexec, which asks for an administrator's password in the
# desktop's own dialog. Nothing in your home folder ever runs as root.
# Run once, and again after these files change:  sudo sh system/install.sh
# Remove:  sudo sh system/install.sh --remove
set -eu

here=$(cd "$(dirname "$0")" && pwd)
libexec=/usr/local/libexec/desktop-helpers
share=/usr/local/share/desktop-helpers
policy=/usr/share/polkit-1/actions/org.dotfiles.desktop.policy

[ "$(id -u)" -eq 0 ] || { echo "Run as root: sudo sh $0" >&2; exit 1; }

if [ "${1:-}" = --remove ]; then
    rm -rf "$libexec" "$share" "$policy"
    echo "Removed. (The login screen, if installed, is untouched: sudo systemctl disable greetd.service)"
    exit 0
fi

install -d -m 755 -o root -g root "$libexec" "$share" "$share/greetd"
install -m 755 -o root -g root "$here/net-admin.sh" "$libexec/net-admin"
install -m 755 -o root -g root "$here/greetd-install.sh" "$libexec/greetd-install"
install -m 644 -o root -g root "$here/greetd/config.toml" "$here/greetd/hyprland.lua" "$share/greetd/"
install -m 644 -o root -g root "$here/org.dotfiles.desktop.policy" "$policy"

echo "Installed the helpers in $libexec and the polkit policy."
echo "Optional login screen:  sudo $libexec/greetd-install [wallpaper]"
