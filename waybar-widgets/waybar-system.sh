#!/bin/bash
# waybar custom/system module: a chip icon (the numbers are in the System panel), refreshed every 2
# seconds; class "high" (shown orange) above 85% CPU or 90% RAM in use.
# The loop starts no programs: it reads /proc with built-ins and waits with `read -t` (bash) on a pipe
# nothing writes to, instead of running `sleep` every time (waybar runs one copy per display).
glyph=$(printf '\363\260\215\233') # nf-md-memory
prev_total=0
prev_idle=0
exec 3<> <(:)
while :; do
    read -r _ user nice system idle iowait irq softirq steal _ </proc/stat
    idle=$((idle + iowait))
    total=$((user + nice + system + idle + irq + softirq + steal))
    cpu=0
    [ "$prev_total" -gt 0 ] && [ "$total" -gt "$prev_total" ] &&
        cpu=$(((100 * ((total - prev_total) - (idle - prev_idle))) / (total - prev_total)))
    prev_total=$total
    prev_idle=$idle
    mem_total=0
    mem_avail=0
    while read -r key value _; do
        case $key in
        MemTotal:) mem_total=$value ;;
        MemAvailable:) mem_avail=$value && break ;;
        esac
    done </proc/meminfo
    mem=0
    [ "$mem_total" -gt 0 ] && mem=$((100 * (mem_total - mem_avail) / mem_total))
    class=normal
    { [ "$cpu" -ge 85 ] || [ "$mem" -ge 90 ]; } && class=high
    printf '{"text": "%s", "class": "%s"}\n' "$glyph" "$class"
    read -r -t 2 -u 3 _
done
