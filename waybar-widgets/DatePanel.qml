import QtQuick
import Quickshell

// Clock and calendar in the style of macOS: a month view like the Notification Center widget
// (today in a red circle, event dots) and a week view like Calendar.app (hour grid, event blocks,
// red now line). Arrows, Today or the scroll wheel move through months/weeks; click a day to list
// its events below.
Column {
    id: panel

    required property Calendars cals
    property bool shown: false

    readonly property color red: "#ff453a"
    readonly property var locale: Qt.locale()
    readonly property date now: clock.date
    readonly property date today: new Date(now.getFullYear(), now.getMonth(), now.getDate())

    property string view: "month" // or "week"
    // Month on screen (its first day), week on screen (its first day) and the clicked day.
    property date month: new Date(today.getFullYear(), today.getMonth(), 1)
    property date week: startOfWeek(today)
    property date selected: today

    readonly property int hourHeight: 34
    readonly property var weekDays: [0, 1, 2, 3, 4, 5, 6].map(i => addDays(week, i))
    readonly property var selectedEvents: cals.events, cals.eventsOn(selected)

    width: parent?.width ?? 0
    spacing: 2

    onShownChanged: {
        if (shown)
            goToday();
    }

    SystemClock {
        id: clock

        precision: SystemClock.Seconds
    }

    function addDays(d, n) {
        return new Date(d.getFullYear(), d.getMonth(), d.getDate() + n);
    }

    function sameDay(a, b) {
        return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
    }

    function startOfWeek(d) {
        return addDays(d, -((d.getDay() - locale.firstDayOfWeek + 7) % 7)); // firstDayOfWeek: 0 = Sunday
    }

    function goToday() {
        month = new Date(today.getFullYear(), today.getMonth(), 1);
        week = startOfWeek(today);
        selected = today;
    }

    function step(delta) {
        if (view === "month") {
            month = new Date(month.getFullYear(), month.getMonth() + delta, 1);
        } else {
            week = addDays(week, 7 * delta);
            selected = addDays(selected, 7 * delta);
        }
    }

    function select(d) {
        selected = d;
        week = startOfWeek(d);
        if (d.getMonth() !== month.getMonth() || d.getFullYear() !== month.getFullYear())
            month = new Date(d.getFullYear(), d.getMonth(), 1);
    }

    // 6 weeks of dates starting on the locale's first day of the week.
    function gridDays(first) {
        const start = startOfWeek(first);
        return Array.from({
            length: 42
        }, (_, i) => addDays(start, i));
    }

    // ISO 8601 week number.
    function weekNumber(d) {
        const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
        const day = t.getUTCDay() || 7;
        t.setUTCDate(t.getUTCDate() + 4 - day);
        const yearStart = new Date(Date.UTC(t.getUTCFullYear(), 0, 1));
        return Math.ceil(((t - yearStart) / 86400000 + 1) / 7);
    }

    function dayOfYear(d) {
        return Math.round((addDays(d, 0) - new Date(d.getFullYear(), 0, 1)) / 86400000) + 1;
    }

    function relative(d) {
        const days = Math.round((d - today) / 86400000);
        if (days === 0)
            return qsTr("Today");
        if (days === 1)
            return qsTr("Tomorrow");
        if (days === -1)
            return qsTr("Yesterday");
        return days > 0 ? qsTr("In %1 days").arg(days) : qsTr("%1 days ago").arg(-days);
    }

    function title() {
        if (view === "month")
            return locale.toString(month, "MMMM").toUpperCase() + (month.getFullYear() !== today.getFullYear() ? "  " + month.getFullYear() : "");
        const last = addDays(week, 6);
        const first = locale.toString(week, "MMM d").toUpperCase();
        return first + " – " + (last.getMonth() === week.getMonth() ? last.getDate() : locale.toString(last, "MMM d").toUpperCase());
    }

    // Timed events of one day, clipped to it, with side-by-side lanes for overlaps: {event, top, height, lane, lanes}.
    function dayLayout(day) {
        const from = addDays(day, 0);
        const to = addDays(day, 1);
        const items = cals.eventsOn(day).filter(e => !e.allDay).map(e => {
            const s = Math.max(e.start, from);
            const en = Math.min(Math.max(+e.end, +e.start + 15 * 60000), +to);
            return {
                event: e,
                startMin: (s - from) / 60000,
                endMin: (en - from) / 60000,
                lane: 0,
                lanes: 1
            };
        }).sort((a, b) => a.startMin - b.startMin);
        let cluster = [];
        let clusterEnd = -1;
        const finish = () => {
            const lanes = Math.max(1, ...cluster.map(i => i.lane + 1));
            cluster.forEach(i => i.lanes = lanes);
        };
        for (const item of items) {
            if (item.startMin >= clusterEnd && cluster.length) {
                finish();
                cluster = [];
            }
            const used = cluster.filter(i => i.endMin > item.startMin).map(i => i.lane);
            let lane = 0;
            while (used.includes(lane))
                lane++;
            item.lane = lane;
            cluster.push(item);
            clusterEnd = Math.max(clusterEnd, item.endMin);
        }
        if (cluster.length)
            finish();
        return items;
    }

    component NavButton: Rectangle {
        id: nav

        property string glyph
        property string label
        signal clicked

        width: label ? labelText.implicitWidth + 14 : 24
        height: 24
        radius: 6
        color: navMouse.pressed ? Theme.pressed : navMouse.containsMouse ? Theme.hover : "transparent"

        Glyph {
            anchors.centerIn: parent
            visible: nav.glyph !== ""
            text: nav.glyph
            size: 16
            color: Theme.textSecondary
        }

        Text {
            id: labelText

            anchors.centerIn: parent
            visible: nav.label !== ""
            text: nav.label
            color: Theme.textSecondary
            font.family: Theme.font
            font.pixelSize: Theme.fontSize(12)
        }

        MouseArea {
            id: navMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: nav.clicked()
        }
    }

    // Day number with today's red circle and the selection ring.
    component DayNumber: Item {
        id: dn

        property date date
        property bool dim: false
        property real circle: 26

        readonly property bool isToday: panel.sameDay(date, panel.today)
        readonly property bool isSelected: panel.sameDay(date, panel.selected)
        readonly property bool weekend: date.getDay() === 0 || date.getDay() === 6

        Rectangle {
            anchors.centerIn: parent
            width: dn.circle
            height: dn.circle
            radius: dn.circle / 2
            color: dn.isToday ? panel.red : dnMouse.containsMouse ? Theme.hover : "transparent"
            border.width: dn.isSelected && !dn.isToday ? 1.5 : 0
            border.color: Theme.textSecondary
        }

        Text {
            anchors.centerIn: parent
            text: dn.date.getDate()
            color: dn.isToday ? "#ffffff" : dn.dim ? (Theme.light ? Qt.rgba(0, 0, 0, 0.2) : Qt.rgba(1, 1, 1, 0.2)) : dn.weekend ? Theme.textSecondary : Theme.text
            font.family: Theme.font
            font.pixelSize: Theme.fontSize(13)
            font.weight: dn.isToday ? Font.Bold : Font.Normal
            font.features: {
                "tnum": 1
            }
        }

        MouseArea {
            id: dnMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: panel.select(dn.date)
        }
    }

    // ---- Clock ----

    Item {
        width: parent.width
        height: 74

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter

            Row {
                spacing: 6

                Text {
                    id: timeText

                    // "h" is only 12-hour when the same format has "AP".
                    text: Qt.formatTime(panel.now, "h:mm AP").split(" ")[0]
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize(38)
                    font.weight: Font.Light
                    font.features: {
                        "tnum": 1
                    }
                }

                Text {
                    anchors.baseline: timeText.baseline
                    text: Qt.formatTime(panel.now, "AP")
                    color: Theme.textSecondary
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize(16)
                    font.weight: Font.Medium
                }
            }

            Text {
                text: panel.locale.toString(panel.now, "dddd, MMMM d, yyyy")
                color: Theme.textSecondary
                font.family: Theme.font
                font.pixelSize: Theme.fontSize(13)
            }
        }
    }

    Separator {}

    Segmented {
        x: 8
        width: parent.width - 16
        options: [qsTr("Month"), qsTr("Week")]
        current: panel.view === "week" ? 1 : 0
        onPicked: index => {
            panel.view = index === 1 ? "week" : "month";
            panel.select(panel.selected);
        }
    }

    // ---- Title and navigation ----

    Item {
        width: parent.width
        height: 32

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: panel.title()
            color: panel.red
            font.family: Theme.font
            font.pixelSize: Theme.fontSize(13)
            font.weight: Font.Bold
            font.letterSpacing: 0.4
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            NavButton {
                glyph: Theme.iChevronLeft
                onClicked: panel.step(-1)
            }
            NavButton {
                label: qsTr("Today")
                opacity: panel.sameDay(panel.selected, panel.today) && (panel.view === "week"
                         ? panel.sameDay(panel.week, panel.startOfWeek(panel.today))
                         : panel.month.getMonth() === panel.today.getMonth() && panel.month.getFullYear() === panel.today.getFullYear()) ? 0.4 : 1
                onClicked: panel.goToday()
            }
            NavButton {
                glyph: Theme.iChevronRight
                onClicked: panel.step(1)
            }
        }
    }

    // Weekday initials, shared by both views (the week view indents them past the hour labels).
    Row {
        id: weekdays

        readonly property real gutter: panel.view === "week" ? 34 : 0

        x: 4 + gutter
        width: parent.width - 8 - gutter
        height: 20

        Repeater {
            model: 7

            Text {
                required property int index

                width: weekdays.width / 7
                horizontalAlignment: Text.AlignHCenter
                text: panel.locale.dayName((panel.locale.firstDayOfWeek + index) % 7, Locale.NarrowFormat)
                color: Theme.textTertiary
                font.family: Theme.font
                font.pixelSize: Theme.fontSize(11)
                font.weight: Font.DemiBold
            }
        }
    }

    // ---- Month ----

    Item {
        id: monthView

        readonly property real cell: width / 7

        visible: panel.view === "month"
        x: 4
        width: parent.width - 8
        height: cell * 6 * 0.9

        WheelHandler {
            onWheel: event => panel.step(event.angleDelta.y > 0 ? -1 : 1)
        }

        Grid {
            columns: 7

            Repeater {
                model: panel.gridDays(panel.month)

                Item {
                    id: cellItem

                    required property date modelData
                    // Distinct calendar colors with events that day, for the dots.
                    readonly property var dots: (panel.cals.events, [...new Set(panel.cals.eventsOn(modelData).map(e => String(e.color)))].slice(0, 3))

                    width: monthView.cell
                    height: monthView.cell * 0.9

                    DayNumber {
                        anchors.fill: parent
                        anchors.bottomMargin: 4
                        date: cellItem.modelData
                        dim: cellItem.modelData.getMonth() !== panel.month.getMonth()
                        circle: Math.min(width, height) - 8
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 1
                        spacing: 2

                        Repeater {
                            model: cellItem.dots

                            Rectangle {
                                required property string modelData

                                width: 4
                                height: 4
                                radius: 2
                                color: modelData
                                opacity: cellItem.modelData.getMonth() === panel.month.getMonth() ? 1 : 0.35
                            }
                        }
                    }
                }
            }
        }
    }

    // ---- Week ----

    Column {
        id: weekView

        readonly property real gutter: 34
        readonly property real column: (width - gutter) / 7
        readonly property bool hasAllDay: panel.weekDays.some(d => panel.cals.eventsOn(d).some(e => e.allDay))

        visible: panel.view === "week"
        x: 4
        width: parent.width - 8
        spacing: 4

        // Dates
        Row {
            x: weekView.gutter
            height: 30

            Repeater {
                model: panel.weekDays

                DayNumber {
                    required property date modelData

                    width: weekView.column
                    height: 30
                    date: modelData
                    circle: 26
                }
            }
        }

        // All-day events
        Row {
            visible: weekView.hasAllDay
            height: visible ? 20 : 0

            Text {
                width: weekView.gutter
                height: 20
                verticalAlignment: Text.AlignVCenter
                text: qsTr("all-day")
                color: Theme.textTertiary
                font.family: Theme.font
                font.pixelSize: Theme.fontSize(9)
            }

            Repeater {
                model: panel.weekDays

                Item {
                    id: allDayCell

                    required property date modelData
                    readonly property var items: (panel.cals.events, panel.cals.eventsOn(modelData).filter(e => e.allDay))

                    width: weekView.column
                    height: 20

                    Rectangle {
                        visible: allDayCell.items.length > 0
                        anchors.fill: parent
                        anchors.margins: 1
                        radius: 4
                        color: Qt.rgba(Qt.color(allDayCell.items[0]?.color ?? Theme.accent).r, Qt.color(allDayCell.items[0]?.color ?? Theme.accent).g,
                                       Qt.color(allDayCell.items[0]?.color ?? Theme.accent).b, 0.35)

                        Text {
                            anchors.fill: parent
                            anchors.leftMargin: 3
                            anchors.rightMargin: 2
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                            text: (allDayCell.items.length > 1 ? allDayCell.items.length + " · " : "") + (allDayCell.items[0]?.title ?? "")
                            color: Theme.text
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize(9)
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: panel.select(allDayCell.modelData)
                        }
                    }
                }
            }
        }

        // Hour grid
        Flickable {
            id: grid

            width: parent.width
            height: panel.hourHeight * 9.5
            contentHeight: panel.hourHeight * 24
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            // Open at the selected day's first event or two hours before now, whichever is earlier
            // (8 AM when neither applies).
            function scrollToStart() {
                const first = panel.cals.eventsOn(panel.selected).find(e => !e.allDay && panel.sameDay(e.start, panel.selected));
                const hours = [];
                if (first)
                    hours.push(first.start.getHours() + first.start.getMinutes() / 60 - 0.5);
                if (panel.sameDay(panel.selected, panel.today))
                    hours.push(panel.now.getHours() - 2);
                const hour = hours.length ? Math.min(...hours) : 8;
                contentY = Math.max(0, Math.min(contentHeight - height, hour * panel.hourHeight));
                autoY = contentY;
            }

            // Where scrollToStart left it; a sync only re-scrolls if the grid hasn't been moved since.
            property real autoY: -1

            Connections {
                target: panel.cals

                function onEventsChanged() {
                    if (grid.contentY === grid.autoY)
                        grid.scrollToStart();
                }
            }

            Connections {
                target: panel

                function onWeekChanged() {
                    grid.scrollToStart();
                }

                function onViewChanged() {
                    grid.scrollToStart();
                }

                function onShownChanged() {
                    grid.scrollToStart();
                }

                function onSelectedChanged() {
                    grid.scrollToStart();
                }
            }

            Item {
                width: grid.width
                height: grid.contentHeight

                // Hour lines and labels
                Repeater {
                    model: 24

                    Item {
                        required property int index

                        y: index * panel.hourHeight
                        width: parent.width
                        height: panel.hourHeight

                        Text {
                            visible: parent.index > 0
                            width: weekView.gutter - 6
                            y: -height / 2
                            horizontalAlignment: Text.AlignRight
                            text: Qt.formatTime(new Date(2000, 0, 1, parent.index), "h AP")
                            color: Theme.textTertiary
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize(9)
                        }

                        Rectangle {
                            x: weekView.gutter
                            width: parent.width - weekView.gutter
                            height: 1
                            color: Theme.separator
                        }
                    }
                }

                // Day columns with events
                Repeater {
                    model: panel.weekDays

                    Item {
                        id: dayColumn

                        required property date modelData
                        required property int index
                        readonly property bool isToday: panel.sameDay(modelData, panel.today)

                        x: weekView.gutter + index * weekView.column
                        width: weekView.column
                        height: parent.height

                        Rectangle {
                            anchors.fill: parent
                            color: dayColumn.isToday ? (Theme.light ? "#0a000000" : "#0dffffff") : "transparent"
                        }

                        Rectangle {
                            width: 1
                            height: parent.height
                            color: Theme.separator
                        }

                        Repeater {
                            model: (panel.cals.events, panel.dayLayout(dayColumn.modelData))

                            Rectangle {
                                id: block

                                required property var modelData
                                readonly property color tint: Qt.color(modelData.event.color)

                                x: 1 + (dayColumn.width - 2) * modelData.lane / modelData.lanes
                                y: modelData.startMin / 60 * panel.hourHeight + 1
                                width: (dayColumn.width - 2) / modelData.lanes - 1
                                height: Math.max(12, (modelData.endMin - modelData.startMin) / 60 * panel.hourHeight - 2)
                                radius: 3
                                color: Qt.rgba(tint.r, tint.g, tint.b, blockMouse.containsMouse ? 0.5 : 0.35)
                                clip: true

                                Rectangle {
                                    width: 2
                                    height: parent.height
                                    color: block.tint
                                }

                                Text {
                                    x: 4
                                    y: 1
                                    width: parent.width - 5
                                    height: parent.height - 2
                                    wrapMode: Text.WordWrap
                                    elide: Text.ElideRight
                                    text: block.modelData.event.title
                                    color: Theme.text
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize(9)
                                    font.weight: Font.Medium
                                    lineHeight: 0.95
                                }

                                MouseArea {
                                    id: blockMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: panel.select(dayColumn.modelData)
                                }
                            }
                        }

                        // Current time: red line with a dot, like Calendar.app.
                        Item {
                            visible: dayColumn.isToday
                            y: (panel.now.getHours() * 60 + panel.now.getMinutes()) / 60 * panel.hourHeight
                            width: parent.width
                            z: 2

                            Rectangle {
                                width: parent.width
                                height: 1.5
                                color: panel.red
                            }

                            Rectangle {
                                x: -3
                                y: -2.5
                                width: 6
                                height: 6
                                radius: 3
                                color: panel.red
                            }
                        }
                    }
                }
            }
        }
    }

    Separator {}

    // ---- Selected day and its events ----

    Item {
        width: parent.width
        height: 40

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                text: panel.locale.toString(panel.selected, "dddd, MMMM d")
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: Theme.fontSize(13)
                font.weight: Font.DemiBold
            }

            Text {
                text: qsTr("Week %1  ·  Day %2").arg(panel.weekNumber(panel.selected)).arg(panel.dayOfYear(panel.selected))
                color: Theme.textSecondary
                font.family: Theme.font
                font.pixelSize: Theme.fontSize(11)
            }
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Spinner {
                anchors.verticalCenter: parent.verticalCenter
                running: panel.cals.syncing
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: panel.relative(panel.selected)
                color: panel.sameDay(panel.selected, panel.today) ? panel.red : Theme.textSecondary
                font.family: Theme.font
                font.pixelSize: Theme.fontSize(12)
                font.weight: Font.Medium
            }
        }
    }

    Repeater {
        model: panel.selectedEvents.slice(0, 6)

        Item {
            id: eventRow

            required property var modelData

            width: panel.width
            height: 36

            Rectangle {
                x: 10
                anchors.verticalCenter: parent.verticalCenter
                width: 3
                height: 26
                radius: 1.5
                color: eventRow.modelData.color
            }

            Column {
                x: 22
                width: parent.width - 30
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: eventRow.modelData.title
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize(13)
                }

                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: [panel.cals.timeRange(eventRow.modelData), eventRow.modelData.location].filter(x => x).join("  ·  ")
                    color: Theme.textSecondary
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize(11)
                }
            }
        }
    }

    Text {
        x: 8
        height: 24
        visible: panel.selectedEvents.length > 6
        verticalAlignment: Text.AlignVCenter
        text: qsTr("%n more event(s)", "", panel.selectedEvents.length - 6)
        color: Theme.textTertiary
        font.family: Theme.font
        font.pixelSize: Theme.fontSize(11)
    }

    Text {
        x: 8
        width: parent.width - 16
        height: implicitHeight + 8
        visible: panel.selectedEvents.length === 0
        wrapMode: Text.WordWrap
        text: !panel.cals.configured && panel.cals.syncedOnce
              ? qsTr("No calendars connected. Add an iCal link to ~/.config/waybar-widgets-calendars.conf")
              : qsTr("No Events")
        color: Theme.textTertiary
        font.family: Theme.font
        font.pixelSize: Theme.fontSize(12)
    }

    Repeater {
        model: panel.cals.calendars.filter(c => c.error && c.count === 0)

        Text {
            required property var modelData

            x: 8
            width: panel.width - 16
            elide: Text.ElideRight
            text: qsTr("Couldn't load %1").arg(modelData.name)
            color: Theme.danger
            font.family: Theme.font
            font.pixelSize: Theme.fontSize(11)
        }
    }
}
