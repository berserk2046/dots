// Fixed ID so `qs ipc` finds this shell wherever the folder lives.
//@ pragma ShellId desktop-shell
// The icon theme comes from the QS_ICON_THEME environment variable, which hyprland.lua and System
// Settings → Appearance set when they start this shell (no IconTheme pragma here: it would win over it).
import Quickshell
// Not used here directly, but needed: importing a folder makes Quickshell register all of its
// components and singletons (e.g. the Dock's DockTheme). Without it, Quickshell 0.3 finds only some
// of a part's neighbouring files when the LazyLoaders below load it.
import qs.common as Common
import qs.dock as Dock
import qs.switcher as Switcher
import qs.widgets as Widgets
import qs.desktop as Desktop
import qs.notifications as Notifications
import qs.polkit as Polkit

// The desktop in one Quickshell process: the Dock, the window switcher (Alt+Tab), the menu bar panels,
// the desktop (wallpaper and icons), the notifications (daemon, banners, Notification Center) and the
// password dialog (polkit agent). Every Quickshell process has a fixed base cost before it draws
// anything, so they share one. Only the lock screen runs on its own (see lockscreen/shell.qml).
//
// The parts aren't copied here: dock, switcher, widgets, desktop, notifications, polkit and common link
// to the folders next to this one. Settings, light/dark and the displays' identities are read once, in
// common, for all of them. IPC:
//   qs -p ~/.config/desktop-shell ipc call switcher next
//   qs -p ~/.config/desktop-shell ipc call panel toggle wifi
//   qs -p ~/.config/desktop-shell ipc call notifications toggle
//
// Each part loads on its own, so a mistake in one part's files leaves the others running.
ShellRoot {
    // No live reload when these files change. After editing any of the folders, restart the shell:
    //   qs kill -p ~/.config/desktop-shell; qs -p ~/.config/desktop-shell -d
    settings.watchFiles: false

    LazyLoader {
        active: true
        source: "dock/DockShell.qml"
    }

    LazyLoader {
        active: true
        source: "switcher/SwitcherShell.qml"
    }

    LazyLoader {
        active: true
        source: "widgets/WidgetsShell.qml"
    }

    LazyLoader {
        active: true
        source: "desktop/DesktopShell.qml"
    }

    LazyLoader {
        active: true
        source: "notifications/NotificationDaemon.qml"
    }

    LazyLoader {
        active: true
        source: "polkit/PolkitShell.qml"
    }
}
