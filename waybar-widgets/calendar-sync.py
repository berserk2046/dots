#!/usr/bin/env python3
"""Fetches iCal (.ics) calendars and prints their events as JSON for Calendars.qml.

Calendars are listed one per line in ~/.config/waybar-widgets-calendars.conf:

    <ics url> [#rrggbb] [name]

e.g. Google Calendar's "Secret address in iCal format". Downloads are cached in
~/.cache/waybar-widgets/calendars (private, mode 600) and reused for 10 minutes, or when offline.
Repeating events are expanded with python-dateutil.

Usage: calendar-sync.py [--force] [--days-back N] [--days-ahead N]
"""

import datetime as dt
import hashlib
import json
import os
import re
import sys
import time
import urllib.request
import zoneinfo

try:
    from dateutil import rrule
except ImportError:  # repeating events then only show their first occurrence
    rrule = None

CONFIG = os.path.expanduser(
    os.path.join(os.environ.get("XDG_CONFIG_HOME", "~/.config"), "waybar-widgets-calendars.conf"))
CACHE = os.path.expanduser(
    os.path.join(os.environ.get("XDG_CACHE_HOME", "~/.cache"), "waybar-widgets", "calendars"))
MAX_AGE = 600
# macOS Calendar's default colors, used in order for calendars without one.
PALETTE = ["#0a84ff", "#30d158", "#ff9f0a", "#bf5af2", "#ff453a", "#ffd60a", "#ac8e68", "#64d2ff"]
LOCAL = dt.datetime.now().astimezone().tzinfo


def read_config():
    calendars = []
    try:
        with open(CONFIG) as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                url, *rest = line.split()
                color = rest.pop(0) if rest and re.fullmatch(r"#[0-9a-fA-F]{6}", rest[0]) else None
                name = " ".join(rest) or None
                calendars.append({"url": url, "color": color, "name": name})
    except FileNotFoundError:
        pass
    return calendars


