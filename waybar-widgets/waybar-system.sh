#!/bin/sh
# waybar custom/system module: a chip icon (the numbers are in the System panel), refreshed every 2
# seconds; class "high" (shown orange) above 85% CPU or 90% RAM in use.
glyph=$(printf '\363\260\215\233') # nf-md-memory
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
    mem=$(awk '/^MemTotal:/ {t = $2} /^MemAvailable:/ {a = $2} END {printf "%d", 100 * (t - a) / t}' /proc/meminfo)
    class=normal
    { [ "$cpu" -ge 85 ] || [ "$mem" -ge 90 ]; } && class=high
    printf '{"text": "%s", "class": "%s"}\n' "$glyph" "$class"
    sleep 2
done
