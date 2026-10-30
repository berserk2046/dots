import QtQuick
import Quickshell
import Quickshell.Io

// Events from the iCal calendars in ~/.config/waybar-widgets-calendars.conf (see calendar-sync.py).
// Syncs when the date panel opens (the script reuses downloads younger than 10 minutes) and every
// 10 minutes while it stays open.
Scope {
    id: cals

    property bool active: false

    property bool configured: false
    property var calendars: [] // {name, color, error, count}
    property var events: [] // {calendar, title, location, start: Date, end: Date, allDay, color}
    property bool syncing: false
    property bool syncedOnce: false

    onActiveChanged: {
        if (active)
            sync(false);
    }

    Timer {
        interval: 600000
        repeat: true
        running: cals.active
        onTriggered: cals.sync(false)
    }

    Process {
        id: proc

        stdout: StdioCollector {
            onStreamFinished: {
                cals.syncing = false;
                cals.syncedOnce = true;
                try {
                    cals.apply(JSON.parse(text));
                } catch (e) {
                    console.warn("calendar-sync:", e);
                }
            }
        }
    }

    function sync(force) {
        if (syncing)
            return;
        syncing = true;
        proc.command = ["python3", Quickshell.shellDir + "/calendar-sync.py", ...(force ? ["--force"] : [])];
        proc.running = true;
    }

    function apply(data) {
        configured = data.configured;
        calendars = data.calendars;
        events = data.events.map(e => {
            let start = new Date(e.start);
            let end = new Date(e.end);
            if (e.allDay) {
                // Use the calendar date itself so all-day events don't shift with time zones.
                const [y, m, d] = e.day.split("-").map(Number);
                start = new Date(y, m - 1, d);
                end = new Date(y, m - 1, d + e.days);
            }
            return {
                calendar: e.calendar,
                title: e.title,
                location: e.location,
                start: start,
                end: end,
                allDay: e.allDay,
                color: data.calendars[e.calendar]?.color ?? Theme.accent
            };
        });
    }

    // Events touching the given day, all-day ones first, then by start time.
    function eventsOn(day) {
        const from = new Date(day.getFullYear(), day.getMonth(), day.getDate());
        const to = new Date(day.getFullYear(), day.getMonth(), day.getDate() + 1);
        return events.filter(e => e.start < to && (e.end > from || (+e.end === +e.start && e.start >= from)))
            .sort((a, b) => (b.allDay - a.allDay) || (a.start - b.start));
    }

    function timeRange(e) {
        if (e.allDay)
            return qsTr("All day");
        const fmt = d => Qt.formatTime(d, "h:mm AP");
        return +e.end === +e.start ? fmt(e.start) : fmt(e.start) + " – " + fmt(e.end);
    }
}
