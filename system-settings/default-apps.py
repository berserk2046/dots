#!/usr/bin/env python3
"""Default apps for Desktop & Dock.
     default-apps.py                     prints JSON: {role: {current, options: [{id, name, icon}]}}
     default-apps.py set <role> <id>     makes <id> (a desktop entry id) the default for <role>
Roles: browser, files, mail (through xdg-mime) and terminal (candidates only; the choice is kept
in System Settings and used by Hyprland's keybinds and the Dock)."""
import configparser, json, os, subprocess, sys

ROLES = {
    "browser": ["x-scheme-handler/http", "x-scheme-handler/https", "text/html", "application/xhtml+xml"],
    "files": ["inode/directory"],
    "mail": ["x-scheme-handler/mailto"],
}

def app_dirs():
    data_home = os.environ.get("XDG_DATA_HOME", os.path.expanduser("~/.local/share"))
    data_dirs = os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share").split(":")
    extra = [os.path.expanduser("~/.local/share/flatpak/exports/share"), "/var/lib/flatpak/exports/share"]
    for d in [data_home] + data_dirs + extra:
        yield os.path.join(d, "applications")

def entries():
    seen = {}
    for d in app_dirs():
        if not os.path.isdir(d):
            continue
        for root, _, files in os.walk(d):
            for f in files:
                if not f.endswith(".desktop"):
                    continue
                id_ = os.path.relpath(os.path.join(root, f), d)[:-8].replace("/", "-")
                if id_ in seen:
                    continue
                c = configparser.ConfigParser(interpolation=None, strict=False)
                try:
                    c.read(os.path.join(root, f), encoding="utf-8")
                    e = c["Desktop Entry"]
                except Exception:
                    continue
                seen[id_] = {
                    "id": id_,
                    "name": e.get("Name", id_),
                    "icon": e.get("Icon", ""),
                    "exec": e.get("Exec", ""),
                    "hidden": e.get("NoDisplay", "false") == "true" or e.get("Hidden", "false") == "true",
                    "mime": [m for m in e.get("MimeType", "").split(";") if m],
                    "categories": [m for m in e.get("Categories", "").split(";") if m],
                }
    return list(seen.values())

def query(mime):
    out = subprocess.run(["xdg-mime", "query", "default", mime], capture_output=True, text=True).stdout.strip()
    return out[:-8] if out.endswith(".desktop") else out

if len(sys.argv) >= 4 and sys.argv[1] == "set":
    role, id_ = sys.argv[2], sys.argv[3]
    subprocess.run(["xdg-mime", "default", id_ + ".desktop", *ROLES[role]], check=True)
    sys.exit(0)

all_entries = entries()
result = {}
for role, mimes in ROLES.items():
    options = [e for e in all_entries if not e["hidden"] and mimes[0] in e["mime"]]
    result[role] = {"current": query(mimes[0]), "options": sorted(
        [{"id": e["id"], "name": e["name"], "icon": e["icon"]} for e in options], key=lambda o: o["name"].lower())}
terminals = {}
for e in all_entries:
    if "TerminalEmulator" in e["categories"] and e["exec"]:
        command = e["exec"].split()[0].split("/")[-1]
        terminals.setdefault(command, {"id": command, "name": e["name"], "icon": e["icon"]})
result["terminal"] = {"current": "", "options": sorted(terminals.values(), key=lambda o: o["name"].lower())}
print(json.dumps(result))
