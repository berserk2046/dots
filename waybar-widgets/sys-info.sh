#!/bin/sh
# Prints what rarely changes (CPU model, energy mode, charge limit, disks) in "@section" blocks for
# System.qml: when a panel opens, every 30 seconds while it's open, and after changing the energy
# mode or the charge limit. The rest is in sys-status.sh. Needs no root.

echo "@cpu"
while IFS= read -r line; do
    case $line in
    "model name"*) printf '%s\n' "${line#*: }" && break ;;
    esac
done </proc/cpuinfo

echo "@pagesize"
getconf PAGESIZE 2>/dev/null || echo 4096

# power-profiles-daemon: active profile, then the list (one JSON value per line).
echo "@profiles"
busctl --system -j get-property net.hadess.PowerProfiles /net/hadess/PowerProfiles net.hadess.PowerProfiles \
    ActiveProfile Profiles 2>/dev/null

# UPower's charge limit (conservation mode on IdeaPads): supported, enabled.
bat=$(upower -e 2>/dev/null | grep -m 1 battery_)
echo "@charge $bat"
[ -n "$bat" ] && busctl --system -j get-property org.freedesktop.UPower "$bat" org.freedesktop.UPower.Device \
    ChargeThresholdSupported ChargeThresholdEnabled 2>/dev/null

# Real filesystems, one line per device: device size used avail mount fstype model
echo "@disks"
df -B1 --output=source,size,used,avail,target,fstype -x tmpfs -x devtmpfs -x efivarfs -x overlay -x squashfs \
    2>/dev/null | tail -n +2 | while read -r src size used avail target fstype; do
    case $src in /dev/*) ;; *) continue ;; esac
    case $fstype in vfat | exfat) [ "$target" = / ] || continue ;; esac
    parent=$(lsblk -no pkname "$src" 2>/dev/null | head -n 1)
    model=$(cat "/sys/block/${parent:-x}/device/model" 2>/dev/null | sed 's/ *$//')
    echo "$src $size $used $avail $target $fstype ${model:-}"
done | awk '!seen[$1]++'
echo "@end"
