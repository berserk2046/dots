# notifications

The notification daemon, banners and Notification Center, built with Quickshell. Runs inside `desktop-shell`.
Anything that sends desktop notifications shows up here: browsers (WhatsApp Web, Instagram... once the site may
notify), Discord, `notify-send` and so on.

- Unlocked: banners in the top right corner for 5 seconds; click to open the app, hover to close
- Locked: the lock screen shows how many notifications arrived and from which apps, never what they say; that
  is in the Notification Center once you've unlocked
- Notification Center ($mod+N or Waybar's bell): every notification, grouped by app. Delete one with the ×
  on hover, an app's with Clear, or everything with Clear All. Clicking one opens it while the app still has it.
  The history (up to System Settings → Notifications → history size) is kept across restarts in
  `~/.local/state/quickshell/by-shell/lockscreen/notifications.json`, in a folder only you can read
- Do Not Disturb (the tile in the Notification Center, or right click the bell): no banners, sounds or lock screen
  count, except critical ones and apps allowed in System Settings → Focus; everything is still saved in the
  history. The bell turns into a moon. It can also turn on by itself on a daily schedule (Focus)
- An alert sound plays for each notification (System Settings → Sound → Sound Effects), through `pw-play`
- Per app (System Settings → Notifications): turn notifications off entirely, or just their sound, banners or
  lock screen count
- Show previews → Never: banners and the Notification Center show only the app, and no text is saved

```sh
qs -p ~/.config/desktop-shell ipc call notifications toggle      # also: open, close, toggleDnd, clearAll
qs -p ~/.config/desktop-shell ipc call notifications setDnd true  # also: isDnd, clearApp <app name>
```

Waybar's `custom/notifications` reads `$XDG_RUNTIME_DIR/lockscreen/notifications.json` and is refreshed with
SIGRTMIN+9. The lock screen reads the same file for its count, and tells the daemon when it locks and unlocks
(`ipc call notifications setLocked true|false`).

## What an app can't make it do

Notifications come from any app, and through browsers from any web site, so what they send is treated as text
and nothing more:

- Titles, text and app names are shown as plain text; markup in them is not interpreted
- An icon or picture is shown only if it is a file on this computer, picture data sent with the notification,
  or an icon from the icon theme. A web address is never fetched
- The daemon runs in `desktop-shell`, not in the lock screen's process
