# waybar-widgets

macOS Control Center style dropdowns for waybar's `network`, `pulseaudio`, `battery`,
`custom/system`, `custom/power` and `custom/date` modules, built with Quickshell. They share sway-dock's look.

**Wi-Fi** (`WifiPanel.qml`, `Network.qml`)
- Wi-Fi on/off (rfkill) and the interface name in the header
- Joined network with details: IP/IPv6, router, DNS, signal, channel, security, BSSID; Disconnect / Forget
- Known networks in range (click to join, ⓘ or right-click to forget) and other networks with
  signal and lock icons; secured ones ask for the password inline. Wrong passwords are detected and the
  half-added network is removed again
- Other Network… for hidden SSIDs
- Ethernet: link state, speed, IP, MAC, router; DHCP or manual IPv4 (address/prefix, router, DNS),
  Renew Lease, Turn On/Off

**Sound** (`AudioPanel.qml`)
- Output and input volume (click the icon to mute), live input level
- Pick the output/input device; paired Bluetooth speakers/headphones that aren't connected are
  listed too and connect on click
- Now Playing for MPRIS players: art, title, artist, previous/play/next, click the bar to seek
- Per-app volume for everything playing

**Battery** (`BatteryPanel.qml`, `System.qml`)
- Level, power source, and time remaining or until full (from the averaged power draw)
- Battery health: condition, maximum capacity (full charge vs. design), cycle count
- State, power draw / charging rate, charge in Wh, voltage, model
- Energy Mode (Low Power / Automatic / High Power), read from power-profiles-daemon and set with
  `powerprofilesctl set`
- Battery Conservation: UPower's charge limit (`EnableChargeThreshold`), which on IdeaPads is conservation
  mode. No root needed (polkit allows the active session) and UPower restores it after a reboot
- Using Significant Energy: apps above 10% CPU right now

**System** (`SystemPanel.qml`, `System.qml`) for the combined CPU + RAM module (`waybar-system.sh`)
- CPU: usage graph (system red, user blue, like Activity Monitor), per-core bars, temperature, load
- Memory: used (colored by pressure) and cached, memory pressure, swap
- Storage: per disk, a bar with available and total space
- Top processes by CPU, helper processes counted as their app (e.g. Firefox)

**Power** (`PowerPanel.qml`), like the Apple menu
- Your name (or user), hostname and uptime, with your picture from `~/.face` (initials otherwise)
- Sleep (locks with the lock screen first), Restart…, Shut Down…, Lock Screen, Log Out…
- Restart, Shut Down and Log Out ask first with macOS's 60 second countdown; Cancel, Esc or closing the
  card stops it. Commands (`systemctl`/`loginctl`, no sudo) are in `commands` at the top of the file

**Date** (`DatePanel.qml`, `Calendars.qml`, `calendar-sync.py`), like macOS Calendar
- Large clock and full date
- Month view: today in a red circle, weekends dimmed, a colored dot per calendar with events that day
- Week view: hour grid with event blocks (overlaps side by side), all-day row, red current-time line
- Arrows, Today or the scroll wheel move through months/weeks; click a day to list its events with
  time and location, plus its week number and day of the year

### Calendar events (Google Calendar or any iCal feed)

Read-only, no extra packages or Google sign-in. For each calendar:
1. Google Calendar on the web → Settings → your calendar under "Settings for my calendars" →
   "Integrate calendar" → copy **Secret address in iCal format**
2. Add it as a line to `~/.config/waybar-widgets-calendars.conf` (kept outside this folder, since the
   address gives read access to the calendar): `<url> [#rrggbb] [name]`, e.g.
   ```
   https://calendar.google.com/calendar/ical/.../basic.ics #0a84ff Personal
   ```
   then `chmod 600 ~/.config/waybar-widgets-calendars.conf`

Calendars sync when the panel opens and every 10 minutes while it's open; downloads are cached in
`~/.cache/waybar-widgets/calendars` (private) and reused for 10 minutes or when offline. Google can take
a few hours to reflect changes in the iCal feed. Repeating events use python-dateutil (already installed
as a matplotlib dependency); without it they show only their first occurrence. If an address leaks,
use "Reset" next to it in Google's settings.

Battery and system data come from sysfs, `/proc`, `df` and `top` (`sys-status.sh`), polled only while
one of the two panels is open; the CPU graph keeps sampling `/proc/stat` in the background.

Wi-Fi goes through `wpa_cli` (no root: the control socket is group `wheel`) and changes are saved with
`save_config` (needs `update_config=1`, already set). IP addressing is left to `dhcpcd`. Ethernet changes
and the rfkill fallback run `net-admin.sh` through `sudo -n`. Manual IPv4 settings are written as a marked
`# >>> waybar-widgets <iface>` block at the end of `/etc/dhcpcd.conf`, with a one-time backup at
`/etc/dhcpcd.conf.waybar-widgets.bak`. Sound uses Quickshell's PipeWire, MPRIS and Bluetooth services.
No extra packages are needed.

## Run

waybar's `on-click` runs `~/.config/waybar-widgets/toggle.sh wifi|volume|battery|system|power|date`, which starts the
shell on the first click.
To start it with Hyprland instead (in `hyprland.lua`):

```lua
hl.on("hyprland.start", function()
    hl.exec_cmd("qs -p ~/.config/waybar-widgets")
end)
```

IPC: `qs -p ~/.config/waybar-widgets ipc call wifi|volume|battery|system|power|date toggle|open|close`

The card opens under the pointer, so under the icon you clicked. Esc or a click outside closes it.

System Settings (`~/.config/system-settings`) imports this folder and shows the Wi-Fi, Sound and Battery panels
as its panes (`WifiPanel`'s `showWifi` / `showEthernet` split Wi-Fi from the Network pane). Scripts are found next
to the QML files, so they work from either shell. Its Control Center pane picks the waybar modules and the clock.

## Configure

- Colors, font (`SF Pro`), glyphs and width: `Theme.qml`
- Wi-Fi interface: `wifiInterface` on `Network` in `shell.qml` (empty picks the first wireless one)
- Profile picture: any square image at `~/.face` (`cp picture.png ~/.face`); it's re-read each time
  the power menu opens. Your full name comes from the account's GECOS field (`sudo chfn -f "Name" $USER`)
- Position fallback when the pointer can't be read: `fallbackRightMargin` in `Popup.qml`
