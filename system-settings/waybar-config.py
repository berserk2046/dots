#!/usr/bin/env python3
"""Edits waybar's config for System Settings → Control Center, keeping its comments and layout:
     waybar-config.py modules '<json list>'        sets "modules-right"
     waybar-config.py clock '<strftime format>' <interval seconds>
                                                   sets custom/date's exec and interval
then reloads waybar (SIGUSR2). WAYBAR_CONFIG=<file> edits that file instead, without reloading."""
import json, os, re, signal, subprocess, sys

path = os.environ.get("WAYBAR_CONFIG", os.path.expanduser("~/.config/waybar/config"))
text = open(path).read()

def block_span(name):
    """Start and end of the object for a top-level module like "custom/date": { ... }."""
    m = re.search(r'"%s"\s*:\s*\{' % re.escape(name), text)
    if not m:
        sys.exit("waybar config has no %s module" % name)
    depth, i = 0, m.end() - 1
    while i < len(text):
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
            if depth == 0:
                return m.start(), i + 1
        i += 1
    sys.exit("unbalanced braces in waybar config")

if sys.argv[1] == "modules":
    modules = json.loads(sys.argv[2])
    text, n = re.subn(r'("modules-right"\s*:\s*)\[[^\]]*\]', lambda m: m.group(1) + json.dumps(modules), text, count=1)
    if n == 0:
        sys.exit("waybar config has no modules-right")
elif sys.argv[1] == "clock":
    fmt, interval = sys.argv[2], int(sys.argv[3])
    start, end = block_span("custom/date")
    block = text[start:end]
    block = re.sub(r'("exec"\s*:\s*)"[^"\n]*"', lambda m: m.group(1) + json.dumps("date +'%s'" % fmt), block, count=1)
    block = re.sub(r'("interval"\s*:\s*)\d+', lambda m: m.group(1) + str(interval), block, count=1)
    text = text[:start] + block + text[end:]
else:
    sys.exit(__doc__)

tmp = path + ".tmp"
with open(tmp, "w") as f:
    f.write(text)
os.replace(tmp, path)
os.environ.get("WAYBAR_CONFIG") or subprocess.run(["pkill", "-SIGUSR2", "-x", "waybar"])
