#!/bin/sh
# Prints "<bars 0-3><tab><network name>" for the first wireless interface, or nothing without one.
# Uses wpa_cli when its socket is reachable (your session); the login screen's user can't reach it,
# so there it falls back to the signal level in /proc/net/wireless without a network name.

wifi=
for dev in /sys/class/net/*; do
    [ -d "$dev/wireless" ] && { wifi=${dev##*/}; break; }
done
[ -n "$wifi" ] || exit 0

bars() {
    # $1: RSSI in dBm
    if [ "$1" -ge -60 ]; then echo 3
    elif [ "$1" -ge -70 ]; then echo 2
    else echo 1
    fi
}

status=$(wpa_cli -i "$wifi" status 2>/dev/null)
if [ -n "$status" ]; then
    state=$(printf '%s\n' "$status" | sed -n 's/^wpa_state=//p')
    if [ "$state" != COMPLETED ]; then
        printf '0\t\n'
        exit 0
    fi
    ssid=$(printf '%s\n' "$status" | sed -n 's/^ssid=//p')
    rssi=$(wpa_cli -i "$wifi" signal_poll 2>/dev/null | sed -n 's/^RSSI=//p')
    printf '%s\t%s\n' "$(bars "${rssi:--100}")" "$ssid"
    exit 0
fi

# Level column is in dBm, e.g. "wlan0: 0000   54.  -56.  -256 ..."
rssi=$(awk -v dev="$wifi:" '$1 == dev { sub(/\.$/, "", $4); print int($4) }' /proc/net/wireless)
if [ -z "$rssi" ] || [ "$(cat "/sys/class/net/$wifi/operstate")" != up ]; then
    printf '0\t\n'
else
    printf '%s\t\n' "$(bars "$rssi")"
fi
