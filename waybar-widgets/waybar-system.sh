#!/bin/sh
# waybar custom/system module: CPU usage and used RAM in one label, refreshed every 2 seconds.
cpu_glyph=$(printf '\357\213\233') # nf-fa-microchip, as waybar's cpu module used
mem_glyph=$(printf '\357\203\211') # nf-fa-bars, as the memory module used
prev_total=0
prev_idle=0
while :; do
    set -- $(head -n 1 /proc/stat)
    idle=$(($5 + $6))
    total=$(($2 + $3 + $4 + $5 + $6 + $7 + $8 + $9))
    cpu=0
    [ "$prev_total" -gt 0 ] && [ "$total" -gt "$prev_total" ] &&
        cpu=$(((100 * ((total - prev_total) - (idle - prev_idle))) / (total - prev_total)))
    prev_total=$total
    prev_idle=$idle
    mem=$(awk '/^MemTotal:/ {t = $2} /^MemAvailable:/ {a = $2} END {printf "%.1f", (t - a) / 1048576}' /proc/meminfo)
    class=normal
    [ "$cpu" -ge 85 ] && class=high
    printf '{"text": "%s%% %s  %sG %s", "class": "%s"}\n' "$cpu" "$cpu_glyph" "$mem" "$mem_glyph" "$class"
    sleep 2
done
