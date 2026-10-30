#!/bin/sh
# Privileged network actions for Network.qml, run through `sudo -n`.
#   net-admin.sh up|down <iface>
#   net-admin.sh renew <iface>                 ask dhcpcd to rebind (new lease, reload config)
#   net-admin.sh dhcp <iface>                  drop manual settings, back to DHCP
#   net-admin.sh static <iface> <addr/prefix> [router] [dns ...]
#   net-admin.sh radio on|off                  Wi-Fi rfkill (only used when rfkill needs root)
# Manual settings live in a marked block at the end of /etc/dhcpcd.conf.
set -e

conf=/etc/dhcpcd.conf
cmd=$1
iface=$2

fail() {
    echo "$*" >&2
    exit 1
}

valid_iface() {
    [ -n "$1" ] && [ -e "/sys/class/net/$1" ] && case $1 in *[!A-Za-z0-9_.-]*) false ;; esac
}

valid_ip() {
    echo "$1" | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}$' || return 1
    for octet in $(echo "$1" | tr . ' '); do
        [ "$octet" -le 255 ] || return 1
    done
}

# Rewrites dhcpcd.conf without <iface>'s block, plus whatever is piped in (the new block, if any).
# Written to a temp file next to it and renamed over it, so the file is never left half-written.
write_conf() {
    tmp=$(mktemp "$conf.XXXXXX")
    trap 'rm -f "$tmp"' EXIT
    {
        sed "/^# >>> waybar-widgets $1\$/,/^# <<< waybar-widgets $1\$/d" "$conf"
        cat
    } >"$tmp"
    chmod --reference="$conf" "$tmp"
    chown --reference="$conf" "$tmp"
    mv -f "$tmp" "$conf"
    trap - EXIT
}

rebind() {
    dhcpcd -n "$1" >/dev/null 2>&1 || true
}

case $cmd in
up | down)
    valid_iface "$iface" || fail "Unknown interface"
    ip link set dev "$iface" "$cmd"
    ;;
renew)
    valid_iface "$iface" || fail "Unknown interface"
    dhcpcd -n "$iface"
    ;;
dhcp)
    valid_iface "$iface" || fail "Unknown interface"
    write_conf "$iface" </dev/null
    ip -4 addr flush dev "$iface"
    rebind "$iface"
    ;;
static)
    valid_iface "$iface" || fail "Unknown interface"
    address=${3%/*}
    prefix=${3#*/}
    [ "$prefix" = "$3" ] && prefix=24
    valid_ip "$address" || fail "Invalid IP address"
    case $prefix in '' | *[!0-9]*) fail "Invalid prefix length" ;; esac
    [ "$prefix" -ge 1 ] && [ "$prefix" -le 32 ] || fail "Invalid prefix length"
    router=$4
    [ -z "$router" ] || valid_ip "$router" || fail "Invalid router address"
    if [ $# -ge 4 ]; then shift 4; else shift $#; fi
    for dns in "$@"; do
        valid_ip "$dns" || fail "Invalid DNS server: $dns"
    done
    cp -n "$conf" "$conf.waybar-widgets.bak"
    {
        echo "# >>> waybar-widgets $iface"
        echo "interface $iface"
        echo "static ip_address=$address/$prefix"
        [ -n "$router" ] && echo "static routers=$router"
        [ $# -gt 0 ] && echo "static domain_name_servers=$*"
        echo "# <<< waybar-widgets $iface"
    } | write_conf "$iface"
    ip -4 addr flush dev "$iface"
    rebind "$iface"
    ;;
radio)
    case $iface in
    on) rfkill unblock wlan ;;
    off) rfkill block wlan ;;
    *) fail "Usage: radio on|off" ;;
    esac
    ;;
*)
    fail "Unknown command: $cmd"
    ;;
esac
