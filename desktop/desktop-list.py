#!/usr/bin/env python3
"""Lists the desktop folder for DesktopShell.qml:  desktop-list.py [folder]
Without a folder it uses XDG's desktop folder (~/Desktop). Prints JSON:
  {"folder": path, "exists": bool, "items": [{id, name, path, uri, dir, kind, icons, label, mtime}]}
- id: the inode, so a file renamed elsewhere (e.g. in a file manager) keeps its place on the desktop
- kind: "dir", "launcher" (a .desktop file), "image" (shown as a thumbnail) or "file"
- icons: icon names to try in order (from the file type, or the launcher's own icon; a path for a file icon)
- label: shown under the icon: a launcher's name, else the file name
- untrusted: a .desktop file not marked as a program yet (kind "file" until then)
Hidden files (".name") are left out, as in file managers. Runs only when the folder changes."""
import json, os, sys

import gi

gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib

try:  # GLib 2.86 moved .desktop files to GioUnix
    gi.require_version("GioUnix", "2.0")
    from gi.repository import GioUnix
    DesktopAppInfo = GioUnix.DesktopAppInfo
except (ValueError, ImportError):
    DesktopAppInfo = Gio.DesktopAppInfo

IMAGES = {"image/jpeg", "image/png", "image/webp", "image/gif", "image/bmp", "image/svg+xml"}
ATTRS = "standard::content-type,standard::icon,standard::type,unix::inode,time::modified"


def icon_names(icon):
    if isinstance(icon, Gio.ThemedIcon):
        return [n for n in icon.get_names() if not n.endswith("-symbolic")]
    if isinstance(icon, Gio.FileIcon) and icon.get_file().get_path():
        return [icon.get_file().get_path()]
    return []


def describe(folder, name):
    path = os.path.join(folder, name)
    gfile = Gio.File.new_for_path(path)
    try:
        info = gfile.query_info(ATTRS, Gio.FileQueryInfoFlags.NONE, None)
    except GLib.Error:
        # e.g. a broken link: shown, as a plain file
        st = os.lstat(path)
        return {"id": str(st.st_ino), "name": name, "path": path, "uri": gfile.get_uri(), "dir": False,
                "kind": "file", "icons": ["text-x-generic"], "label": name, "mtime": int(st.st_mtime)}
    is_dir = info.get_file_type() == Gio.FileType.DIRECTORY
    content_type = info.get_content_type() or ""
    icons = icon_names(info.get_icon())
    label = name
    kind = "dir" if is_dir else "image" if content_type in IMAGES else "file"
    untrusted = False
    if not is_dir and name.endswith(".desktop"):
        # Only a shortcut marked as a program (the executable bit; "Allow Launching" on the desktop
        # sets it) shows its app's name and icon and starts it. Any other .desktop file is shown as
        # the file it is: one that came with a download could call itself anything and run anything.
        if os.access(path, os.X_OK):
            app = DesktopAppInfo.new_from_filename(path)
            if app is not None:
                kind = "launcher"
                label = app.get_display_name() or app.get_name() or name
                icons = icon_names(app.get_icon()) + ["application-x-executable"]
        else:
            untrusted = True
            icons = ["text-x-generic"]
    modified = info.get_modification_date_time()
    return {
        "id": str(info.get_attribute_uint64("unix::inode")),
        "name": name,
        "path": path,
        "uri": gfile.get_uri(),
        "dir": is_dir,
        "kind": kind,
        "icons": icons + (["folder"] if is_dir else ["text-x-generic"]),
        "label": label,
        "mtime": modified.to_unix() if modified else 0,
        "untrusted": untrusted,
    }


def main():
    folder = sys.argv[1] if len(sys.argv) > 1 and sys.argv[1] else \
        GLib.get_user_special_dir(GLib.UserDirectory.DIRECTORY_DESKTOP) or os.path.expanduser("~/Desktop")
    folder = os.path.expanduser(folder)
    items = []
    exists = os.path.isdir(folder)
    if exists:
        for name in sorted(os.listdir(folder)):
            if name.startswith("."):
                continue
            try:
                items.append(describe(folder, name))
            except OSError:
                pass  # gone meanwhile
    json.dump({"folder": folder, "exists": exists, "items": items}, sys.stdout)


if __name__ == "__main__":
    main()
