#!/usr/bin/env python3
"""Sets the desktop picture for System Settings → Wallpaper:
     wallpaper.py ['<json of the "wallpaper" settings>']
(without an argument it reads them from settings.json). Writes ~/.config/hypr/hyprpaper.conf and
switches the running hyprpaper over to it, or starts it.

hyprpaper keeps each picture decoded at its full size: a picture larger than the display takes more
memory than the display needs. So for each connected display, the picture is first
scaled down to exactly that display's size in pixels ("cover": scaled to fill it and cropped in the
middle, as hyprpaper does; "contain": scaled to fit inside it), into
~/.local/state/system-settings/wallpapers. Pictures no larger than the display, and tiled ones, are
used as they are. The catch-all entry keeps the original picture, for displays connected later.
System Settings runs this again after a display's resolution changes. When the desktop draws the
wallpaper instead (System Settings → Wallpaper), it uses the same copies (listed in index.json there,
and it runs this for displays without one) and hyprpaper isn't started; hyprpaper.conf is still kept
up to date."""
import gi, hashlib, json, os, subprocess, sys, time

gi.require_version("GdkPixbuf", "2.0")
from gi.repository import GdkPixbuf, GLib

HOME = os.path.expanduser("~")
SETTINGS = os.path.join(HOME, ".config/system-settings/settings.json")
CONF = os.path.join(HOME, ".config/hypr/hyprpaper.conf")
CACHE = os.path.join(os.environ.get("XDG_STATE_HOME", os.path.join(HOME, ".local/state")),
                     "system-settings", "wallpapers")
DEFAULT = os.path.join(HOME, "Pictures/Wallpapers/wallpaper.jpg")


def hyprctl(*args):
    return subprocess.run(["hyprctl", *args], capture_output=True, text=True)


def display_key(m):
    """How settings.json names a monitor: make, model and serial (Hyprland's description), plus the
    port without a serial number. The same as shell-common/Displays.qml."""
    description = m.get("description")
    if not description:
        return m["name"]
    return description if m.get("serial") else "%s (%s)" % (description, m["name"])


def displays():
    """Connected displays as (name, width, height, key), sizes in physical pixels."""
    try:
        monitors = json.loads(hyprctl("monitors", "-j").stdout)
    except ValueError:
        return []
    result = []
    for m in monitors:
        w, h = m["width"], m["height"]
        if m.get("transform", 0) % 2 == 1:  # rotated by 90° or 270°
            w, h = h, w
        result.append((m["name"], w, h, display_key(m)))
    return result


