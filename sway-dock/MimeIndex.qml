import QtQuick
import Quickshell
import Quickshell.Io

// Knows which file types each app opens (MimeType= in its .desktop file) and the types of
// the files currently being dragged, so the dock only highlights apps that can open them.
Scope {
    id: root

    property var appTypes: ({}) // lowercase desktop ID -> array of MIME types
    property var parents: ({}) // MIME type -> parent types (subclasses)
    property var aliases: ({}) // alias -> canonical MIME type

    property string dragKey: ""
    property var dragTypes: null // types of the dragged files; null while unknown

    function parseIndex(text) {
        const apps = {};
        const parentMap = {};
        const aliasMap = {};
        for (const line of text.split("\n")) {
            const [kind, a, b] = line.split("\t");
            if (kind === "A") {
                const id = a.replace(/\.desktop$/, "").replace(/\//g, "-").toLowerCase();
                if (!(id in apps))
                    apps[id] = (b || "").split(";").filter(type => type.length > 0);
            } else if (kind === "S" && b) {
                (parentMap[a] = parentMap[a] || []).push(b);
            } else if (kind === "L" && b) {
                aliasMap[a] = b;
            }
        }
        appTypes = apps;
        parents = parentMap;
        aliases = aliasMap;
    }

    // The type plus everything it is a subclass of, as shared-mime-info defines it.
    function ancestors(type) {
        const result = [];
        const queue = [aliases[type] || type];
        while (queue.length > 0) {
            const current = queue.shift();
            if (result.indexOf(current) >= 0)
                continue;
            result.push(current);
            queue.push(...(parents[current] || []).map(parent => aliases[parent] || parent));
            if (current.startsWith("text/") && current !== "text/plain")
                queue.push("text/plain");
        }
        if (!type.startsWith("inode/"))
            result.push("application/octet-stream");
        return result;
    }

    function appAcceptsType(accepted, type) {
        return ancestors(type).some(candidate => accepted.some(pattern => pattern === candidate
                                                                          || (pattern.endsWith("/*")
                                                                              && candidate.startsWith(pattern.slice(0, -1)))));
    }

    // True when the app can open every dragged file.
    function accepts(desktopId, types) {
        if (!types || types.length === 0)
            return false;
        const accepted = (appTypes[String(desktopId).toLowerCase()] || []).map(type => aliases[type] || type);
        return types.every(type => appAcceptsType(accepted, type));
    }

    function resolveDrag(urls) {
        const list = urls.map(String);
        const key = list.join("\n");
        if (key === dragKey)
            return;
        dragKey = key;
        dragTypes = null;
        // Links (e.g. dragged from a browser) are typed by scheme, like xdg-open does.
        const files = list.filter(url => url.startsWith("file://"));
        const schemes = list.filter(url => !url.startsWith("file://")).map(url => "x-scheme-handler/" + url.split(":")[0]);
        if (files.length === 0) {
            dragTypes = schemes;
            return;
        }
        typeProcess.key = key;
        typeProcess.schemes = schemes;
        typeProcess.running = false;
        typeProcess.command = ["gio", "info", "-a", "standard::content-type,standard::fast-content-type", ...files];
        typeProcess.running = true;
    }

    function parseTypes(text) {
        const types = [];
        for (const block of text.split(/^uri: /m).slice(1)) {
            const content = /standard::content-type: (\S+)/.exec(block)?.[1];
            const fast = /standard::fast-content-type: (\S+)/.exec(block)?.[1];
            // Empty files have no content to sniff; fall back to the extension-based type.
            const type = content && content !== "application/x-zerosize" ? content : fast;
            if (type)
                types.push(type);
        }
        return types;
    }

    function refresh() {
        indexProcess.running = false;
        indexProcess.running = true;
    }

    Process {
        id: indexProcess

        command: ["sh", Quickshell.shellPath("mime-index.sh")]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.parseIndex(text)
        }
    }

    Process {
        id: typeProcess

        property string key
        property var schemes: []

        stdout: StdioCollector {
            onStreamFinished: {
                if (typeProcess.key === root.dragKey)
                    root.dragTypes = root.parseTypes(text).concat(typeProcess.schemes);
            }
        }
    }

    // Re-read when apps are installed or removed.
    Connections {
        target: DesktopEntries.applications

        function onValuesChanged() {
            root.refresh();
        }
    }
}
