pragma Singleton
import QtQuick
import Quickshell

// Navigation and the window-wide layers (pop-up menus, sheets), shared by every pane.
Singleton {
    id: ui

    property string pane: "wifi"
    // A page inside the pane (e.g. "about" in General), or "" for the pane itself.
    property string subpage: ""
    property var history: []

    // Bumped after the account picture or name changes, so the sidebar re-reads them.
    property int userVersion: 0

    // Set by shell.qml
    property Item overlay: null
    property MenuLayer menu: null

    function open(id, sub) {
        if (id === pane && (sub ?? "") === subpage)
            return;
        history = [...history, {
                pane: pane,
                subpage: subpage
            }].slice(-30);
        pane = id;
        subpage = sub ?? "";
    }

    function openSub(sub) {
        open(pane, sub);
    }

    function back() {
        if (subpage !== "") {
            subpage = "";
            return;
        }
        const last = history[history.length - 1];
        if (!last)
            return;
        history = history.slice(0, -1);
        pane = last.pane;
        subpage = last.subpage;
    }

    // Pop-up menu under `anchor`; options are strings or {label, value}.
    function openMenu(anchor, options, current, picked) {
        menu?.show(anchor, options, current, picked);
    }

    function labelOf(option) {
        return typeof option === "object" && option !== null ? option.label : String(option);
    }

    function valueOf(option) {
        return typeof option === "object" && option !== null ? option.value : option;
    }

    // Every half hour of the day as {label: "10:30 PM", value: "22:30"}, for schedule pickers.
    readonly property var halfHours: {
        const list = [];
        for (let i = 0; i < 48; i++) {
            const h = Math.floor(i / 2);
            const m = i % 2 ? "30" : "00";
            const label = (h % 12 === 0 ? 12 : h % 12) + ":" + m + (h < 12 ? " AM" : " PM");
            list.push({
                label: label,
                value: h + ":" + m
            });
        }
        return list;
    }
}
