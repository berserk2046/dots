# Lock screen ideas

The lock screen is now the Quickshell one in `../lockscreen` (hyprlock is no longer used).

## Done

- Full lock UI only on the main monitor (`Config.mainScreen`)
- Password not needed for 15 seconds after locking (`Config.graceSeconds`)
- Battery level and charging state, Wi-Fi network and signal, keyboard layout (top right)
- Clear Caps Lock warning (symbol in the field and a line under it)
- Sleep / Restart / Shut Down buttons
- Custom message (`Config.message`, e.g. "Hello")
- Up Next calendar event, from `waybar-widgets/calendar-sync.py`
- Notifications on the lock screen (the shell is now the notification daemon, with banners while unlocked)
- Now Playing card
- Shake on a wrong password, slide-up when unlocking
- Login screen with the same look (greetd + `lockscreen/greeter.qml`)

## Still open

- **Auto-lock on idle and before sleep**: lock after N minutes, turn displays off, lock before suspend.
  Needs `hypridle` (not installed); it would call `qs -p ~/.config/lockscreen ipc call lock lock`.
- **Touch ID**: fingerprint unlock through `fprintd`, only with a fingerprint reader.
- **Weather widget**: temperature and condition from an online service such as wttr.in.
