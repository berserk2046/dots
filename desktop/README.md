# desktop

The desktop, macOS style: the wallpaper and the files and folders of `~/Desktop`, on every display, under
the windows and on every workspace. Built with Quickshell.

- Folders, files, image thumbnails and `.desktop` shortcuts (shown with their app's name and icon), with icons
  from your icon theme
- A shortcut starts its app only once you've allowed it: right-click → **Allow Launching** (it marks the file as
  a program, like GNOME does). Until then a `.desktop` file is shown as the plain file it is and opens in an
  editor, so one that arrived with a download can't pass for a document and run something
- Click to select, Ctrl or Shift-click to add, drag on empty space to select several
- Drag items to arrange them, also onto another display. It's a real drag and drop, so items can also be
  dropped on the Dock (an app opens them, the Trash trashes them) or into a file manager window
- Double-click or Return opens (with your default apps; shortcuts start their app), F2 renames, Delete moves
  to the Trash, Ctrl+A selects all, Esc clears the selection
- Right-click an item: Open, Rename, Allow Launching (shortcuts), Move to Trash. Right-click the desktop: New Folder, Sort by Name /
  Kind / Date Modified (lines up that display's items once, from the top right corner), Open Desktop Folder, Change Wallpaper…, Desktop Settings…
- Files dragged in from a file manager are copied to `~/Desktop`, where you dropped them
- Takes the keyboard only after a click on it, and gives it back as soon as the pointer leaves it, so
  windows keep their focus with focus-follows-mouse, and clicking a window always focuses it

## Places on each monitor

Every item remembers its display and its place there, in
`~/.local/state/quickshell/by-shell/desktop/layout.json`.

- Displays are told apart by make, model and serial number (Hyprland's monitor description), so a monitor gets
  its own arrangement back whenever it's connected, on any port. A display without a serial number (like most
  built-in screens) is told apart by its port too.
- While a display is disconnected, its items show on the main display (System Settings → Displays, or the
  leftmost one) in free places, and go back when it's connected again.
- Places are grid cells, counted from the top right corner as on macOS, so a new resolution or icon size
  doesn't scatter them. An item whose cell doesn't fit right now shows in the nearest free one, without losing
  its place.
- Items are told apart by inode, so a file renamed anywhere keeps its place; and by name, so does a file an
  editor saves by replacing it. New items take the first free cell on the main display.

## The wallpaper

By default the desktop also draws the wallpaper, and hyprpaper doesn't run: one process for both instead of
two, which typically uses less memory than icons plus hyprpaper. It shows the copies of the
picture that System Settings' `wallpaper.py` makes at each display's exact size (listed in
`~/.local/state/system-settings/wallpapers/index.json`), and asks `wallpaper.py` for one when a display has
none. Without System Settings it decodes the picture itself, at the display's size.

System Settings → Wallpaper → **Draw the wallpaper with the desktop** turns this off; then hyprpaper draws it
and the desktop only shows icons above it. If the desktop crashes, the wallpaper is gone until Quickshell
restarts it (a second or so); with hyprpaper it isn't.

## Run

Inside `desktop-shell`, which loads `DesktopShell.qml`. With **Draw the wallpaper with the desktop** off and
**Show items** off, it draws nothing.

## Configure

System Settings → Desktop & Dock → Desktop: show items, icon size, grid spacing, text size. Saved under
`desktop` in `~/.config/system-settings/settings.json` (`showIcons`, `drawWallpaper`, `iconSize`,
`gridSpacing`, `textSize`; `folder` for another folder than `~/Desktop`).

## Files

- `DesktopShell.qml` the folder, the places on each display, file actions
- `DesktopWindow.qml` one display: wallpaper, icons, selection, dragging, renaming, menus
- `desktop-list.py` lists the folder (GIO: file types, icons, shortcuts' names), only when it changes
- Settings, light or dark and the displays' identities come from `shell-common`
