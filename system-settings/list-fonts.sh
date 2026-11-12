#!/bin/sh
# Prints the installed fonts for Appearance → Fonts: ui= lines (every family), mono= lines (monospaced
# families), then the current values, as GTK and Qt apps read them (gsettings).
fc-list : family 2>/dev/null | cut -d, -f1 | sort -u | sed 's/^/ui=/'
fc-list :spacing=mono family 2>/dev/null | cut -d, -f1 | sort -u | sed 's/^/mono=/'
schema=org.gnome.desktop.interface
for key in font-name monospace-font-name text-scaling-factor font-antialiasing font-hinting; do
    echo "current-$key=$(gsettings get $schema $key | tr -d "'")"
done
