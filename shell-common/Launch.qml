pragma Singleton
import QtQuick
import Quickshell

// Starts apps for the user (from the Dock, the desktop, a panel) without what the shell itself was
// started with: its allocator setting (MALLOC_CONF, one memory pool, which suits a shell and not a
// browser or a database) and its rendering setting (QSG_RENDER_LOOP, System Settings → General).
// Both are in the shell's environment, which anything it starts would otherwise inherit.
Singleton {
    readonly property var cleaned: ({
            "MALLOC_CONF": null,
            "QSG_RENDER_LOOP": null
        })

    function app(command) {
        Quickshell.execDetached({
            command: command,
            environment: cleaned
        });
    }
}
