#!/bin/sh
# Prints key=value lines for General → About.
. /etc/os-release 2>/dev/null
echo "os=${PRETTY_NAME:-Linux}"
echo "hostname=$(cat /etc/hostname 2>/dev/null || uname -n)"
echo "kernel=$(uname -r)"
echo "vendor=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null)"
echo "model=$(cat /sys/class/dmi/id/product_version 2>/dev/null) $(cat /sys/class/dmi/id/product_name 2>/dev/null)"
echo "cpu=$(sed -n 's/^model name[[:space:]]*: //p' /proc/cpuinfo | head -1) ($(nproc) threads)"
echo "memory=$(awk '/MemTotal/ {printf "%.0f GB", $2 / 1048576}' /proc/meminfo)"
lspci 2>/dev/null | sed -n 's/.*\(VGA compatible controller\|3D controller\|Display controller\): //p' | sed 's/^/gpu=/'
hyprctl monitors -j 2>/dev/null | python3 -c '
import json, sys
for m in json.load(sys.stdin):
    print("display=%s: %s, %dx%d @ %.0f Hz" % (m["name"], m["description"], m["width"], m["height"], m["refreshRate"]))'
echo "hyprland=$(hyprctl version -j 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin)["tag"])')"
echo "quickshell=$(qs --version 2>/dev/null | head -1 | cut -d' ' -f2)"
echo "uptime=$(cut -d' ' -f1 /proc/uptime)"
