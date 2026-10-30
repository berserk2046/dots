#!/bin/sh
# Prints paths of a few sample icons from an icon theme (largest PNG or SVG found), one per line.
theme=$1
for d in "$HOME/.icons" "$HOME/.local/share/icons" /usr/local/share/icons /usr/share/icons; do
    [ -d "$d/$theme" ] && root="$d/$theme" && break
done
[ -n "${root:-}" ] || exit 0
for name in folder user-trash utilities-terminal firefox preferences-system multimedia-audio-player; do
    find -L "$root" \( -name "$name.svg" -o -name "$name.png" \) 2>/dev/null | sort -t/ -k1 | grep -v '/symbolic/' | tail -1
done
