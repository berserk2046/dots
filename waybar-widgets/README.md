# waybar-widgets

macOS Control Center style dropdowns for waybar's `network`, `pulseaudio`, `bluetooth`, `battery`,
`custom/system`, `backlight`, `custom/power` and `custom/date` modules, built with Quickshell. They share sway-dock's look.

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
- Spotify item on the bar: a larger Now Playing card; click the title or artist to open them in Spotify. Shows the previous and next song once logged in to the Web API (see `spotify-queue.py`)
- Per-app volume for everything playing

**Bluetooth** (`BluetoothPanel.qml`)
- Bluetooth on/off
- Your devices: click to connect or disconnect, spinner while it happens, battery when the device reports it
- Nearby devices (the first six; System Settings lists them all): click to pair and connect, again to cancel.
  While the panel is open it's the pairing agent (`BluetoothPairing.qml`, `bt-agent.py`, shared with System
  Settings), so a code to confirm or a PIN to type shows up inline (`PairingPrompt.qml`). A device is trusted
  only once you've confirmed its code, and one you haven't paired has to ask before using a service
- Bluetooth Settings… opens System Settings → Bluetooth

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
- CPU: usage graph (system red, user blue, like Activity Monitor), per-core bars, load, CPU and GPU temperature
- Memory: used (colored by pressure) and cached, memory pressure, swap
- Storage: per disk, a bar with available and total space
- Top processes by CPU, helper processes counted as their app (e.g. Firefox)

**Display** (`DisplayPanel.qml`, `Display.qml`) for the `backlight` module, like Control Center's Display
- Brightness (brightnessctl), following changes made elsewhere while open
- Night Shift on/off ("until turned off"), the moon turns blue while it's on (by hand or by schedule)
- Schedule Off / Custom, with From and To time steppers (30 minutes; arrows or scroll)
- Color temperature, Less Warm to More Warm (6500 K to 2500 K)
- Display Settings… opens System Settings → Displays (`SettingsLink.qml`, shared with Bluetooth)
- Night Shift shares System Settings' values (`displays.nightShift` in its `settings.json`) and is applied
  the same way: `~/.config/hypr/hyprsunset.conf` is rewritten, hyprsunset restarted, and `night_shift` in
  `~/.config/hypr/system-settings.lua` updated so it starts again at login

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

Battery and system data are polled only while one of the two panels is open: `sys-status.sh` every 2 seconds
(CPU, memory, battery and every process's CPU time from sysfs and `/proc`, with shell built-ins only, so it
starts no programs), `sys-info.sh` on opening and every 30 seconds (disks, energy mode, charge limit). The CPU
graph keeps reading `/proc/stat` in the background (every 10 seconds while closed), without starting a program.

Wi-Fi goes through `wpa_cli` (no root: the control socket is group `wheel`) and changes are saved with
`save_config` (needs `update_config=1`, already set). A new network's password goes from the panel to
`wifi-join.py` on its input and from there straight to wpa_supplicant's socket, never as an argument of a
command (where any user could read it in the process list). IP addressing is left to `dhcpcd`. Ethernet changes
and the rfkill fallback run the root-owned helper `/usr/local/libexec/desktop-helpers/net-admin`
(`system/net-admin.sh`) through `pkexec`, which asks for an administrator's password. Manual IPv4 settings are written as a marked
`# >>> waybar-widgets <iface>` block at the end of `/etc/dhcpcd.conf`, with a one-time backup at
`/etc/dhcpcd.conf.waybar-widgets.bak`. Sound uses Quickshell's PipeWire, MPRIS and Bluetooth services.
No extra packages are needed.

## Run

The panels run inside `desktop-shell`, which loads `WidgetsShell.qml`. One window shows whichever panel is open,
and a panel only exists while it's open: it's built when its icon is clicked and thrown away once closed, so the
panels cost nothing at login or while closed. waybar's `on-click` runs
`~/.config/waybar-widgets/toggle.sh wifi|volume|bluetooth|battery|system|display|power|date|media`.

IPC: `qs -p ~/.config/desktop-shell ipc call panel toggle|open <name>`, `panel toggleAt <name> <x> <y>`,
`panel close`.

The card opens under the pointer, so under the icon you clicked. Esc or a click outside closes it.

System Settings (`~/.config/system-settings`) imports this folder and shows the Wi-Fi, Sound and Battery panels
as its panes (`WifiPanel`'s `showWifi` / `showEthernet` split Wi-Fi from the Network pane). Scripts are found next
to the QML files, so they work from either shell. Its Control Center pane picks the waybar modules and the clock.

## Configure

- Colors, font (`SF Pro Text`), glyphs and width: `Theme.qml`; `fontScale` there multiplies every text size
  (System Settings sets its own in its `shell.qml`)
- Wi-Fi interface: `wifiInterface` on `Network` in `WidgetsShell.qml` (empty picks the first wireless one)
- Profile picture: any square image at `~/.face` (`cp picture.png ~/.face`); it's re-read each time
  the power menu opens. Your full name comes from the account's GECOS field (System Settings → Users & Groups)
- Position fallback when the pointer can't be read: `fallbackRightMargin` in `Popup.qml`
