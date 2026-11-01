#!/bin/sh
# Applies Appearance settings to GTK (gsettings for GTK 4/libadwaita, settings.ini for GTK 3, the
# theme's gtk-4.0 CSS linked into ~/.config/gtk-4.0 for libadwaita)
# Hyprland (cursor, title bar colors) and waybar's colors:
#   appearance.sh scheme dark|light     color scheme; swaps a -Dark/-Light GTK theme to its other variant
#   appearance.sh gtk <theme>
#   appearance.sh icons <theme>
#   appearance.sh cursor <theme> <size>
set -u
schema=org.gnome.desktop.interface

# Sets a key in [Settings] of both GTK settings.ini files.
ini() {
    for v in 3.0 4.0; do
        f="$HOME/.config/gtk-$v/settings.ini"
        mkdir -p "$(dirname "$f")"
        python3 - "$f" "$1" "$2" <<'PY'
import sys, configparser
path, key, value = sys.argv[1:]
c = configparser.ConfigParser(interpolation=None)
c.optionxform = str
c.read(path)
if not c.has_section("Settings"):
    c.add_section("Settings")
c["Settings"][key] = value
with open(path, "w") as f:
    c.write(f, space_around_delimiters=False)
PY
    done
}

theme_exists() {
    [ "$1" = Adwaita ] && return 0
    for d in "$HOME/.themes" "$HOME/.local/share/themes" /usr/local/share/themes /usr/share/themes; do
        [ -d "$d/$1" ] && return 0
    done
    return 1
}

# libadwaita apps ignore the GTK theme and only load ~/.config/gtk-4.0/gtk.css, so the theme's GTK 4
# files are linked there (what the themes' own installers do with their libadwaita option). Removed
# for themes without GTK 4 files (e.g. Adwaita); files there that aren't our links are left alone.
adwaita_links() {
    src=
    for d in "$HOME/.themes" "$HOME/.local/share/themes" /usr/local/share/themes /usr/share/themes; do
        [ -f "$d/$1/gtk-4.0/gtk.css" ] && { src=$d/$1/gtk-4.0; break; }
    done
    dest=$HOME/.config/gtk-4.0
    mkdir -p "$dest"
    for f in gtk.css gtk-dark.css assets windows-assets; do
        [ -e "$dest/$f" ] && [ ! -L "$dest/$f" ] && continue
        rm -f "$dest/$f"
        [ -n "$src" ] && [ -e "$src/$f" ] && ln -s "$src/$f" "$dest/$f"
    done
    return 0
}

case "${1:-}" in
scheme)
    # e.g. WhiteSur-Light <-> WhiteSur-Dark; first, so whatever follows color-scheme sees the new theme
    current=$(gsettings get $schema gtk-theme | tr -d "'")
    if [ "$2" = dark ]; then other=$(echo "$current" | sed 's/-[Ll]ight$/-Dark/'); else other=$(echo "$current" | sed 's/-[Dd]ark$/-Light/'); fi
    if [ "$other" != "$current" ] && theme_exists "$other"; then
        gsettings set $schema gtk-theme "$other"
        ini gtk-theme-name "$other"
        adwaita_links "$other"
    fi
    if [ "$2" = dark ]; then
        gsettings set $schema color-scheme prefer-dark
        ini gtk-application-prefer-dark-theme 1
    else
        gsettings set $schema color-scheme prefer-light
        ini gtk-application-prefer-dark-theme 0
    fi
    # Title bars (hyprbars in hyprland.lua) read the scheme from settings.ini when the config loads
    hyprctl reload config-only >/dev/null 2>&1
    # The menu bar: waybar's style.css imports colors.css
    if [ -f "$HOME/.config/waybar/colors-$2.css" ]; then
        cp "$HOME/.config/waybar/colors-$2.css" "$HOME/.config/waybar/colors.css"
        pkill -SIGUSR2 -x waybar
    fi
    ;;
gtk)
    gsettings set $schema gtk-theme "$2"
    ini gtk-theme-name "$2"
    adwaita_links "$2"
    ;;
icons)
    gsettings set $schema icon-theme "$2"
    ini gtk-icon-theme-name "$2"
    ;;
cursor)
    gsettings set $schema cursor-theme "$2"
    gsettings set $schema cursor-size "$3"
    ini gtk-cursor-theme-name "$2"
    ini gtk-cursor-theme-size "$3"
    hyprctl setcursor "$2" "$3" >/dev/null
    ;;
*)
    echo "usage: $0 scheme dark|light | gtk <theme> | icons <theme> | cursor <theme> <size>" >&2
    exit 1
    ;;
esac
