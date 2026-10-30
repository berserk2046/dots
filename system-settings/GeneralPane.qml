import QtQuick
import Quickshell
import Quickshell.Io
import qs.shared

// General: About, Storage, Date & Time (with the menu bar's calendars) and Login Items, each on its own page.
Column {
    id: pane

    readonly property var titles: ({
            "about": qsTr("About"),
            "storage": qsTr("Storage"),
            "dateTime": qsTr("Date & Time"),
            "loginItems": qsTr("Login Items")
        })
    property string pageTitle: titles[Ui.subpage] ?? ""

    spacing: 10

    // ---- Main page ----

    SettingsGroup {
        visible: Ui.subpage === ""

        SettingRow {
            title: qsTr("About")
            glyph: Theme.iAbout
            tileColor: "#8e8e93"
            chevron: true
            onClicked: Ui.openSub("about")
        }

        SettingRow {
            title: qsTr("Storage")
            glyph: Theme.iDisk
            tileColor: "#8e8e93"
            chevron: true
            onClicked: Ui.openSub("storage")
        }
    }

    SettingsGroup {
        visible: Ui.subpage === ""

        SettingRow {
            title: qsTr("Date & Time")
            glyph: Theme.iClock
            tileColor: "#0a84ff"
            chevron: true
            onClicked: Ui.openSub("dateTime")
        }

        SettingRow {
            title: qsTr("Login Items")
            glyph: Theme.iList
            tileColor: "#8e8e93"
            chevron: true
            onClicked: Ui.openSub("loginItems")
        }
    }

    // ---- About ----

    Loader {
        width: parent.width
        active: Ui.subpage === "about"
        visible: active
        sourceComponent: aboutPage
    }

    Component {
        id: aboutPage

        Column {
            id: about

            property var info: ({})
            property var gpus: []
            property var displays: []

            spacing: 10

            Component.onCompleted: Store.run(["sh", Store.script("about.sh")], (code, out) => {
                const info = {};
                const gpus = [];
                const displays = [];
                for (const line of out.split("\n")) {
                    const i = line.indexOf("=");
                    if (i < 0)
                        continue;
                    const key = line.slice(0, i);
                    const value = line.slice(i + 1).trim();
                    if (key === "gpu")
                        gpus.push(value);
                    else if (key === "display")
                        displays.push(value);
                    else
                        info[key] = value;
                }
                about.info = info;
                about.gpus = gpus;
                about.displays = displays;
            })

            function uptime(seconds) {
                const s = Number(seconds) || 0;
                const days = Math.floor(s / 86400);
                const hours = Math.floor(s % 86400 / 3600);
                const minutes = Math.floor(s % 3600 / 60);
                if (days > 0)
                    return qsTr("%1 d %2 h").arg(days).arg(hours);
                return hours > 0 ? qsTr("%1 h %2 min").arg(hours).arg(minutes) : qsTr("%1 min").arg(minutes);
            }

            Item {
                width: parent.width
                height: 150

                Glyph {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 6
                    text: Theme.iArch
                    size: 78
                    color: "#1793d1"
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 100
                    text: about.info.model ?? ""
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 20
                    font.weight: Font.DemiBold
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 128
                    text: about.info.vendor ?? ""
                    color: Theme.textSecondary
                    font.family: Theme.font
                    font.pixelSize: 12
                }
            }

            SettingsGroup {
                SettingRow {
                    title: qsTr("Name")

                    Field {
                        id: hostField

                        anchors.verticalCenter: parent.verticalCenter
                        width: 200
                        text: about.info.hostname ?? ""
                        onAccepted: {
                            const name = text.trim();
                            if (/^[A-Za-z0-9][A-Za-z0-9-]{0,62}$/.test(name))
                                Store.run(["sh", "-c", 'hostnamectl set-hostname "$1" || sudo -n hostnamectl set-hostname "$1"', "sh", name]);
                        }
                    }
                }

                SettingRow {
                    title: qsTr("Processor")
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: about.info.cpu ?? ""
                        color: Theme.textSecondary
                        font.family: Theme.font
                        font.pixelSize: 12
                    }
                }

                Repeater {
                    model: about.gpus

                    SettingRow {
                        required property string modelData

                        title: qsTr("Graphics")
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(implicitWidth, 380)
                            elide: Text.ElideRight
                            text: modelData
                            color: Theme.textSecondary
                            font.family: Theme.font
                            font.pixelSize: 12
                        }
                    }
                }

                SettingRow {
                    title: qsTr("Memory")
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: about.info.memory ?? ""
                        color: Theme.textSecondary
                        font.family: Theme.font
                        font.pixelSize: 12
                    }
                }

                Repeater {
                    model: about.displays

                    SettingRow {
                        required property string modelData

                        title: qsTr("Display")
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(implicitWidth, 400)
                            elide: Text.ElideRight
                            text: modelData
                            color: Theme.textSecondary
                            font.family: Theme.font
                            font.pixelSize: 12
                        }
                    }
                }
            }

            Caption {
                text: qsTr("Press Enter in the name field to rename this computer (hostnamectl).")
            }

            SettingsGroup {
                Repeater {
                    model: [[qsTr("Operating system"), "os"], [qsTr("Kernel"), "kernel"], [qsTr("Hyprland"), "hyprland"], [qsTr("Quickshell"), "quickshell"]]

                    SettingRow {
                        id: infoRow

                        required property var modelData

                        title: modelData[0]
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: about.info[infoRow.modelData[1]] ?? ""
                            color: Theme.textSecondary
                            font.family: Theme.font
                            font.pixelSize: 12
                        }
                    }
                }

                SettingRow {
                    title: qsTr("Up for")
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: about.uptime(about.info.uptime)
                        color: Theme.textSecondary
                        font.family: Theme.font
                        font.pixelSize: 12
                    }
                }
            }
        }
    }

    // ---- Storage ----

    Loader {
        width: parent.width
        active: Ui.subpage === "storage"
        visible: active
        sourceComponent: storagePage
    }

    Component {
        id: storagePage

        Column {
            spacing: 10

            System {
                id: system

                active: true
                interval: 10000
            }

            SettingsGroup {
                SettingRow {
                    visible: system.disks.length === 0
                    title: system.loaded ? qsTr("No disks found") : qsTr("Calculating…")
                    titleColor: Theme.textSecondary
                }

                Repeater {
                    model: system.disks

                    SettingRow {
                        id: diskRow

                        required property var modelData

                        title: (modelData.model || modelData.device) + "  ·  " + modelData.mount
                        subtitle: qsTr("%1 available of %2  ·  %3").arg(system.bytes(modelData.avail)).arg(system.bytes(modelData.size)).arg(modelData.fstype)
                        glyph: Theme.iDisk
                        tileColor: "#8e8e93"
                        below: Meter {
                            width: parent.width
                            value: diskRow.modelData.size > 0 ? diskRow.modelData.used / diskRow.modelData.size : 0
                            barColor: value > 0.9 ? Theme.danger : Theme.accent
                        }
                    }
                }
            }

            Caption {
                text: qsTr("Bars show the space in use on each mounted disk.")
            }
        }
    }

    // ---- Date & Time ----

    Loader {
        width: parent.width
        active: Ui.subpage === "dateTime"
        visible: active
        sourceComponent: dateTimePage
    }

    Component {
        id: dateTimePage

        Column {
            id: dateTime

            property bool ntp: false
            property string timezone: ""
            property var timezones: []
            property var calendars: [] // {url, color, name}
            property date now: new Date()
            property bool adding: false
            readonly property string calendarFile: Store.home + "/.config/waybar-widgets-calendars.conf"
            readonly property var colors: ["#0a84ff", "#30d158", "#ff9f0a", "#ff453a", "#bf5af2", "#ff375f", "#64d2ff", "#ffd60a"]

            spacing: 10

            function refresh() {
                Store.run(["timedatectl", "show", "-p", "NTP", "-p", "Timezone"], (code, out) => {
                    for (const line of out.split("\n")) {
                        if (line.startsWith("NTP="))
                            dateTime.ntp = line.slice(4) === "yes";
                        else if (line.startsWith("Timezone="))
                            dateTime.timezone = line.slice(9);
                    }
                });
            }

            function loadCalendars() {
                Store.run(["sh", "-c", 'cat "$1" 2>/dev/null', "sh", calendarFile], (code, out) => {
                    const list = [];
                    for (const line of out.split("\n")) {
                        const parts = line.trim().split(/\s+/);
                        if (!parts[0] || parts[0].startsWith("#"))
                            continue;
                        let color = "";
                        let rest = parts.slice(1);
                        if (rest[0]?.startsWith("#")) {
                            color = rest[0];
                            rest = rest.slice(1);
                        }
                        list.push({
                            url: parts[0],
                            color: color,
                            name: rest.join(" ")
                        });
                    }
                    dateTime.calendars = list;
                });
            }

            function saveCalendars(list) {
                calendars = list;
                const text = list.map(c => [c.url, c.color, c.name].filter(x => x).join(" ")).join("\n") + "\n";
                // Private: the addresses give read access to the calendars.
                Store.writeFile(calendarFile, text, ["chmod", "600", calendarFile]);
            }

            Component.onCompleted: {
                refresh();
                loadCalendars();
                Store.run(["timedatectl", "list-timezones"], (code, out) => dateTime.timezones = out.split("\n").filter(z => z));
            }

            Timer {
                interval: 1000
                repeat: true
                running: true
                onTriggered: dateTime.now = new Date()
            }

            SettingsGroup {
                SettingRow {
                    title: qsTr("Set time and date automatically")
                    subtitle: qsTr("From network time servers (systemd-timesyncd)")

                    Toggle {
                        anchors.verticalCenter: parent.verticalCenter
                        checked: dateTime.ntp
                        onToggled: on => {
                            dateTime.ntp = on;
                            Store.runQueued("ntp", ["sh", "-c", 'timedatectl set-ntp "$1" || sudo -n timedatectl set-ntp "$1"', "sh", String(on)], () => dateTime.refresh());
                        }
                    }
                }

                SettingRow {
                    title: qsTr("Date and time")

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: dateTime.now.toLocaleString(Qt.locale(), "dddd, MMMM d, yyyy  h:mm:ss AP")
                        color: Theme.textSecondary
                        font.family: Theme.font
                        font.pixelSize: 12
                    }
                }

                SettingRow {
                    title: qsTr("Time zone")

                    Dropdown {
                        anchors.verticalCenter: parent.verticalCenter
                        options: dateTime.timezones
                        value: dateTime.timezone
                        onPicked: zone => {
                            dateTime.timezone = zone;
                            Store.run(["sh", "-c", 'timedatectl set-timezone "$1" || sudo -n timedatectl set-timezone "$1"', "sh", zone], () => dateTime.refresh());
                        }
                    }
                }

                SettingRow {
                    title: qsTr("Menu bar clock")
                    subtitle: qsTr("24-hour time, seconds and the date are in Control Center")
                    chevron: true
                    onClicked: Ui.open("controlCenter")
                }
            }

            GroupTitle {
                text: qsTr("Calendars")

                TextButton {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Add…")
                    onClicked: {
                        calUrl.text = "";
                        calName.text = "";
                        calColors.picked = dateTime.colors[dateTime.calendars.length % dateTime.colors.length];
                        dateTime.adding = true;
                    }
                }
            }

            SettingsGroup {
                SettingRow {
                    visible: dateTime.calendars.length === 0
                    title: qsTr("No calendars")
                    titleColor: Theme.textSecondary
                }

                Repeater {
                    model: dateTime.calendars

                    SettingRow {
                        id: calRow

                        required property var modelData
                        required property int index

                        title: modelData.name || qsTr("Calendar %1").arg(index + 1)
                        // Only the host: the rest of the address is a secret that gives access to the calendar.
                        subtitle: modelData.url.replace(/^\w+:\/\//, "").split("/")[0]

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 12
                            height: 12
                            radius: 6
                            color: calRow.modelData.color || Theme.accent
                        }

                        TextButton {
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("Remove")
                            onClicked: dateTime.saveCalendars(dateTime.calendars.filter((c, i) => i !== calRow.index))
                        }
                    }
                }
            }

            Caption {
                text: qsTr("Calendars show in the menu bar's date panel and the lock screen's Up Next. Use an iCal address, e.g. Google Calendar → Settings → your calendar → “Secret address in iCal format”.")
            }

            Sheet {
                shown: dateTime.adding
                onDismissed: dateTime.adding = false

                Text {
                    text: qsTr("Add Calendar")
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                }

                Field {
                    id: calUrl

                    width: parent.width
                    placeholder: qsTr("iCal address (https://…ics)")
                }

                Field {
                    id: calName

                    width: parent.width
                    placeholder: qsTr("Name (optional)")
                }

                Row {
                    id: calColors

                    property string picked: dateTime.colors[0]

                    spacing: 8

                    Repeater {
                        model: dateTime.colors

                        Rectangle {
                            required property string modelData

                            width: 22
                            height: 22
                            radius: 11
                            color: modelData
                            border.width: calColors.picked === modelData ? 2 : 0
                            border.color: "#ffffff"

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: calColors.picked = parent.modelData
                            }
                        }
                    }
                }

                Row {
                    anchors.right: parent.right
                    spacing: 8

                    TextButton {
                        text: qsTr("Cancel")
                        onClicked: dateTime.adding = false
                    }

                    TextButton {
                        primary: true
                        text: qsTr("Add")
                        enabled: /^(https?|webcal):\/\/\S+$/.test(calUrl.text.trim())
                        onClicked: {
                            dateTime.saveCalendars([...dateTime.calendars, {
                                    url: calUrl.text.trim().replace(/^webcal:/, "https:"),
                                    color: calColors.picked,
                                    name: calName.text.trim()
                                }]);
                            dateTime.adding = false;
                        }
                    }
                }
            }
        }
    }

    // ---- Login Items ----

    Loader {
        width: parent.width
        active: Ui.subpage === "loginItems"
        visible: active
        sourceComponent: loginItemsPage
    }

    Component {
        id: loginItemsPage

        Column {
            id: login

            readonly property var items: Store.get("general", "loginItems", [])
            property bool adding: false
            readonly property var apps: DesktopEntries.applications.values.filter(e => !e.noDisplay).sort((a, b) => a.name.localeCompare(b.name))

            spacing: 10

            function setItems(list) {
                Store.set("general", "loginItems", list);
            }

            GroupTitle {
                text: qsTr("Open at Login")

                TextButton {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Add…")
                    onClicked: {
                        appPicker.value = undefined;
                        commandField.text = "";
                        login.adding = true;
                    }
                }
            }

            SettingsGroup {
                SettingRow {
                    visible: login.items.length === 0
                    title: qsTr("No login items")
                    titleColor: Theme.textSecondary
                }

                Repeater {
                    model: login.items

                    SettingRow {
                        id: itemRow

                        required property var modelData
                        required property int index
                        readonly property var entry: modelData.app ? DesktopEntries.byId(modelData.app) : null

                        title: modelData.name || modelData.command
                        subtitle: modelData.command
                        iconSource: entry?.icon ? Quickshell.iconPath(entry.icon, true) : ""
                        glyph: Theme.iConsole
                        tileColor: "#48484a"

                        Toggle {
                            anchors.verticalCenter: parent.verticalCenter
                            checked: itemRow.modelData.enabled !== false
                            onToggled: on => login.setItems(login.items.map((item, i) => i === itemRow.index ? Object.assign({}, item, {
                                    enabled: on
                                }) : item))
                        }

                        TextButton {
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("Remove")
                            onClicked: login.setItems(login.items.filter((item, i) => i !== itemRow.index))
                        }
                    }
                }
            }

            Caption {
                text: qsTr("These start with Hyprland, after the menu bar, Dock and lock screen. Changes apply at the next login.")
            }

            Sheet {
                shown: login.adding
                onDismissed: login.adding = false

                Text {
                    text: qsTr("Add Login Item")
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                }

                Dropdown {
                    id: appPicker

                    width: parent.width
                    placeholder: qsTr("Choose an app…")
                    options: login.apps.map(e => ({
                                label: e.name,
                                value: e.id
                            }))
                    onPicked: id => {
                        value = id;
                        const entry = DesktopEntries.byId(id);
                        commandField.text = (entry?.command ?? []).filter(a => !/^%[a-zA-Z]$/.test(a)).map(a => /[\s"'$`\\]/.test(a) ? "'" + a.replace(/'/g, "'\\''") + "'" : a).join(" ");
                    }
                }

                Field {
                    id: commandField

                    width: parent.width
                    placeholder: qsTr("Or a command, e.g. nm-applet --indicator")
                }

                Row {
                    anchors.right: parent.right
                    spacing: 8

                    TextButton {
                        text: qsTr("Cancel")
                        onClicked: login.adding = false
                    }

                    TextButton {
                        primary: true
                        text: qsTr("Add")
                        enabled: commandField.text.trim() !== ""
                        onClicked: {
                            const entry = appPicker.value ? DesktopEntries.byId(appPicker.value) : null;
                            login.setItems([...login.items, {
                                    name: entry?.name ?? commandField.text.trim().split(/\s+/)[0],
                                    app: entry?.id ?? "",
                                    command: commandField.text.trim(),
                                    enabled: true
                                }]);
                            login.adding = false;
                        }
                    }
                }
            }
        }
    }
}
