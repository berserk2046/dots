#!/bin/sh
# Prints CPU, memory, disk, battery and process info in "@section" blocks for System.qml. Needs no root.

echo "@stat"
grep '^cpu' /proc/stat

echo "@mem"
grep -E '^(MemTotal|MemAvailable|Buffers|Cached|SReclaimable|Shmem|SwapTotal|SwapFree):' /proc/meminfo

echo "@load"
cat /proc/loadavg
echo "@uptime"
cut -d' ' -f1 /proc/uptime

echo "@cpu"
grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^ *//'

echo "@temp"
for h in /sys/class/hwmon/hwmon*; do
    case $(cat "$h/name" 2>/dev/null) in
    k10temp | coretemp | zenpower) cat "$h/temp1_input" 2>/dev/null && break ;;
    esac
done

echo "@battery"
for b in /sys/class/power_supply/BAT*; do
    [ -e "$b/status" ] || continue
    for f in status capacity cycle_count energy_now energy_full energy_full_design charge_now charge_full \
        charge_full_design power_now current_now voltage_now manufacturer model_name technology; do
        [ -r "$b/$f" ] && echo "$f=$(cat "$b/$f")"
    done
    break
done
for a in /sys/class/power_supply/*; do
    [ "$(cat "$a/type" 2>/dev/null)" = Mains ] && echo "ac_online=$(cat "$a/online")"
done

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

# Current per-process CPU: the second `top` iteration measures the last half second.
echo "@procs"
top -b -n 2 -d 0.5 -o %CPU -e k -w 512 2>/dev/null | awk '
    /^top -/ { n++ }
    n == 2 && $1 == "PID" { rows = 1; next }
    n == 2 && rows && NF >= 12 && count++ < 12 {
        cmd = $12; for (i = 13; i <= NF; i++) cmd = cmd " " $i
        print $1 "\t" $9 "\t" $6 "\t" cmd
    }'
echo "@end"
