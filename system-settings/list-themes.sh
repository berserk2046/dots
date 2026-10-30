#!/bin/sh
# Prints the installed themes for Appearance: gtk=, icons=, cursors= lines, then the current values.
dirs_themes="$HOME/.themes $HOME/.local/share/themes /usr/local/share/themes /usr/share/themes"
dirs_icons="$HOME/.icons $HOME/.local/share/icons /usr/local/share/icons /usr/share/icons"

echo "gtk=Adwaita" # built into GTK
for d in $dirs_themes; do
    for t in "$d"/*/; do
        [ -f "$t/gtk-3.0/gtk.css" ] || [ -f "$t/gtk-4.0/gtk.css" ] || continue
        echo "gtk=$(basename "$t")"
    done
done

for d in $dirs_icons; do
    for t in "$d"/*/; do
        name=$(basename "$t")
        [ -d "$t/cursors" ] && echo "cursors=$name"
        # Icon themes list their folders in index.theme; cursor-only themes don't.
        [ -f "$t/index.theme" ] && grep -q '^Directories=' "$t/index.theme" && [ "$name" != default ] && [ "$name" != hicolor ] && echo "icons=$name"
    done
done

echo "current-gtk=$(gsettings get org.gnome.desktop.interface gtk-theme | tr -d "'")"
echo "current-icons=$(gsettings get org.gnome.desktop.interface icon-theme | tr -d "'")"
echo "current-cursors=$(gsettings get org.gnome.desktop.interface cursor-theme | tr -d "'")"
echo "current-size=$(gsettings get org.gnome.desktop.interface cursor-size)"
echo "current-scheme=$(gsettings get org.gnome.desktop.interface color-scheme | tr -d "'")"