def scaled(path, width, height, fit):
    """A copy of `path` scaled down for a width×height display, or `path` itself when that wouldn't
    save anything."""
    if fit not in ("cover", "contain") or not os.path.isfile(path):
        return path
    st = os.stat(path)
    key = "%s|%d|%d|%dx%d|%s" % (os.path.realpath(path), st.st_mtime_ns, st.st_size, width, height, fit)
    name = hashlib.sha1(key.encode()).hexdigest()[:16]
    for ext in (".jpg", ".png"):
        if os.path.isfile(os.path.join(CACHE, name + ext)):
            return os.path.join(CACHE, name + ext)

    # The size alone, without decoding the picture.
    info = GdkPixbuf.Pixbuf.get_file_info(path)
    if not info or not info[0]:
        return path
    w, h = info[1], info[2]
    s = max(width / w, height / h) if fit == "cover" else min(width / w, height / h)
    if s >= 1:
        return path

    try:
        pixbuf = GdkPixbuf.Pixbuf.new_from_file(path)
    except GLib.Error:
        return path
    sw, sh = max(1, round(w * s)), max(1, round(h * s))
    if fit == "cover":
        sw, sh = max(sw, width), max(sh, height)
    out = pixbuf.scale_simple(sw, sh, GdkPixbuf.InterpType.HYPER)
    if fit == "cover":
        out = out.new_subpixbuf((sw - width) // 2, (sh - height) // 2, width, height)

    os.makedirs(CACHE, exist_ok=True)
    if pixbuf.get_has_alpha():
        target, kind, keys, values = os.path.join(CACHE, name + ".png"), "png", [], []
    else:
        target, kind, keys, values = os.path.join(CACHE, name + ".jpg"), "jpeg", ["quality"], ["95"]
    out.savev(target + ".tmp", kind, keys, values)
    os.replace(target + ".tmp", target)
    return target


def block(monitor, path, fit):
    return ["", "wallpaper {", "    monitor = " + monitor, "    path = " + path, "    fit_mode = " + fit, "}"]


def main():
    if len(sys.argv) > 1:
        settings = json.loads(sys.argv[1])
    else:
        try:
            with open(SETTINGS) as f:
                settings = json.load(f).get("wallpaper", {})
        except (OSError, ValueError):
            settings = {}
    main_path = settings.get("path") or DEFAULT
    per_monitor = settings.get("monitors") or {}
    fit = settings.get("fit") or "cover"

    connected = displays()
    # A display's own picture, by monitor (or by port name, as older settings have it)
    source = {name: per_monitor.get(key) or per_monitor.get(name) or main_path for name, w, h, key in connected}
    chosen = {name: scaled(source[name], w, h, fit) for name, w, h, key in connected}

    # Which copy fits which display, for the desktop when it draws the wallpaper (desktop/DesktopShell.qml)
    os.makedirs(CACHE, exist_ok=True)
    index = {name: {"source": source[name], "path": chosen[name], "fit": fit, "width": w, "height": h}
             for name, w, h, key in connected}
    with open(os.path.join(CACHE, "index.json.tmp"), "w") as f:
        json.dump(index, f, indent=1)
    os.replace(os.path.join(CACHE, "index.json.tmp"), os.path.join(CACHE, "index.json"))

    lines = ["# Written by System Settings → Wallpaper; changes here are overwritten.", "splash = false"]
    lines += block("", main_path, fit)
    for name, path in chosen.items():
        lines += block(name, path, fit)
    # Displays with their own picture that aren't connected right now, for hyprpaper to find by
    # description when they are (older settings: by port name)
    connected_keys = {key for name, w, h, key in connected} | set(chosen)
    for key, path in per_monitor.items():
        if key not in connected_keys:
            lines += block(key if "/" not in key and " " not in key else "desc:" + key.rsplit(" (", 1)[0], path, fit)
    os.makedirs(os.path.dirname(CONF), exist_ok=True)
    with open(CONF + ".tmp", "w") as f:
        f.write("\n".join(lines) + "\n")
    os.replace(CONF + ".tmp", CONF)

    # Scaled copies nothing uses any more
    if os.path.isdir(CACHE):
        used = set(chosen.values()) | {os.path.join(CACHE, "index.json")}
        for entry in os.listdir(CACHE):
            path = os.path.join(CACHE, entry)
            if path not in used:
                try:
                    os.remove(path)
                except OSError:
                    pass

    running = subprocess.run(["pgrep", "-x", "hyprpaper"], capture_output=True).returncode == 0
    # hyprctl splits its argument on commas, so a path with one needs a restart instead.
    if running and any("," in p for p in chosen.values()):
        subprocess.run(["pkill", "-x", "hyprpaper"])
        for _ in range(20):
            if subprocess.run(["pgrep", "-x", "hyprpaper"], capture_output=True).returncode != 0:
                break
            time.sleep(0.1)
        running = False
    if not running:
        # Not when the desktop draws the wallpaper (System Settings passes startHyprpaper: false); else
        # through Hyprland, so hyprpaper isn't tied to this script or System Settings.
        if settings.get("startHyprpaper", True):
            hyprctl("dispatch", 'hl.dsp.exec_cmd("hyprpaper")')
        return
    for name, path in chosen.items():
        hyprctl("hyprpaper", "wallpaper", "%s,%s,%s" % (name, path, fit))


if __name__ == "__main__":
    main()
