# lockscreen

macOS-style lock screen and login screen for Hyprland, built with Quickshell. It runs in a process of its own,
with as little in it as possible: if it crashed while locked, the session would be stuck behind Hyprland's red
screen. The notifications are in `notifications/` (inside `desktop-shell`).

- Blurred wallpaper, date and large clock
- Now Playing card (prefers Spotify), Up Next calendar event
- How many notifications arrived while locked, and from which apps. What they say stays behind the password,
  in the Notification Center
- Keyboard layout (click to switch), Wi-Fi network and signal, battery level and charging state
- Your message (`Config.message`), picture (`~/.face`) and name, pill-shaped password field
- Caps Lock symbol in the field plus a "Caps Lock is on" line
- The field shakes on a wrong password; the screen slides up when unlocking, revealing the desktop
- Sleep, Restart and Shut Down buttons
- Full UI on the main monitor only; the others show the wallpaper and clock
- Locked by itself when idle: any key or click unlocks during the first 15 seconds (`Config.graceSeconds`).
  Locked by you ($mod+CTRL+q, a hot corner, the Apple menu) or before sleep: the password is asked right away

## Settings

Set in System Settings (Lock Screen, Wallpaper, Displays → main display), saved in
`~/.config/system-settings/settings.json` and read through `Settings` (`shell-common`, linked here as `common`)
by `Config.qml`, which holds the defaults: message, grace period, main monitor, wallpaper. Picture, layout names
and the session the login screen starts are set in `Config.qml` itself.

Auto-lock, display sleep and locking before sleep are hypridle's (`~/.config/hypr/hypridle.conf`, written by
System Settings → Lock Screen).

## Lock screen

Started from `hyprland.lua` (`qs -p ~/.config/lockscreen`). Lock with $mod+CTRL+q, or:

```sh
qs -p ~/.config/lockscreen ipc call lock lock          # when idle (hypridle): the grace period applies
qs -p ~/.config/lockscreen ipc call lock lockNow       # password right away: a lock you asked for
qs -p ~/.config/lockscreen ipc call lock lockForSleep  # password right away, and locked at once: no pictures
                                                       # of the desktop are taken first (before sleep)
```

Before sleep, hypridle (`inhibit_sleep = 3` in `hypridle.conf`) holds the sleep back until the screen really is
locked, so the desktop can't show for a moment when the lid opens again.

The password is checked by PAM with the system's `/etc/pam.d/login` rules, so faillock lockouts apply.
Pictures of the desktop for the slide-up are kept in `$XDG_RUNTIME_DIR/lockscreen` while locked and
deleted after unlocking. The lock screen itself is only built while locked (a `Loader` in `shell.qml`), so most of
its memory is given back after unlocking. Some video memory (roughly 100 MB, more with more or larger displays)
stays with the process after the first lock: Qt and the graphics driver keep it even once the lock windows are
gone, and only the process ending returns it.

If the lock screen ever crashes while locked, Hyprland shows a red screen. Switch to another TTY
(Ctrl+Alt+F3), log in and run:

```sh
hyprctl --instance 0 dispatch exec "qs -p ~/.config/lockscreen"
hyprctl --instance 0 dispatch exec "qs -p ~/.config/lockscreen ipc call lock lockNow"
```

then go back to Hyprland's TTY (`allow_session_lock_restore` in `hyprland.lua` lets it take over).

## Login screen

`greeter.qml` runs under greetd inside a minimal Hyprland (`system/greetd/hyprland.lua`). It signs in your
account and starts `Config.session` (`start-hyprland`). Install or update it with:

```sh
sudo /usr/local/libexec/desktop-helpers/greetd-install [wallpaper]
```

or System Settings → Lock Screen → Login screen → Update, which asks for an administrator's password. The
helper is `system/greetd-install.sh`, installed root-owned by `sudo sh system/install.sh`.

The greeter user can't read your home folder, so the helper copies these files, the wallpaper and `~/.face`
into `/etc/greetd/lockscreen`, reading each of them as you, not as root. Of your settings it takes only what
the login screen needs: the message, the main display, your account's name, and for its Hyprland the displays'
arrangement and the keyboard layouts (`/etc/greetd/greeter-settings.lua`). Run it again after changing anything
here. Media, calendar and notifications aren't shown there, since they belong to your session.
