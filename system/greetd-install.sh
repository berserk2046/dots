#!/bin/sh
# Installs or updates the login screen: greetd, the greeter files in /etc/greetd/lockscreen, and
# greetd's config. Installed root-owned as /usr/local/libexec/desktop-helpers/greetd-install by
# system/install.sh. Run it as root from your own account:
#     sudo /usr/local/libexec/desktop-helpers/greetd-install [wallpaper]
# or use System Settings → Lock Screen → Login screen → Update, which runs it through pkexec (polkit
# action org.dotfiles.desktop.greetd-install, asks for an administrator's password).
# Run it again after changing the lock screen, to update the login screen's copy.
# It only enables greetd; it starts on the next boot.
#
# It runs as root on behalf of your account, so everything of yours it copies (the lock screen's
# files, the wallpaper, your picture, a few settings) is read as you, never as root: a link in your
# folders can't make it copy a file you couldn't read yourself.
set -eu
PATH=/usr/local/sbin:/usr/local/bin:/usr/bin:/usr/sbin
export PATH
umask 022

share=/usr/local/share/desktop-helpers/greetd
dest=/etc/greetd/lockscreen

fail() {
    echo "$*" >&2
    exit 1
}

[ "$(id -u)" -eq 0 ] || fail "Run as root: sudo $0"
uid=${PKEXEC_UID:-${SUDO_UID:-}}
case $uid in '' | *[!0-9]* | 0) fail "Run with sudo (or pkexec) from your own account" ;; esac

# The account the login screen signs in
user=$(getent passwd "$uid" | cut -d: -f1)
user_home=$(getent passwd "$uid" | cut -d: -f6)
[ -n "$user" ] && [ -d "$user_home" ] || fail "No such account: $uid"

as_user() {
    runuser -u "$user" -- "$@"
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# copy <file of yours> <destination> <mode>: read as you, written as root
copy() {
    as_user cat -- "$1" >"$tmp/file" || return 1
    install -m "$3" "$tmp/file" "$2"
}

# Plain file names only
qml_files() {
    as_user find -L "$1" -maxdepth 1 -type f -name '*.qml' -printf '%f\n' | grep -E '^[A-Za-z0-9_.-]+\.qml$' || true
}

src=$user_home/.config/lockscreen
as_user test -f "$src/greeter.qml" || fail "No lock screen in $src"

# Wallpaper: the argument, else the one picked in System Settings, else ~/Pictures/Wallpapers/wallpaper.jpg
settings=$user_home/.config/system-settings/settings.json
have_settings=false
if as_user cat -- "$settings" >"$tmp/settings.json" 2>/dev/null; then
    have_settings=true
else
    echo '{}' >"$tmp/settings.json"
fi
picked=$(python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1])).get("wallpaper", {}).get("path", ""))' "$tmp/settings.json" 2>/dev/null || true)
wallpaper=${1:-${picked:-$user_home/Pictures/Wallpapers/wallpaper.jpg}}
as_user test -f "$wallpaper" || fail "Wallpaper not found: $wallpaper (pass one: $0 /path/to/image)"

pacman -Q greetd >/dev/null 2>&1 || pacman -S --needed --noconfirm greetd

# The greeter user can't read your home folder, so it gets its own copy of everything it shows.
rm -rf "$dest"
install -d -m 755 "$dest" "$dest/common"
for f in $(qml_files "$src"); do
    copy "$src/$f" "$dest/$f" 644
done
for f in $(qml_files "$src/common"); do
    copy "$src/common/$f" "$dest/common/$f" 644
done
copy "$src/wifi-status.sh" "$dest/wifi-status.sh" 755
copy "$wallpaper" "$dest/wallpaper.jpg" 644
if as_user test -f "$user_home/.face"; then
    copy "$user_home/.face" "$dest/face" 644
fi

# What the login screen needs of your settings, and nothing else of them: its message, the main
# display and your account's name in settings.json (read by Config.qml); the displays' arrangement and
# the keyboard layouts for its Hyprland in greeter-settings.lua. Every value is checked.
python3 -I - "$tmp/settings.json" "$user" "$dest/settings.json" /etc/greetd/greeter-settings.lua <<'PY'
import json, re, sys

