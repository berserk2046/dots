#!/bin/sh
# Prints what changes from second to second (CPU, memory, temperature, battery, processes) in
# "@section" blocks for System.qml, every couple of seconds while a panel shows them. Only shell
# built-ins, so a run starts no programs; the rest (disks, energy mode, CPU model) is in sys-info.sh,
# polled less often. Needs no root.

echo "@stat"
while read -r line; do
    case $line in
    cpu*) printf '%s\n' "$line" ;;
    *) break ;;
    esac
done </proc/stat

echo "@mem"
while read -r line; do
    case $line in
    MemTotal:* | MemAvailable:* | Buffers:* | Cached:* | SReclaimable:* | Shmem:* | SwapTotal:* | SwapFree:*)
        printf '%s\n' "$line" ;;
    esac
done </proc/meminfo

echo "@load"
read -r line </proc/loadavg && printf '%s\n' "$line"
echo "@uptime"
read -r up _ </proc/uptime && printf '%s\n' "$up"

# Temperatures in thousandths of a degree, from the kernel's sensors (hwmon): "cpu <value>" from the
# processor's own sensor, "gpu <value>" for each graphics card that has one (AMD, Intel Xe, nouveau;
# NVIDIA's own driver has none here, it would take running nvidia-smi).
echo "@temp"
cpu_seen=
for h in /sys/class/hwmon/hwmon*; do
    name=
    read -r name <"$h/name" 2>/dev/null
    case $name in
    k10temp | coretemp | zenpower)
        [ -z "$cpu_seen" ] && read -r t <"$h/temp1_input" 2>/dev/null && printf 'cpu %s\n' "$t" && cpu_seen=1
        ;;
    amdgpu | radeon | nouveau | xe | i915)
        read -r t <"$h/temp1_input" 2>/dev/null && printf 'gpu %s\n' "$t"
        ;;
    esac
done

echo "@battery"
for b in /sys/class/power_supply/BAT*; do
    [ -e "$b/status" ] || continue
    for f in status capacity cycle_count energy_now energy_full energy_full_design charge_now charge_full \
        charge_full_design power_now current_now voltage_now manufacturer model_name technology; do
        [ -r "$b/$f" ] && read -r v <"$b/$f" 2>/dev/null && printf '%s=%s\n' "$f" "$v"
    done
    break
done
for a in /sys/class/power_supply/*; do
    t=
    read -r t <"$a/type" 2>/dev/null
    [ "$t" = Mains ] && read -r v <"$a/online" 2>/dev/null && printf 'ac_online=%s\n' "$v"
done

# Every process's /proc/<pid>/stat line; System.qml works out each one's CPU use from the change
# in its CPU time since the previous run. Processes that end meanwhile are skipped.
echo "@procs"
for f in /proc/[0-9]*/stat; do
    [ "$f" = "/proc/$$/stat" ] && continue
    read -r line <"$f" 2>/dev/null && printf '%s\n' "$line"
done
echo "@end"
