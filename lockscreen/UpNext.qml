import QtQuick

// macOS "Up Next" calendar widget: the next (or current) event with its calendar color.
Rectangle {
    id: card

    // {title, location, start: Date, end: Date, allDay, color} or null
    property var event: null

    function when(e) {
        const now = new Date();
        const fmt = d => Qt.formatTime(d, "h:mm AP");
        if (e.start <= now)
            return e.allDay ? qsTr("Today") : qsTr("Now · until %1").arg(fmt(e.end));
        const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        const days = Math.floor((new Date(e.start.getFullYear(), e.start.getMonth(), e.start.getDate()) - today) / 86400000);
        const day = days === 0 ? qsTr("Today") : days === 1 ? qsTr("Tomorrow") : Qt.formatDate(e.start, "dddd");
        if (e.allDay)
            return day;
        const range = +e.end === +e.start ? fmt(e.start) : fmt(e.start) + " – " + fmt(e.end);
        return days === 0 ? range : day + ", " + range;
    }

    visible: event !== null
    width: 380
    height: column.implicitHeight + 24
    radius: 20
    color: Qt.rgba(1, 1, 1, 0.16)

    Rectangle {
        id: bar

        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.top: column.top
        anchors.bottom: column.bottom
        width: 4
        radius: 2
        color: card.event?.color ?? Theme.accent
    }

    Column {
        id: column

        anchors.left: bar.right
        anchors.leftMargin: 10
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Text {
            text: qsTr("UP NEXT")
            color: Theme.textSecondary
            font.family: Theme.font
            font.pixelSize: 11
            font.weight: Font.DemiBold
            font.letterSpacing: 0.5
        }

        Text {
            width: parent.width
            text: card.event?.title ?? ""
            elide: Text.ElideRight
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 14
            font.weight: Font.DemiBold
        }

        Text {
            width: parent.width
            text: card.event ? card.when(card.event) + (card.event.location ? " · " + card.event.location : "") : ""
            elide: Text.ElideRight
            color: Theme.textSecondary
            font.family: Theme.font
            font.pixelSize: 13
        }
    }
}