source, user, settings_out, lua_out = sys.argv[1:]
try:
    data = json.load(open(source))
    if not isinstance(data, dict):
        data = {}
except (OSError, ValueError):
    data = {}


def section(name):
    value = data.get(name)
    return value if isinstance(value, dict) else {}


def text(value, limit):
    return value[:limit] if isinstance(value, str) else ""


out = {
    "lockScreen": {"message": text(section("lockScreen").get("message"), 200)},
    "displays": {"main": text(section("displays").get("main"), 200)},
    "login": {"user": user},
}
with open(settings_out, "w") as f:
    json.dump(out, f, indent=2)
    f.write("\n")


def lua_string(value):
    # ASCII only, with every quote, backslash and control character escaped
    return json.dumps(value, ensure_ascii=True) if re.fullmatch(r"[\x20-\x7e]*", value) else None


lines = ["-- Written by greetd-install from System Settings; changes here are overwritten.", "return {"]
layouts = section("keyboard").get("layouts")
if isinstance(layouts, list) and layouts:
    names = [l.get("layout", "") if isinstance(l, dict) else "" for l in layouts]
    variants = [(l.get("variant") or "") if isinstance(l, dict) else "" for l in layouts]
    if all(isinstance(n, str) and re.fullmatch(r"[A-Za-z0-9_-]+", n) for n in names) and \
            all(isinstance(v, str) and re.fullmatch(r"[A-Za-z0-9_()-]*", v) for v in variants):
        lines.append("    kb_layout = %s," % json.dumps(",".join(names)))
        lines.append("    kb_variant = %s," % json.dumps(",".join(variants)))

rules = []
monitors = section("displays").get("monitors")
for m in monitors if isinstance(monitors, list) else []:
    if not isinstance(m, dict):
        continue
    output = m.get("output")
    if not isinstance(output, str) or not 0 < len(output) < 200 or lua_string(output) is None:
        continue
    fields = ["output = " + lua_string(output)]
    if m.get("disabled") is True:
        fields.append("disabled = true")
    else:
        mode, position = m.get("mode"), m.get("position")
        if not (isinstance(mode, str) and re.fullmatch(r"\d{3,5}x\d{3,5}(@\d{1,3}(\.\d{1,6})?)?", mode)):
            continue
        if not (isinstance(position, str) and re.fullmatch(r"-?\d{1,6}x-?\d{1,6}", position)):
            continue
        fields += ["mode = " + json.dumps(mode), "position = " + json.dumps(position)]
        scale = m.get("scale")
        if isinstance(scale, (int, float)) and not isinstance(scale, bool) and 0.25 <= scale <= 8:
            fields.append("scale = %s" % round(float(scale), 2))
        transform = m.get("transform")
        if isinstance(transform, int) and not isinstance(transform, bool) and 0 <= transform <= 7:
            fields.append("transform = %d" % transform)
        mirror = m.get("mirror")
        if isinstance(mirror, str) and re.fullmatch(r"[A-Za-z0-9_-]{1,40}", mirror):
            fields.append("mirror = " + json.dumps(mirror))
    rules.append("        { " + ", ".join(fields) + " },")
if rules:
    lines += ["    monitors = {"] + rules + ["    },"]
lines.append("}")
with open(lua_out, "w") as f:
    f.write("\n".join(lines) + "\n")
PY
chmod 644 "$dest/settings.json" /etc/greetd/greeter-settings.lua

[ -f /etc/greetd/config.toml ] && [ ! -f /etc/greetd/config.toml.orig ] && cp /etc/greetd/config.toml /etc/greetd/config.toml.orig
install -m 644 "$share/config.toml" /etc/greetd/config.toml
install -m 644 "$share/hyprland.lua" /etc/greetd/hyprland.lua

systemctl enable greetd.service

echo "Done. The login screen starts on the next boot (greetd on tty1)."
echo "Undo: sudo systemctl disable greetd.service"
