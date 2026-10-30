#!/bin/sh
# Prints network state in "@section" blocks for Network.qml to parse. Needs no root.
# Usage: net-status.sh [wifi-interface]

wifi=$1
if [ -z "$wifi" ]; then
    for dev in /sys/class/net/*; do
        [ -d "$dev/wireless" ] && { wifi=${dev##*/}; break; }
    done
fi

echo "@wifi $wifi"
if [ -n "$wifi" ]; then
    echo "@status"
    wpa_cli -i "$wifi" status 2>/dev/null
    echo "@signal"
    wpa_cli -i "$wifi" signal_poll 2>/dev/null
    echo "@networks"
    wpa_cli -i "$wifi" list_networks 2>/dev/null | tail -n +2
fi

echo "@rfkill"
for r in /sys/class/rfkill/rfkill*; do
    [ -e "$r/type" ] && echo "$(cat "$r/type") $(cat "$r/soft") $(cat "$r/hard")"
done

# Physical wired interfaces: have a device link and no wireless dir.
echo "@ethernet"
for dev in /sys/class/net/*; do
    name=${dev##*/}
    [ "$name" = lo ] || [ -d "$dev/wireless" ] || [ ! -e "$dev/device" ] && continue
    [ "$(cat "$dev/type" 2>/dev/null)" = 1 ] || continue
    carrier=$(cat "$dev/carrier" 2>/dev/null || echo 0)
    speed=$(cat "$dev/speed" 2>/dev/null || echo -1)
    echo "$name $(cat "$dev/operstate") ${carrier:-0} ${speed:--1} $(cat "$dev/address")"
done

echo "@addr"
ip -o -4 addr show 2>/dev/null | awk '{print $2, $4}'
echo "@addr6"
ip -o -6 addr show scope global 2>/dev/null | awk '{print $2, $4}'
echo "@routes"
ip -4 route show default 2>/dev/null
echo "@dns"
awk '$1 == "nameserver" {print $2}' /etc/resolv.conf 2>/dev/null

# Manual IPv4 settings written by net-admin.sh.
echo "@static"
sed -n '/^# >>> waybar-widgets /,/^# <<< waybar-widgets /p' /etc/dhcpcd.conf 2>/dev/null
echo "@end"
