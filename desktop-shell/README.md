# desktop-shell

The desktop in one Quickshell process: the Dock (`sway-dock`), the window switcher (`app-switcher`), the menu
bar panels (`waybar-widgets`), the desktop (`desktop`: wallpaper and icons), the notifications
(`notifications`: daemon, banners, Notification Center) and the password dialog (`polkit-agent`). Every
Quickshell process has a fixed base cost before it draws anything, so they share one.

Nothing is copied here. `dock`, `switcher`, `widgets`, `desktop`, `notifications`, `polkit` and `common` are
links to the folders next to this one, and `shell.qml` loads their `DockShell.qml`, `SwitcherShell.qml`,
`WidgetsShell.qml`, `DesktopShell.qml`, `NotificationDaemon.qml` and `PolkitShell.qml`.

What the parts share is read once, in `common` (`shell-common`):

- `Settings`: System Settings' `settings.json`, re-read when it changes
- `Appearance`: light or dark, from the GTK color scheme
- `Displays`: which monitor is which (make, model and serial number), so a display's Dock, wallpaper and
  desktop arrangement follow it to another port

A mistake in one part's QML only stops that part: each part is loaded on its own (`LazyLoader`), and the others
keep running. If the process crashes, all of them go away together until Quickshell restarts itself.

The lock screen (`lockscreen`) is the one thing that runs on its own, with as little in it as possible: if it
crashed while locked, the session would be stuck behind Hyprland's red screen. That is also why the
notifications, which handle text and pictures sent by any app, live here and not there.

## Run

```sh
MALLOC_CONF=narenas:1 QS_ICON_THEME=MacTahoe-dark qs -p ~/.config/desktop-shell
qs -p ~/.config/desktop-shell ipc call switcher next           # also: previous left right up down commit cancel close
qs -p ~/.config/desktop-shell ipc call panel toggle wifi       # also: volume bluetooth battery system display power
                                                               # date media; panel open <name>, panel close
qs -p ~/.config/desktop-shell ipc call notifications toggle    # also: open close toggleDnd setDnd isDnd clearAll clearApp
```

`hyprland.lua` starts it at login. waybar's buttons go through `waybar-widgets/toggle.sh`.

## Memory

Start it with `MALLOC_CONF=narenas:1`, as `hyprland.lua`, System Settings and `toggle.sh` do. Quickshell's
allocator (jemalloc) makes four memory pools per CPU core and the shell's threads spread over them, each pool
keeping spare memory; on a 16-core machine that was 160 MB of the shell's 290 MB. With one pool the shell (two
displays, Dock and wallpaper on both) measured 129 MB, and the lock screen's idle process 29 MB instead of 76.

System Settings → General → Performance → **Draw the Dock, desktop and panels with one thread** starts it with
`QSG_RENDER_LOOP=basic` as well: about 12 MB less, but every window then shares one drawing thread, so a busy
one can make the others' animations stutter. Off by default.

Apps started from the Dock, the desktop or a panel don't inherit either setting (`Launch` in `shell-common`
takes them out of their environment): one memory pool suits a shell, not a browser.

The icon theme is the `QS_ICON_THEME` variable the shell starts with: `hyprland.lua` sets it from System
Settings → Appearance, which restarts the shell with the new one when you change it. (There is no
`//@ pragma IconTheme` line in `shell.qml`; it would win over the variable.)

Live reload is off (`settings.watchFiles`). After editing any of the folders, restart it:
`qs kill -p ~/.config/desktop-shell; qs -p ~/.config/desktop-shell -d`.

## Why the imports in shell.qml

`shell.qml` imports `qs.common`, `qs.dock`, `qs.switcher`, `qs.widgets`, `qs.desktop`, `qs.notifications` and
`qs.polkit` without using them. Quickshell 0.3 only finds all of a folder's components and singletons (e.g. the
Dock's `DockTheme`) after the folder has been imported; without that, loading `dock/DockShell.qml` by path fails
with "DockTheme is not a type" and similar.
