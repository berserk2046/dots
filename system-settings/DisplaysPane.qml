import QtQuick
import qs.shared

// Displays: arrange monitors by dragging them, then pick resolution, refresh rate, scale, rotation,
// mirroring and the main display. Changes apply live through `hyprctl eval` and revert after 15
// seconds unless kept (as on macOS); kept ones are saved for hyprland.lua. Also brightness and
// Night Shift (hyprsunset).
Column {
    id: pane

    property string pageTitle: ""
    property var monitors: [] // from `hyprctl monitors all -j`
    property var applied: ({}) // name -> spec now in effect
    property var draft: ({}) // name -> spec being edited
    property string selected: ""
    property int countdown: 0
    property real brightness: -1
    readonly property var night: Store.get("displays", "nightShift", {})
    readonly property var names: monitors.map(m => m.name)
    readonly property var current: draft[selected] ?? null
    readonly property var currentInfo: monitors.find(m => m.name === selected) ?? null
    readonly property bool changed: JSON.stringify(draft) !== JSON.stringify(applied)

    spacing: 10

    Component.onCompleted: {
        refresh();
        Store.run(["brightnessctl", "-m", "info"], (code, out) => {
            const percent = parseInt(out.split(",")[3]);
            pane.brightness = isNaN(percent) ? -1 : percent / 100;
        });
    }

    function refresh() {
        Store.run(["hyprctl", "monitors", "all", "-j"], (code, out) => {
            try {
                const list = JSON.parse(out);
                const specs = {};
                for (const m of list)
                    specs[m.name] = specFrom(m);
                pane.monitors = list;
                pane.applied = specs;
                pane.draft = JSON.parse(JSON.stringify(specs));
                if (!pane.names.includes(pane.selected))
                    pane.selected = (list.find(m => m.focused) ?? list[0])?.name ?? "";
            } catch (error) {}
        });
    }

    function specFrom(m) {
        return {
            output: m.name,
            enabled: !m.disabled,
            mode: m.width + "x" + m.height + "@" + m.refreshRate.toFixed(2),
            x: m.x,
            y: m.y,
            scale: Math.round(m.scale * 100) / 100,
            transform: m.transform,
            mirror: m.mirrorOf && m.mirrorOf !== "none" ? m.mirrorOf : ""
        };
    }

    // Hyprland monitor rule for a spec.
    function rule(spec) {
        if (!spec.enabled)
            return {
                output: spec.output,
                disabled: true
            };
        const r = {
            output: spec.output,
            mode: spec.mode,
            position: Math.round(spec.x) + "x" + Math.round(spec.y),
            scale: spec.scale,
            transform: spec.transform
        };
        if (spec.mirror)
            r.mirror = spec.mirror;
        return r;
    }

    function luaRule(spec) {
        const r = rule(spec);
        return "hl.monitor({ " + Object.keys(r).map(k => k + " = " + (typeof r[k] === "string" ? JSON.stringify(r[k]) : r[k])).join(", ") + " })";
    }

    function applySpecs(specs, callback) {
        Store.run(["hyprctl", "eval", Object.values(specs).map(luaRule).join("\n")], () => {
            Qt.callLater(() => pane.refresh());
            callback?.();
        });
    }

    function edit(key, value) {
        const next = Object.assign({}, draft);
        next[selected] = Object.assign({}, next[selected]);
        next[selected][key] = value;
        draft = next;
    }

    function apply() {
        previous = applied;
        applySpecs(draft);
        countdown = 15;
    }

    property var previous: ({})

    function keep() {
        countdown = 0;
        Store.set("displays", "monitors", Object.values(draft).map(rule));
    }

    function revert() {
        countdown = 0;
        applySpecs(previous);
    }

    Timer {
        interval: 1000
        repeat: true
        running: pane.countdown > 0
        onTriggered: {
            pane.countdown--;
            if (pane.countdown === 0)
                pane.revert();
        }
    }

    // Logical size of a display (after scale and rotation), in layout pixels.
    function logicalSize(spec) {
        const [w, h] = spec.mode.split("@")[0].split("x").map(Number);
        const rotated = spec.transform % 2 === 1;
        return {
            w: (rotated ? h : w) / spec.scale,
            h: (rotated ? w : h) / spec.scale
        };
    }

    // ---- Arrangement ----

    SettingsGroup {
        Item {
            id: arrangement

            readonly property var specs: Object.values(pane.draft).filter(s => s.enabled && !s.mirror)
            readonly property var bounds: {
                let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
                for (const s of specs) {
                    const size = pane.logicalSize(s);
                    x0 = Math.min(x0, s.x);
                    y0 = Math.min(y0, s.y);
                    x1 = Math.max(x1, s.x + size.w);
                    y1 = Math.max(y1, s.y + size.h);
                }
                return specs.length ? {
                    x: x0,
                    y: y0,
                    w: x1 - x0,
                    h: y1 - y0
                } : {
                    x: 0,
                    y: 0,
                    w: 1,
                    h: 1
                };
            }
            // Layout pixels -> canvas pixels; leaves room around to drag displays outward.
            readonly property real ratio: Math.min((width - 80) / (bounds.w * 1.6), (height - 40) / (bounds.h * 1.6))

            width: parent.width
            height: 230

            Repeater {
                model: arrangement.specs

                Rectangle {
                    id: tile

                    required property var modelData
                    readonly property var size: pane.logicalSize(modelData)
                    readonly property bool isSelected: pane.selected === modelData.output
                    property real dragX: 0
                    property real dragY: 0

                    x: arrangement.width / 2 + (modelData.x - arrangement.bounds.x - arrangement.bounds.w / 2) * arrangement.ratio + dragX
                    y: arrangement.height / 2 + (modelData.y - arrangement.bounds.y - arrangement.bounds.h / 2) * arrangement.ratio + dragY
                    width: size.w * arrangement.ratio
                    height: size.h * arrangement.ratio
                    radius: 4
                    color: "#2a6fdb"
                    border.width: isSelected ? 3 : 1
                    border.color: isSelected ? "#ffffff" : "#66ffffff"

                    gradient: Gradient {
                        GradientStop {
                            position: 0
                            color: "#2a6fdb"
                        }
                        GradientStop {
                            position: 1
                            color: "#6a3fb5"
                        }
                    }

                    // Menu bar of the main display
                    Rectangle {
                        visible: (Store.get("displays", "main", "") || pane.names[0]) === tile.modelData.output
                        x: 3
                        y: 3
                        width: parent.width - 6
                        height: 5
                        radius: 2
                        color: "#ccffffff"
                    }

                    Text {
                        anchors.centerIn: parent
                        width: parent.width - 8
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: tile.modelData.output
                        color: "#ffffff"
                        font.family: Theme.font
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: arrangement.specs.length > 1 ? Qt.OpenHandCursor : Qt.PointingHandCursor
                        property point start

                        onPressed: event => {
                            pane.selected = tile.modelData.output;
                            start = mapToItem(arrangement, event.x, event.y);
                        }
                        onPositionChanged: event => {
                            if (arrangement.specs.length < 2)
                                return;
                            const p = mapToItem(arrangement, event.x, event.y);
                            tile.dragX = p.x - start.x;
                            tile.dragY = p.y - start.y;
                        }
                        onReleased: {
                            if (tile.dragX === 0 && tile.dragY === 0)
                                return;
                            arrangement.drop(tile.modelData, tile.modelData.x + tile.dragX / arrangement.ratio, tile.modelData.y + tile.dragY / arrangement.ratio);
                            tile.dragX = 0;
                            tile.dragY = 0;
                        }
                    }
                }
            }

            // Snaps a dropped display against the nearest edge of another one, so they touch
            // without overlapping (Hyprland needs that for the pointer to cross).
            function drop(spec, x, y) {
                const size = pane.logicalSize(spec);
                let best = null;
                for (const other of specs) {
                    if (other.output === spec.output)
                        continue;
                    const o = pane.logicalSize(other);
                    const candidates = [
                        {
                            x: other.x - size.w,
                            y: y
                        },
                        {
                            x: other.x + o.w,
                            y: y
                        },
                        {
                            x: x,
                            y: other.y - size.h
                        },
                        {
                            x: x,
                            y: other.y + o.h
                        }
                    ];
                    for (const c of candidates) {
                        // Keep some overlap along the shared edge, and line up edges that are close.
                        if (c.x === x) {
                            c.x = Math.max(other.x - size.w + 50, Math.min(other.x + o.w - 50, c.x));
                            for (const edge of [other.x, other.x + o.w - size.w])
                                if (Math.abs(c.x - edge) < 60)
                                    c.x = edge;
                        } else {
                            c.y = Math.max(other.y - size.h + 50, Math.min(other.y + o.h - 50, c.y));
                            for (const edge of [other.y, other.y + o.h - size.h])
                                if (Math.abs(c.y - edge) < 60)
                                    c.y = edge;
                        }
                        const distance = Math.hypot(c.x - x, c.y - y);
                        if (!best || distance < best.distance)
                            best = {
                                x: c.x,
                                y: c.y,
                                distance: distance
                            };
                    }
                }
                if (!best)
                    return;
                const next = Object.assign({}, pane.draft);
                next[spec.output] = Object.assign({}, next[spec.output], {
                    x: Math.round(best.x),
                    y: Math.round(best.y)
                });
                // Keep the top left display at 0,0
                const all = Object.values(next).filter(s => s.enabled && !s.mirror);
                const minX = Math.min(...all.map(s => s.x));
                const minY = Math.min(...all.map(s => s.y));
                for (const s of all)
                    next[s.output] = Object.assign({}, next[s.output], {
                        x: s.x - minX,
                        y: s.y - minY
                    });
                pane.draft = next;
            }
        }
    }

    Caption {
        text: pane.monitors.length > 1 ? qsTr("Drag displays to arrange them; the white bar marks the main display. Click one to change its settings below.")
                                       : qsTr("Connect another display to arrange them here.")
    }

    // ---- Selected display ----

    GroupTitle {
        text: pane.currentInfo ? pane.currentInfo.name + "  ·  " + (pane.currentInfo.make + " " + pane.currentInfo.model).trim() : ""
    }

    SettingsGroup {
        visible: pane.current !== null

        SettingRow {
            visible: pane.monitors.length > 1
            title: qsTr("Use as")

            Dropdown {
                anchors.verticalCenter: parent.verticalCenter
                options: [
                    {
                        label: qsTr("Main display"),
                        value: "main"
                    },
                    {
                        label: qsTr("Extended display"),
                        value: "extended"
                    },
                    ...pane.names.filter(n => n !== pane.selected).map(n => ({
                                label: qsTr("Mirror for %1").arg(n),
                                value: "mirror:" + n
                            }))
                ]
                value: pane.current?.mirror ? "mirror:" + pane.current.mirror
                                            : (Store.get("displays", "main", "") || pane.names[0]) === pane.selected ? "main" : "extended"
                onPicked: v => {
                    if (v.startsWith("mirror:")) {
                        pane.edit("mirror", v.slice(7));
                    } else {
                        pane.edit("mirror", "");
                        if (v === "main")
                            Store.set("displays", "main", pane.selected);
                        else if (Store.get("displays", "main", "") === pane.selected)
                            Store.set("displays", "main", "");
                    }
                }
            }
        }

        SettingRow {
            visible: pane.monitors.length > 1
            title: qsTr("Enabled")

            Toggle {
                anchors.verticalCenter: parent.verticalCenter
                checked: pane.current?.enabled ?? true
                // The last enabled display can't be turned off.
                enabled: !checked || Object.values(pane.draft).filter(s => s.enabled).length > 1
                onToggled: on => pane.edit("enabled", on)
            }
        }

        SettingRow {
            title: qsTr("Resolution")
            enabled: pane.current?.enabled ?? false
            opacity: enabled ? 1 : 0.4

            Dropdown {
                anchors.verticalCenter: parent.verticalCenter
                readonly property var sizes: Array.from(new Set((pane.currentInfo?.availableModes ?? []).map(m => m.split("@")[0])))

                options: sizes.map(s => ({
                            label: s.replace("x", " × "),
                            value: s
                        }))
                value: pane.current?.mode.split("@")[0]
                onPicked: size => {
                    // Best refresh rate for the new size
                    const rates = (pane.currentInfo?.availableModes ?? []).filter(m => m.startsWith(size + "@")).map(m => parseFloat(m.split("@")[1]));
                    pane.edit("mode", size + "@" + Math.max(...rates).toFixed(2));
                }
            }
        }

        SettingRow {
            title: qsTr("Refresh rate")
            enabled: pane.current?.enabled ?? false
            opacity: enabled ? 1 : 0.4

            Dropdown {
                anchors.verticalCenter: parent.verticalCenter
                readonly property string size: pane.current?.mode.split("@")[0] ?? ""

                options: (pane.currentInfo?.availableModes ?? []).filter(m => m.startsWith(size + "@")).map(m => {
                    const rate = parseFloat(m.split("@")[1]);
                    return {
                        label: rate.toFixed(2).replace(/\.?0+$/, "") + " Hz",
                        value: size + "@" + rate.toFixed(2)
                    };
                })
                value: pane.current?.mode
                onPicked: mode => pane.edit("mode", mode)
            }
        }

        SettingRow {
            title: qsTr("Scale")
            subtitle: pane.current ? qsTr("Looks like %1 × %2").arg(Math.round(pane.logicalSize(pane.current).w)).arg(Math.round(pane.logicalSize(pane.current).h)) : ""
            enabled: pane.current?.enabled ?? false
            opacity: enabled ? 1 : 0.4

            Dropdown {
                anchors.verticalCenter: parent.verticalCenter
                options: [1, 1.25, 1.333333, 1.5, 1.6, 1.75, 2, 2.5, 3].map(s => ({
                            label: Math.round(s * 100) + "%",
                            value: s
                        }))
                value: [1, 1.25, 1.333333, 1.5, 1.6, 1.75, 2, 2.5, 3].find(s => Math.abs(s - (pane.current?.scale ?? 1)) < 0.01)
                onPicked: v => pane.edit("scale", v)
            }
        }

        SettingRow {
            title: qsTr("Rotation")
            enabled: pane.current?.enabled ?? false
            opacity: enabled ? 1 : 0.4

            Dropdown {
                anchors.verticalCenter: parent.verticalCenter
                options: [
                    {
                        label: qsTr("Standard"),
                        value: 0
                    },
                    {
                        label: "90°",
                        value: 1
                    },
                    {
                        label: "180°",
                        value: 2
                    },
                    {
                        label: "270°",
                        value: 3
                    }
                ]
                value: (pane.current?.transform ?? 0) % 4
                onPicked: v => pane.edit("transform", v)
            }
        }
    }

    Row {
        anchors.right: parent.right
        spacing: 8

        TextButton {
            text: qsTr("Revert")
            enabled: pane.changed
            onClicked: pane.draft = JSON.parse(JSON.stringify(pane.applied))
        }

        TextButton {
            primary: true
            text: qsTr("Apply")
            enabled: pane.changed
            onClicked: pane.apply()
        }
    }

    Sheet {
        shown: pane.countdown > 0
        onDismissed: pane.revert()

        Text {
            width: parent.width
            text: qsTr("Keep these display settings?")
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 15
            font.weight: Font.DemiBold
        }

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: (pane.countdown === 1 ? qsTr("Reverting to the previous settings in 1 second.") : qsTr("Reverting to the previous settings in %1 seconds.").arg(pane.countdown))
            color: Theme.textSecondary
            font.family: Theme.font
            font.pixelSize: 12
        }

        Row {
            anchors.right: parent.right
            spacing: 8

            TextButton {
                text: qsTr("Revert")
                onClicked: pane.revert()
            }

            TextButton {
                primary: true
                text: qsTr("Keep Changes")
                onClicked: pane.keep()
            }
        }
    }

    // ---- Brightness ----

    SettingsGroup {
        visible: pane.brightness >= 0

        SettingRow {
            title: qsTr("Brightness")
            subtitle: qsTr("Built-in display")
            below: SettingSlider {
                width: parent.width
                from: 0.01
                to: 1
                value: pane.brightness
                onMoved: v => {
                    pane.brightness = v;
                    brightnessTimer.restart();
                }
            }
        }
    }

    Timer {
        id: brightnessTimer

        interval: 60
        onTriggered: Store.run(["sh", "-c", 'brightnessctl -q set "$1%" || sudo -n brightnessctl -q set "$1%"', "sh", String(Math.round(pane.brightness * 100))])
    }

    // ---- Night Shift ----

    GroupTitle {
        text: qsTr("Night Shift")
    }

    SettingsGroup {
        SettingRow {
            title: qsTr("Schedule")

            Dropdown {
                anchors.verticalCenter: parent.verticalCenter
                options: [
                    {
                        label: qsTr("Off"),
                        value: "off"
                    },
                    {
                        label: qsTr("Custom"),
                        value: "custom"
                    }
                ]
                value: pane.night.schedule ?? "off"
                onPicked: v => nightShift.set("schedule", v)
            }
        }

        SettingRow {
            visible: pane.night.schedule === "custom"
            title: qsTr("From")

            Dropdown {
                anchors.verticalCenter: parent.verticalCenter
                options: Ui.halfHours
                value: pane.night.from ?? "22:00"
                onPicked: v => nightShift.set("from", v)
            }
        }

        SettingRow {
            visible: pane.night.schedule === "custom"
            title: qsTr("To")

            Dropdown {
                anchors.verticalCenter: parent.verticalCenter
                options: Ui.halfHours
                value: pane.night.to ?? "7:00"
                onPicked: v => nightShift.set("to", v)
            }
        }

        SettingRow {
            title: qsTr("Turn on until I turn it off")

            Toggle {
                anchors.verticalCenter: parent.verticalCenter
                checked: pane.night.manual === true
                onToggled: on => nightShift.set("manual", on)
            }
        }

        SettingRow {
            title: qsTr("Color temperature")
            below: SettingSlider {
                width: parent.width
                // Left is less warm (higher kelvin), as on macOS
                from: -6500
                to: -2500
                step: 100
                minLabel: qsTr("Less Warm")
                maxLabel: qsTr("More Warm")
                value: -(pane.night.temperature ?? 4500)
                onMoved: v => {
                    nightShift.temperature = -v;
                    temperatureTimer.restart();
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: (pane.night.temperature ?? 4500) + " K"
                color: Theme.textSecondary
                font.family: Theme.font
                font.pixelSize: 12
            }
        }
    }

    Caption {
        text: qsTr("Night Shift warms the colors with hyprsunset; while it's on, moving the slider previews the color.")
    }

    QtObject {
        id: nightShift

        property int temperature: 4500

        function set(key, value) {
            const next = Object.assign({
                schedule: "off",
                from: "22:00",
                to: "7:00",
                manual: false,
                temperature: 4500
            }, pane.night);
            next[key] = value;
            Store.set("displays", "nightShift", next);
            Store.writeNightShift();
        }
    }

    // Saves the temperature once the slider rests; previews it right away while Night Shift is on.
    Timer {
        id: temperatureTimer

        interval: 300
        onTriggered: {
            nightShift.set("temperature", nightShift.temperature);
        }
    }
}
