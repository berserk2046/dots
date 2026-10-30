# lockscreen

macOS-style lock screen, login screen, notification daemon and Notification Center for Hyprland, built with Quickshell.

- Blurred wallpaper, date and large clock
- Now Playing card (prefers Spotify), Up Next calendar event, notifications that arrived while locked
- Keyboard layout (click to switch), Wi-Fi network and signal, battery level and charging state
- Your message (`Config.message`), picture (`~/.face`) and name, pill-shaped password field
- Caps Lock symbol in the field plus a "Caps Lock is on" line
- The field shakes on a wrong password; the screen slides up when unlocking, revealing the desktop
- Sleep, Restart and Shut Down buttons
- Full UI on the main monitor only; the others show the wallpaper and clock
- Any key or click unlocks during the first 15 seconds after locking (`Config.graceSeconds`)
- While unlocked, notifications show as banners in the top right corner for 5 seconds

## Notifications

The shell is the notification daemon, so anything that sends desktop notifications shows up here:
browsers (WhatsApp Web, Instagram... once the site may notify), Discord, `notify-send` and so on.

- Unlocked: banners in the top right corner for 5 seconds; click to open the app, hover to close
- Locked: on the lock screen under the clock
- Notification Center ($mod+N or Waybar's bell): every notification, grouped by app. Delete one with the ×
  on hover, an app's with Clear, or everything with Clear All. Clicking one opens it while the app still has it.
  The history (up to `Config.historyLimit`) is kept across restarts in
  `~/.local/state/quickshell/by-shell/lockscreen/notifications.json`.
- Do Not Disturb (the tile in the Notification Center, or right click the bell): no banners, sounds or lock screen
  notifications, except critical ones and apps allowed in System Settings → Focus; everything is still saved in
  the history. The bell turns into a moon. It can also turn on by itself on a daily schedule (Focus)
- An alert sound plays for each notification (System Settings → Sound → Sound Effects), through `pw-play`
- Per app (System Settings → Notifications): turn notifications off entirely, or just their sound, banners or
  lock screen entry

```sh
qs -p ~/.config/lockscreen ipc call notifications toggle      # also: open, close, toggleDnd, clearAll
qs -p ~/.config/lockscreen ipc call notifications setDnd true  # also: isDnd, clearApp <app name>
```

Waybar's `custom/notifications` reads `$XDG_RUNTIME_DIR/lockscreen/notifications.json` and is refreshed with
SIGRTMIN+9.

## Settings

Set in System Settings (Lock Screen, Notifications, Focus, Sound, Wallpaper, Displays → main display), saved in
`~/.config/system-settings/settings.json` and read by `Config.qml`, which follows changes and holds the defaults:
message, grace period, main monitor, wallpaper, notification previews, banner duration, history size, per-app
rules, the Do Not Disturb schedule and alert sound. Login user, picture, layout names and the session the login
screen starts are set in `Config.qml` itself.

Auto-lock, display sleep and locking before sleep are hypridle's (`~/.config/hypr/hypridle.conf`, written by
System Settings → Lock Screen).

## Lock screen

Started from `hyprland.lua` (`qs -p ~/.config/lockscreen`). Lock with $mod+CTRL+q, or:

```sh
qs -p ~/.config/lockscreen ipc call lock lock      # grace period applies
qs -p ~/.config/lockscreen ipc call lock lockNow   # password right away (used before sleep)
```

The password is checked by PAM with the system's `/etc/pam.d/login` rules, so faillock lockouts apply.
Pictures of the desktop for the slide-up are kept in `$XDG_RUNTIME_DIR/lockscreen` while locked and
deleted after unlocking.

If the lock screen ever crashes while locked, Hyprland shows a red screen. Switch to another TTY
(Ctrl+Alt+F3), log in and run:

```sh
hyprctl --instance 0 dispatch exec "qs -p ~/.config/lockscreen"
hyprctl --instance 0 dispatch exec "qs -p ~/.config/lockscreen ipc call lock lockNow"
```

then go back to Hyprland's TTY (`allow_session_lock_restore` in `hyprland.lua` lets it take over).

## Login screen

`greeter.qml` runs under greetd inside a minimal Hyprland (`greetd/hyprland.lua`). It signs in
`Config.user` and starts `Config.session` (`start-hyprland`). Install or update it with:

```sh
sudo sh greetd/install.sh
```

The greeter user can't read your home folder, so the script copies these files, the wallpaper, `~/.face` and
System Settings' `settings.json` into `/etc/greetd/lockscreen`. Run it again after changing anything here, or
use System Settings → Lock Screen → Login screen → Update.
Media, calendar and notifications aren't shown there, since they belong to your session.
