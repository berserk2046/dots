#!/bin/sh
# Opens/closes a panel from waybar: toggle.sh wifi|volume|bluetooth|battery|system|display|power|date
# On Hyprland the panel opens centered under the cursor (hyprctl cursorpos); elsewhere Popup.qml
# finds the pointer itself. Starts the shell first if it isn't running yet.
dir=$(dirname "$(readlink -f "$0")")
target=${1:-wifi}

pos=$(hyprctl cursorpos 2>/dev/null | tr -d ' ')
case $pos in
*[0-9],*[0-9]) call="toggleAt ${pos%,*} ${pos#*,}" ;;
*) call=toggle ;;
esac

# $call is split on purpose: "toggleAt <x> <y>".
# shellcheck disable=SC2086
if ! qs -p "$dir" ipc call "$target" $call 2>/dev/null; then
    qs -n -d -p "$dir" >/dev/null 2>&1
    for _ in 1 2 3 4 5 6 7 8 9 10; do
        sleep 0.2
        qs -p "$dir" ipc call "$target" $call 2>/dev/null && exit 0
    done
    exit 1
fi
