#!/bin/sh
# Opens/closes a panel from waybar: toggle.sh wifi|volume|bluetooth|battery|system|display|power|date|media
# The panel opens centered under the cursor (hyprctl cursorpos); if the position can't be read,
# Popup.qml finds the pointer itself. The panels run inside desktop-shell; if it isn't running (it
# crashed and didn't come back, say), it's started first.
shell=$HOME/.config/desktop-shell
target=${1:-wifi}

case $target in
*[!a-z]* | '') exit 1 ;;
esac

pos=$(hyprctl cursorpos 2>/dev/null | tr -d ' ')
x=${pos%,*}
y=${pos#*,}

send() {
    case "$x$y" in
    *[!0-9-]* | '') qs -p "$shell" ipc call panel toggle "$target" >/dev/null 2>&1 ;;
    *) qs -p "$shell" ipc call panel toggleAt "$target" "$x" "$y" >/dev/null 2>&1 ;;
    esac
}

send && exit 0

icons=$(sed -n 's/^ *icon_theme = "\([A-Za-z0-9._ -]*\)",$/\1/p' "$HOME/.config/hypr/system-settings.lua" 2>/dev/null)
# Started as hyprland.lua starts it: one memory pool, and one drawing thread if System Settings says so
grep -q '^ *single_render_thread = true,$' "$HOME/.config/hypr/system-settings.lua" 2>/dev/null && export QSG_RENDER_LOOP=basic
MALLOC_CONF=narenas:1 QS_ICON_THEME=${icons:-MacTahoe-dark} qs -n -d -p "$shell" >/dev/null 2>&1
for _ in 1 2 3 4 5 6 7 8 9 10; do
    sleep 0.2
    send && exit 0
done
exit 1
