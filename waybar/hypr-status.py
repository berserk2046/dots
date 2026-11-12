#!/usr/bin/env python3
"""waybar custom modules fed by Hyprland's event socket, one JSON line per change:
     hypr-status.py app       name of the focused app, from its .desktop entry (bold on the left, like macOS)
     hypr-status.py keyboard  active keyboard layout as a short code ("US"); empty, so hidden, with one layout
The app mode also keeps the keyboard layout in $XDG_RUNTIME_DIR/waybar/keyboard.json and sends waybar
SIGRTMIN+10 when it changes, so the custom/keyboard module can just read that file and the bar needs
one Python process instead of two.
"""
import glob, html, json, os, signal, socket, subprocess, sys

# custom/keyboard's "signal" in waybar's config
KEYBOARD_SIGNAL = 10


def hyprctl(*args):
    try:
        return json.loads(subprocess.run(["hyprctl", "-j", *args], capture_output=True, text=True).stdout)
    except (ValueError, OSError):
        return {}


def desktop_names():
    """Window class (lowercase) -> app name, from the .desktop files. StartupWMClass wins over file names."""
    data_home = os.environ.get("XDG_DATA_HOME", os.path.expanduser("~/.local/share"))
    data_dirs = os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share").split(":")
    dirs = [data_home, "/var/lib/flatpak/exports/share", *data_dirs]
    names, weak = {}, {}
    # Later directories lose, so a user's own entry beats the system one.
    for d in reversed(dirs):
        for path in glob.glob(os.path.join(d, "applications", "**", "*.desktop"), recursive=True):
            entry, section = {}, None
            try:
                with open(path, encoding="utf-8", errors="replace") as f:
                    for line in f:
                        line = line.strip()
                        if line.startswith("["):
                            section = line
                        elif section == "[Desktop Entry]" and "=" in line:
                            key, value = line.split("=", 1)
                            entry.setdefault(key.strip(), value.strip())
            except OSError:
                continue
            # "Spotify (Launcher)" -> "Spotify"
            name = entry.get("Name", "").split(" (")[0]
            if not name:
                continue
            base = os.path.basename(path)[:-len(".desktop")].lower()
            if entry.get("StartupWMClass"):
                names[entry["StartupWMClass"].lower()] = name
            weak[base] = name
            weak.setdefault(base.split(".")[-1], name)  # org.gnome.Nautilus -> nautilus
            command = entry.get("Exec", "").split(" ")[0]
            if command:
                weak.setdefault(os.path.basename(command).lower(), name)
    weak.update(names)
    return weak


def app_name(cls, names):
    if not cls:
        return ""
    key = cls.lower()
    if key in names:
        return names[key]
    last = cls.split(".")[-1]
    return names.get(last.lower(), last[:1].upper() + last[1:])


def keyboard():
    keyboards = hyprctl("devices").get("keyboards", [])
    main = next((k for k in keyboards if k.get("main")), keyboards[0] if keyboards else None)
    if not main:
        return {"text": ""}
    layouts = [l for l in main.get("layout", "").split(",") if l]
    if len(layouts) < 2:
        return {"text": ""}
    index = main.get("active_layout_index", 0)
    code = layouts[index] if 0 <= index < len(layouts) else layouts[0]
    return {"text": html.escape(code.upper()), "tooltip": main.get("active_keymap", "")}


def runtime_dir():
    return os.environ.get("XDG_RUNTIME_DIR", "/run/user/%d" % os.getuid())


def signal_waybar():
    """SIGRTMIN+KEYBOARD_SIGNAL to this user's waybar, which then re-reads keyboard.json."""
    uid = os.getuid()
    for pid in os.listdir("/proc"):
        if not pid.isdigit():
            continue
        try:
            with open("/proc/%s/comm" % pid) as f:
                if f.read().strip() != "waybar":
                    continue
            if os.stat("/proc/" + pid).st_uid == uid:
                os.kill(int(pid), signal.SIGRTMIN + KEYBOARD_SIGNAL)
        except OSError:
            pass


def publish_keyboard(force=False):
    """Writes the keyboard layout for custom/keyboard and tells waybar, if it changed."""
    path = os.path.join(runtime_dir(), "waybar", "keyboard.json")
    data = json.dumps(keyboard()) + "\n"
    try:
        with open(path) as f:
            if f.read() == data and not force:
                return
    except OSError:
        pass
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path + ".tmp", "w") as f:
        f.write(data)
    os.replace(path + ".tmp", path)
    signal_waybar()


def emit(value):
    sys.stdout.write(json.dumps(value) + "\n")
    sys.stdout.flush()


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "app"
    names = desktop_names() if mode == "app" else {}
    if mode == "app":
        emit({"text": html.escape(app_name(hyprctl("activewindow").get("class", ""), names))})
        # Even when unchanged: waybar may have read a file left from before this process started.
        publish_keyboard(force=True)
    else:
        emit(keyboard())

    path = os.path.join(runtime_dir(), "hypr", os.environ["HYPRLAND_INSTANCE_SIGNATURE"], ".socket2.sock")
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.connect(path)
    buffer = b""
    while True:
        chunk = sock.recv(4096)
        if not chunk:
            return
        buffer += chunk
        *lines, buffer = buffer.split(b"\n")
        for raw in lines:
            event, _, data = raw.decode(errors="replace").partition(">>")
            if mode == "app" and event == "activewindow":
                emit({"text": html.escape(app_name(data.split(",", 1)[0], names))})
            elif event in ("activelayout", "configreloaded"):
                if mode == "app":
                    publish_keyboard()
                else:
                    emit(keyboard())


if __name__ == "__main__":
    main()
