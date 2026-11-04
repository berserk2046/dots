# app-switcher

A macOS-style window switcher (Alt+Tab) for Quickshell on Hyprland.

- **Alt+Tab** switches to the previous window right away. Keep Alt down to see every window, press Tab
  again (or Shift+Tab, the arrows, or h/j/k/l) to move, and let go of Alt to switch
- While it's open: **Return** switches, **Esc** cancels, **Q** closes the selected window (the switcher
  stays open). Click a window to switch to it; middle-click or its × button closes it
- Most recently used first, from every workspace and display; switching to a window on another workspace
  goes there
- Hidden windows (the title bar's yellow button, `$mod+Shift+minus`) are listed last, marked Hidden, and
  come back onto the current workspace when picked
- Window previews, or large app icons like macOS's Cmd+Tab (System Settings → Desktop & Dock → Window
  Switcher)
- Frosted glass in the Dock's colors, light or dark following System Settings → Appearance; SF Pro
- Many windows shrink the tiles to fit, then wrap onto more rows

Uses Quickshell built-ins (Hyprland IPC, global shortcuts, toplevel capture for the previews) and `hyprctl`.

## How the keys work

Hyprland owns the keys, in `hypr/hyprland.lua` (search for "Window switcher"). Alt+Tab enters the
`App Switcher` submap (the name waybar's submap module shows), so the focused app never sees the keys while
the switcher is open, and each key reaches the switcher as a global shortcut,
`hl.dsp.global("app-switcher:<action>")`. A timer in `hyprland.lua` notices Alt being let go
(`hl.is_key_down`), leaves the submap and sends `commit`; if that commit is ever lost, the switcher
commits by itself once it sees the submap end. The panel appears 90 ms after Alt+Tab, so a quick Alt+Tab
switches without flashing it.

The actions can also be called from a shell, which is handy for scripts or other bindings:

```sh
qs -p ~/.config/app-switcher ipc call switcher next      # also: previous left right up down commit cancel close
```

## Run

Started from `hyprland.lua` with the rest of the desktop:

```lua
hl.on("hyprland.start", function()
    hl.exec_cmd("qs -p ~/.config/app-switcher")
end)
```

## Configure

- System Settings → Desktop & Dock → Window Switcher: previews or icons, and windows from all workspaces
  or only the current one. Saved under `switcher` in `~/.config/system-settings/settings.json`
  (`previews`, `scope`: `"all"` or `"workspace"`) and read by `Settings.qml`; changes apply right away.
- Keys: the "Window switcher" block in `hyprland.lua`.
- Colors and font: `Theme.qml`. Tile sizes, spacing and the radius: the top of `Switcher.qml`.
- Icon theme: the `//@ pragma IconTheme` line in `shell.qml`, which System Settings → Appearance rewrites.

Live reload is off for this shell (`settings.watchFiles` in `shell.qml`). After editing it, restart it:
`qs kill -p ~/.config/app-switcher; qs -p ~/.config/app-switcher -d`.
