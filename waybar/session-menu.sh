#!/bin/sh
# Session menu for the power button's right click.

choice=$(printf '%s\n' "Shut Down" "Restart" "Sleep" "Lock" "Log Out" | fuzzel -d -p "Session: ")

case "$choice" in
    "Shut Down") systemctl poweroff ;;
    "Restart")   systemctl reboot ;;
    "Sleep")     systemctl suspend ;;
    "Lock")      qs -p ~/.config/lockscreen ipc call lock lockNow ;;
    "Log Out")   hyprctl dispatch 'hl.dsp.exit()' ;;
esac
