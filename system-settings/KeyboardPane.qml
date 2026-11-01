import QtQuick
import qs.shared

// Keyboard: key repeat, input sources (xkb layouts, switched with $mod+U) and the shortcut list.
Column {
    id: pane

    property string pageTitle: Ui.subpage === "shortcuts" ? qsTr("Keyboard Shortcuts") : ""
    property var allLayouts: [] // {layout, variant, name}
    property var binds: []
    readonly property var layouts: Store.get("keyboard", "layouts", [{
            layout: "us",
            variant: ""
        }, {
            layout: "latam",
            variant: ""
        }])

    spacing: 10

    Component.onCompleted: {
        // Layouts and variants from xkb's list
        Store.run(["sh", "-c", "sed -n '/^! layout/,/^! option/p' /usr/share/X11/xkb/rules/base.lst"], (code, out) => {
            const list = [];
            let section = "";
            for (const line of out.split("\n")) {
                if (line.startsWith("!")) {
                    section = line.slice(2).trim();
                    continue;
                }
                const m = line.match(/^\s+(\S+)\s+(.*)$/);
                if (!m)
                    continue;
                if (section === "layout")
                    list.push({ layout: m[1], variant: "", name: m[2] });
                else if (section === "variant") {
                    const v = m[2].match(/^(\S+): (.*)$/);
                    if (v)
                        list.push({ layout: v[1], variant: m[1], name: v[2] });
                }
            }
            pane.allLayouts = list;
        });
        Store.run(["hyprctl", "binds", "-j"], (code, out) => {
            try {
                // Mouse binds and the repeated focus/move/workspace ones in Lua loops stay in
                // the list; only exact duplicates (same keys and description) are dropped.
                const seen = new Set();
                pane.binds = JSON.parse(out).filter(b => {
                    const id = b.modmask + b.key + b.submap + b.description;
                    if (seen.has(id))
                        return false;
                    seen.add(id);
                    return true;
                });
            } catch (error) {}
        });
    }

    function nameOf(l) {
        return allLayouts.find(a => a.layout === l.layout && a.variant === (l.variant ?? ""))?.name ?? l.layout;
    }

    // e.g. "⌘⇧ ←" for $mod+SHIFT+left
    function keyName(bind) {
        const mods = [];
        if (bind.modmask & 64)
            mods.push("⌘");
        if (bind.modmask & 4)
            mods.push("⌃");
        if (bind.modmask & 8)
            mods.push("⌥");
        if (bind.modmask & 1)
            mods.push("⇧");
        const names = {
            "Return": "↩",
            "escape": "Esc",
            "space": "Space",
            "left": "←",
            "right": "→",
            "up": "↑",
            "down": "↓",
            "minus": "-",
            "period": ".",
            "comma": ",",
            "Print": "Print Screen",
            "mouse:272": "Left-drag",
            "mouse:273": "Right-drag"
        };
        const key = names[bind.key] ?? bind.key.replace(/^XF86/, "").replace(/([a-z])([A-Z])/g, "$1 $2");
        return (mods.join("") + " " + (key.length === 1 ? key.toUpperCase() : key)).trim();
    }

    // Binds grouped by mode: [{submap, binds}], normal ones first.
    readonly property var bindGroups: {
        const groups = [];
        for (const bind of binds) {
            let group = groups.find(g => g.submap === bind.submap);
            if (!group) {
                group = {
                    submap: bind.submap,
                    binds: []
                };
                groups.push(group);
            }
            group.binds.push(bind);
        }
        return groups.sort((a, b) => (a.submap === "" ? 0 : 1) - (b.submap === "" ? 0 : 1));
    }

    SettingsGroup {
        visible: Ui.subpage === ""

        SettingRow {
            title: qsTr("Key repeat rate")
            below: SettingSlider {
                width: parent.width
                from: 5
                to: 80
                step: 5
                minLabel: qsTr("Slow")
                maxLabel: qsTr("Fast")
                value: Store.get("keyboard", "repeatRate", 25)
                onMoved: v => Store.set("keyboard", "repeatRate", v)
            }
        }

        SettingRow {
            title: qsTr("Delay until repeat")
            below: SettingSlider {
                width: parent.width
                // Left is long, as on macOS
                from: -1500
                to: -150
                step: 50
                minLabel: qsTr("Long")
                maxLabel: qsTr("Short")
                value: -Store.get("keyboard", "repeatDelay", 600)
                onMoved: v => Store.set("keyboard", "repeatDelay", -v)
            }
        }
    }

    GroupTitle {
        visible: Ui.subpage === ""
        text: qsTr("Input Sources")

        Dropdown {
            anchors.verticalCenter: parent.verticalCenter
            placeholder: qsTr("Add…")
            options: pane.allLayouts.map((l, i) => ({ label: l.name, value: i }))
            value: undefined
            onPicked: i => {
                const l = pane.allLayouts[i];
                if (!pane.layouts.some(x => x.layout === l.layout && (x.variant ?? "") === l.variant))
                    Store.set("keyboard", "layouts", [...pane.layouts, { layout: l.layout, variant: l.variant }]);
            }
        }
    }

    SettingsGroup {
        visible: Ui.subpage === ""

        Repeater {
            model: pane.layouts

            SettingRow {
                id: layoutRow

                required property var modelData
                required property int index

                title: pane.nameOf(modelData)
                subtitle: modelData.layout + (modelData.variant ? " (" + modelData.variant + ")" : "")
                glyph: Theme.iKeyboard
                tileColor: "#8e8e93"

                TextButton {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: pane.layouts.length > 1
                    text: qsTr("Remove")
                    onClicked: Store.set("keyboard", "layouts", pane.layouts.filter((l, i) => i !== layoutRow.index))
                }
            }
        }
    }

    Caption {
        visible: Ui.subpage === ""
        text: qsTr("Switch between them with $mod+U, or click the layout on the lock screen.")
    }

    SettingsGroup {
        visible: Ui.subpage === ""

        SettingRow {
            title: qsTr("Keyboard Shortcuts…")
            chevron: true
            onClicked: Ui.openSub("shortcuts")
        }
    }

    Repeater {
        model: Ui.subpage === "shortcuts" ? pane.bindGroups : []

        Column {
            id: bindGroup

            required property var modelData

            width: pane.width
            spacing: 6

            GroupTitle {
                visible: bindGroup.modelData.submap !== ""
                text: qsTr("In %1 mode").arg(bindGroup.modelData.submap)
            }

            SettingsGroup {
                Repeater {
                    model: bindGroup.modelData.binds

                    SettingRow {
                        id: bindRow

                        required property var modelData

                        title: modelData.description || modelData.dispatcher

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: pane.keyName(bindRow.modelData)
                            color: Theme.textSecondary
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize(12)
                        }
                    }
                }
            }
        }
    }

    Caption {
        visible: Ui.subpage === "shortcuts"
        text: qsTr("Shortcuts are defined in ~/.config/hypr/hyprland.lua.")
    }
}