def fetch(url, force):
    """Returns (ics text, error). Falls back to the cached copy when the download fails."""
    os.makedirs(CACHE, mode=0o700, exist_ok=True)
    path = os.path.join(CACHE, hashlib.sha256(url.encode()).hexdigest() + ".ics")
    fresh = os.path.exists(path) and time.time() - os.path.getmtime(path) < MAX_AGE
    error = None
    if force or not fresh:
        try:
            req = urllib.request.Request(url.replace("webcal://", "https://", 1),
                                         headers={"User-Agent": "waybar-widgets"})
            with urllib.request.urlopen(req, timeout=15) as resp:
                data = resp.read()
            fd = os.open(path + ".tmp", os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
            with os.fdopen(fd, "wb") as f:
                f.write(data)
            os.replace(path + ".tmp", path)
        except Exception as e:  # offline, bad URL...: use the cache if there is one
            error = str(e)
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            return f.read(), error
    except FileNotFoundError:
        return None, error or "not downloaded yet"


def unfold(text):
    return re.sub(r"\r?\n[ \t]", "", text).splitlines()


def unescape(value):
    return re.sub(r"\\([\\;,nN])", lambda m: "\n" if m.group(1) in "nN" else m.group(1), value)


def parse_line(line):
    """'NAME;P=V;...:value' -> (NAME, {P: V}, value)"""
    head, _, value = line.partition(":")
    # A colon inside a quoted parameter belongs to the head.
    while head.count('"') % 2:
        more, _, value = value.partition(":")
        head += ":" + more
    name, *params = head.split(";")
    return name.upper(), dict(p.split("=", 1) for p in params if "=" in p), value


def parse_time(value, params):
    """Returns (datetime aware, all_day)."""
    value = value.strip()
    if params.get("VALUE") == "DATE" or re.fullmatch(r"\d{8}", value):
        d = dt.datetime.strptime(value[:8], "%Y%m%d")
        return d.replace(tzinfo=LOCAL), True
    utc = value.endswith("Z")
    d = dt.datetime.strptime(value.rstrip("Z")[:15], "%Y%m%dT%H%M%S")
    if utc:
        return d.replace(tzinfo=dt.timezone.utc), False
    tzid = params.get("TZID", "").strip('"')
    try:
        return d.replace(tzinfo=zoneinfo.ZoneInfo(tzid)), False
    except Exception:  # floating time or a non-IANA TZID
        return d.replace(tzinfo=LOCAL), False


def parse_duration(value):
    m = re.fullmatch(r"([+-])?P(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?", value.strip())
    if not m:
        return None
    sign, w, d, h, mi, s = m.groups()
    delta = dt.timedelta(weeks=int(w or 0), days=int(d or 0), hours=int(h or 0), minutes=int(mi or 0),
                         seconds=int(s or 0))
    return -delta if sign == "-" else delta


def parse_events(text):
    events, current = [], None
    calendar_name = None
    for line in unfold(text):
        if line == "BEGIN:VEVENT":
            current = {"exdates": [], "rdates": []}
        elif line == "END:VEVENT":
            if current and "start" in current:
                events.append(current)
            current = None
        elif current is None:
            if line.startswith("X-WR-CALNAME:"):
                calendar_name = unescape(line.split(":", 1)[1])
        else:
            name, params, value = parse_line(line)
            if name == "DTSTART":
                current["start"], current["all_day"] = parse_time(value, params)
            elif name == "DTEND":
                current["end"], _ = parse_time(value, params)
            elif name == "DURATION":
                current["duration"] = parse_duration(value)
            elif name in ("SUMMARY", "LOCATION", "UID", "STATUS"):
                current[name.lower()] = unescape(value)
            elif name == "RRULE":
                current["rrule"] = value
            elif name == "EXDATE":
                current["exdates"] += [parse_time(v, params)[0] for v in value.split(",")]
            elif name == "RDATE":
                current["rdates"] += [parse_time(v, params)[0] for v in value.split(",")]
            elif name == "RECURRENCE-ID":
                current["recurrence_id"], _ = parse_time(value, params)
    return calendar_name, events


def occurrences(event, start, end):
    """Start times of the event within [start, end)."""
    first = event["start"]
    if not event.get("rrule") or rrule is None:
        times = [first] + event["rdates"]
    else:
        rules = rrule.rruleset()
        try:
            rule_text = event["rrule"]
            # dateutil wants UNTIL in the same awareness as DTSTART; all of ours are aware.
            rule_text = re.sub(r"UNTIL=(\d{8})(;|$)", r"UNTIL=\1T235959Z\2", rule_text)
            rule_text = re.sub(r"UNTIL=(\d{8}T\d{6})(;|$)", r"UNTIL=\1Z\2", rule_text)
            rules.rrule(rrule.rrulestr(rule_text, dtstart=first))
        except Exception:
            return [first] if start <= first < end else []
        for d in event["rdates"]:
            rules.rdate(d)
        for d in event["exdates"]:
            rules.exdate(d)
        times = rules.between(start - dt.timedelta(days=1), end, inc=True)
    return [t for t in times if t < end]


def main():
    args = sys.argv[1:]
    force = "--force" in args

    def number(flag, default):
        return int(args[args.index(flag) + 1]) if flag in args else default

    today = dt.datetime.now(LOCAL).replace(hour=0, minute=0, second=0, microsecond=0)
    window_start = today - dt.timedelta(days=number("--days-back", 45))
    window_end = today + dt.timedelta(days=number("--days-ahead", 90))

    calendars_out, events_out = [], []
    for index, cal in enumerate(read_config()):
        text, error = fetch(cal["url"], force)
        name, events = parse_events(text) if text else (None, [])
        color = cal["color"] or PALETTE[index % len(PALETTE)]
        calendars_out.append({"name": cal["name"] or name or "Calendar %d" % (index + 1), "color": color,
                              "error": error, "count": len(events)})

        # Edited instances of a repeating event replace the generated occurrence.
        overridden = {(e.get("uid"), e["recurrence_id"]) for e in events if "recurrence_id" in e}
        for e in events:
            if e.get("status", "").upper() == "CANCELLED":
                continue
            if "end" in e:
                length = e["end"] - e["start"]
            elif e.get("duration") is not None:
                length = e["duration"]
            else:
                length = dt.timedelta(days=1) if e["all_day"] else dt.timedelta(0)
            for start in occurrences(e, window_start, window_end):
                if "recurrence_id" not in e and (e.get("uid"), start) in overridden:
                    continue
                end = start + length
                if end < window_start and start < window_start:
                    continue
                events_out.append({
                    "calendar": index,
                    "title": e.get("summary") or "(No title)",
                    "location": e.get("location", ""),
                    "start": int(start.timestamp() * 1000),
                    "end": int(end.timestamp() * 1000),
                    # All-day dates are local calendar days; give QML the date itself.
                    "allDay": e["all_day"],
                    "day": start.strftime("%Y-%m-%d") if e["all_day"] else "",
                    "days": max(1, length.days) if e["all_day"] else 0,
                })

    events_out.sort(key=lambda e: (e["start"], not e["allDay"]))
    json.dump({"configured": os.path.exists(CONFIG), "calendars": calendars_out, "events": events_out,
               "dateutil": rrule is not None}, sys.stdout)


if __name__ == "__main__":
    main()
