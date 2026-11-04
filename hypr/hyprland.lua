-- Hyprland config
-- Reference: https://wiki.hypr.land/Configuring/Start/
-- API stubs for editor completion: /usr/share/hypr/stubs/hl.meta.lua


-------------------
---- VARIABLES ----
-------------------

-- Values set in the System Settings app (~/.config/system-settings), which writes them to
-- system-settings.lua next to this file. Anything it hasn't set falls back to the defaults here.
local S = {}
do
    local ok, settings = pcall(dofile, os.getenv("HOME") .. "/.config/hypr/system-settings.lua")
    if ok and type(settings) == "table" then
        S = settings
    end
end
local function pick(value, default)
    if value == nil then
        return default
    end
    return value
end

-- Logo key
local mod = "SUPER"
-- Home row direction keys, like vim
local left  = "h"
local down  = "j"
local up    = "k"
local right = "l"
-- Your preferred terminal emulator
local term = pick(S.terminal, "foot")
-- Your preferred application launcher
local menu = "fuzzel --icon-theme=" .. pick(S.icon_theme, "MacTahoe-dark")

-- Color scheme
local ac = "rgb(07a6c5)"
local ab = "rgb(202020)"
local bg = "rgb(595959)"
local uf = "rgb(94a3ad)"
local bi = "rgb(37474f)"
local ta = "rgb(ffffff)"


------------------
---- MONITORS ----
------------------

-- Every output at its preferred mode, laid out automatically.
-- Pin positions per output if you want, e.g.:
-- hl.monitor({ output = "HDMI-A-1", mode = "1920x1200", position = "1920x0", scale = 1 })
-- Output names: hyprctl monitors
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = 1,
})

-- Per-monitor layout from System Settings → Displays
for _, m in ipairs(S.monitors or {}) do
    hl.monitor(m)
end


-------------------
---- AUTOSTART ----
-------------------

hl.on("hyprland.start", function()
    -- Wallpaper (~/.config/hypr/hyprpaper.conf, written by System Settings → Wallpaper)
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("waybar")
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("qs -p ~/.config/sway-dock")
    -- Window switcher (Alt+Tab)
    hl.exec_cmd("qs -p ~/.config/app-switcher")
    -- Lock screen and notifications
    hl.exec_cmd("qs -p ~/.config/lockscreen")
    -- Load plugins enabled with hyprpm (hyprbars)
    hl.exec_cmd("hyprpm reload -n")
    -- Auto-lock, display sleep and lock before sleep (~/.config/hypr/hypridle.conf, System Settings → Lock Screen)
    hl.exec_cmd("hypridle")
    -- Night Shift (~/.config/hypr/hyprsunset.conf, System Settings → Displays)
    if pick(S.night_shift, false) then
        hl.exec_cmd("hyprsunset")
    end
    -- System Settings → General → Login Items
    for _, cmd in ipairs(S.login_items or {}) do
        hl.exec_cmd(cmd)
    end
end)


-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

-- Qt apps follow the GTK theme and light/dark (System Settings → Appearance)
hl.env("QT_QPA_PLATFORMTHEME", "gtk3")
hl.env("XCURSOR_SIZE", tostring(pick(S.cursor_size, 24)))
hl.env("HYPRCURSOR_SIZE", tostring(pick(S.cursor_size, 24)))
if S.cursor_theme then
    hl.env("XCURSOR_THEME", S.cursor_theme)
    hl.env("HYPRCURSOR_THEME", S.cursor_theme)
end


-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config({
    general = {
        gaps_in  = pick(S.gaps_in, 0),
        gaps_out = pick(S.gaps_out, 0),

        border_size = pick(S.border_size, 1),

        col = {
            active_border   = bg,
            inactive_border = ab,
        },

        resize_on_border = false,
        allow_tearing    = false,

        layout = "dwindle",
    },

    decoration = {
        rounding       = pick(S.rounding, 10),
        rounding_power = 2,

        active_opacity   = 1.0,
        inactive_opacity = 1.0,

        shadow = {
            enabled      = true,
            range        = 4,
            render_power = 3,
            color        = 0xee1a1a1a,
        },

        blur = {
            enabled  = true,
            -- Strong enough to read as frosted glass behind see-through surfaces (System Settings' sidebar)
            size     = 8,
            passes   = 3,
            vibrancy = 0.1696,
        },
    },

    animations = {
        enabled = true,
    },
})

hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1}    } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1}    } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}       } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1}    } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}     } })
hl.curve("easy",           { type = "spring", mass = 1, stiffness = 238.1191, dampening = 24.21279333 })

hl.animation({ leaf = "global",        enabled = true,  speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true,  speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true,  speed = 4.79, spring = "easy" })
hl.animation({ leaf = "windowsIn",     enabled = true,  speed = 4.1,  spring = "easy",         style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true,  speed = 1.49, bezier = "linear",       style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true,  speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true,  speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true,  speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true,  speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true,  speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true,  speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true,  speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true,  speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = true,  speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn",  enabled = true,  speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true,  speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "zoomFactor",    enabled = true,  speed = 7,    bezier = "quick" })

hl.config({
    dwindle = {
        preserve_split = true, -- needed for togglesplit
    },
})

-- Tabbed groups ($mod+w): a tab bar with titles above the windows, the active tab in the accent color
hl.config({
    group = {
        col = {
            border_active   = ac,
            border_inactive = bi,
        },

        groupbar = {
            font_family          = "SF Pro Text",
            font_size            = 11,
            font_weight_active   = "semibold",
            font_weight_inactive = "normal",
            height               = 22,
            indicator_height     = 0,
            gradients            = true,
            gradient_rounding    = 6,
            gradient_round_only_edges = false,
            gaps_in              = 3,
            gaps_out             = 3,
            text_color           = ta,
            text_color_inactive  = uf,

            col = {
                active   = ac,
                inactive = bi,
            },
        },
    },
})


----------------
----  MISC  ----
----------------

hl.config({
    misc = {
        force_default_wallpaper  = 0,
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
        -- Lets a restarted lock screen take over if it ever crashes while locked
        allow_session_lock_restore = true,
        -- A display turned off when idle (hypridle) or by a hot corner wakes on input
        mouse_move_enables_dpms = true,
        key_press_enables_dpms   = true,
    },

    -- Don't move the pointer when focus changes
    cursor = {
        no_warps = true,
    },

    -- Focus left/right walks through the tabs of a group first
    binds = {
        movefocus_cycles_groupfirst = true,
    },
})


---------------
---- INPUT ----
---------------

hl.config({
    input = {
        kb_layout  = pick(S.kb_layout, "us,latam"),
        kb_variant = pick(S.kb_variant, ""),

        repeat_rate  = pick(S.repeat_rate, 25),
        repeat_delay = pick(S.repeat_delay, 600),

        -- Focus on click, not on hover
        follow_mouse = pick(S.follow_mouse, 0),

        sensitivity    = pick(S.sensitivity, 0),
        natural_scroll = pick(S.mouse_natural_scroll, false),

        touchpad = {
            natural_scroll       = pick(S.natural_scroll, false),
            tap_to_click         = pick(S.tap_to_click, true),
            disable_while_typing = pick(S.disable_while_typing, true),
        },
    },
})


---------------------
---- KEYBINDINGS ----
---------------------

-- Basics
hl.bind(mod .. " + Return", hl.dsp.exec_cmd(term), { description = "Open a terminal" })
hl.bind(mod .. " + i",      hl.dsp.exec_cmd(term .. " yazi ~"), { description = "Open the file manager (yazi)" })
hl.bind(mod .. " + q",      hl.dsp.window.close(), { description = "Close the window" })
hl.bind(mod .. " + p",      hl.dsp.exec_cmd(menu), { description = "Open the app launcher" })
hl.bind(mod .. " + u",      hl.dsp.exec_cmd("hyprctl switchxkblayout all next"), { description = "Switch keyboard layout" })

hl.bind(mod .. " + SHIFT + r", hl.dsp.exec_cmd("hyprctl reload"), { description = "Reload Hyprland's config" })
-- Asks first: pick "Exit Hyprland" in fuzzel to end the session
hl.bind(mod .. " + SHIFT + e", hl.dsp.exec_cmd(
    [[[ "$(printf 'Cancel\nExit Hyprland\n' | fuzzel --dmenu --prompt 'End your Wayland session? ')" = "Exit Hyprland" ] && hyprctl dispatch 'hl.dsp.exit()']]
), { description = "Log out" })

-- Lock the screen (Ctrl+Cmd+Q on macOS)
hl.bind(mod .. " + CTRL + q", hl.dsp.exec_cmd("qs -p ~/.config/lockscreen ipc call lock lock"), { description = "Lock the screen" })

-- Notification Center
hl.bind(mod .. " + n", hl.dsp.exec_cmd("qs -p ~/.config/lockscreen ipc call notifications toggle"), { description = "Show the Notification Center" })

-- Window switcher (Alt+Tab), drawn by ~/.config/app-switcher (Quickshell). Hold Alt and press Tab
-- (Shift+Tab, the arrows or hjkl) to pick a window; let go of Alt to switch to it. While it's open,
-- Esc cancels, Return switches and Q closes the selected window. Its keys live in the "App Switcher"
-- submap (the name waybar shows), so the focused app never sees them, and reach the switcher as global
-- shortcuts.
do
    local submap = "App Switcher"

    local function send(action)
        hl.dispatch(hl.dsp.global("app-switcher:" .. action))
    end

    local function altDown()
        return hl.is_key_down("Alt_L") or hl.is_key_down("Alt_R")
    end

    -- Letting go of Alt switches. Checked every few milliseconds while the switcher is open. (Not a
    -- release bind: a global sent from a key release reaches the switcher as "released", which it
    -- ignores, so the panel would stay open.)
    local watch = nil

    local function finish(action)
        if watch ~= nil then
            watch:set_enabled(false)
        end
        if hl.get_current_submap() == submap then
            hl.dispatch(hl.dsp.submap("reset"))
        end
        send(action)
    end

    local function open(action)
        send(action)
        if hl.get_current_submap() ~= submap then
            hl.dispatch(hl.dsp.submap(submap))
        end
        -- Always watched, even when Alt is already up again (a very fast Alt+Tab): then the next
        -- check switches right away
        if watch == nil then
            watch = hl.timer(function()
                if not altDown() then
                    finish("commit")
                end
            end, { timeout = 15, type = "repeat" })
        else
            watch:set_enabled(true)
        end
    end

    hl.bind("ALT + Tab",         function() open("next") end,     { description = "Switch windows" })
    hl.bind("ALT + SHIFT + Tab", function() open("previous") end, { description = "Switch windows, backwards" })

    hl.define_submap(submap, function()
        local moves = {
            { "Tab",         "next"     },
            { "SHIFT + Tab", "previous" },
            { "left",  "left"  }, { left,  "left"  },
            { "right", "right" }, { right, "right" },
            { "up",    "up"    }, { up,    "up"    },
            { "down",  "down"  }, { down,  "down"  },
        }
        for _, m in ipairs(moves) do
            local action = m[2]
            hl.bind("ALT + " .. m[1], function() send(action) end, { repeating = true, description = "Window switcher: " .. action })
        end
        hl.bind("ALT + q",      function() send("close") end,     { description = "Window switcher: close the window" })
        hl.bind("ALT + Return", function() finish("commit") end,  { description = "Window switcher: switch" })
        hl.bind("ALT + Escape", function() finish("cancel") end,  { description = "Window switcher: cancel" })
        hl.bind("Escape",       function() finish("cancel") end,  { description = "Window switcher: cancel" })
    end)
end

-- Drag windows with $mod + left mouse, resize with $mod + right mouse
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true, description = "Move a window with the mouse" })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "Resize a window with the mouse" })

-- Moving around: focus with $mod + hjkl/arrows, move with $mod + SHIFT + hjkl/arrows
local directions = {
    { left,  "left",  "left"  },
    { down,  "down",  "down"  },
    { up,    "up",    "up"    },
    { right, "right", "right" },
}
for _, d in ipairs(directions) do
    local vimKey, arrowKey, dir = d[1], d[2], d[3]
    hl.bind(mod .. " + " .. vimKey,              hl.dsp.focus({ direction = dir }), { description = "Focus the window " .. dir })
    hl.bind(mod .. " + " .. arrowKey,            hl.dsp.focus({ direction = dir }), { description = "Focus the window " .. dir })
    hl.bind(mod .. " + SHIFT + " .. vimKey,      hl.dsp.window.move({ direction = dir }), { description = "Move the window " .. dir })
    hl.bind(mod .. " + SHIFT + " .. arrowKey,    hl.dsp.window.move({ direction = dir }), { description = "Move the window " .. dir })
end

-- Monitors
hl.bind(mod .. " + period",         hl.dsp.focus({ monitor = "right" }), { description = "Focus the display on the right" })
hl.bind(mod .. " + comma",          hl.dsp.focus({ monitor = "left" }), { description = "Focus the display on the left" })
hl.bind(mod .. " + SHIFT + period", hl.dsp.window.move({ monitor = "right", follow = false }), { description = "Move the window to the display on the right" })
hl.bind(mod .. " + SHIFT + comma",  hl.dsp.window.move({ monitor = "left",  follow = false }), { description = "Move the window to the display on the left" })

-- Workspaces 1-10
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mod .. " + " .. key,         hl.dsp.focus({ workspace = i }), { description = "Go to workspace " .. i })
    hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i, follow = false }), { description = "Move the window to workspace " .. i })
end

-- Layout stuff
-- Choose where the next tiled window opens: right of or below the focused one
hl.bind(mod .. " + b", hl.dsp.layout("preselect r"), { description = "Open the next tiled window to the right" })
hl.bind(mod .. " + v", hl.dsp.layout("preselect d"), { description = "Open the next tiled window below" })
hl.bind(mod .. " + e", hl.dsp.layout("togglesplit"), { description = "Toggle the split direction" })
-- Tabbed groups: windows share one spot, switch with the tab bar or focus left/right
hl.bind(mod .. " + w", hl.dsp.group.toggle(), { description = "Toggle tabbed group" })
hl.bind(mod .. " + s", hl.dsp.group.toggle(), { description = "Toggle tabbed group" })

hl.bind(mod .. " + f",             hl.dsp.window.fullscreen(), { description = "Fullscreen" })
hl.bind(mod .. " + SHIFT + space", hl.dsp.window.float(), { description = "Toggle floating" })

-- Swap focus between the tiling area and the floating area
hl.bind(mod .. " + space", function()
    local win = hl.get_active_window()
    if win ~= nil and win.floating then
        hl.dispatch(hl.dsp.window.cycle_next({ tiled = true }))
    else
        hl.dispatch(hl.dsp.window.cycle_next({ floating = true }))
    end
end, { description = "Switch between tiled and floating windows" })

-- Scratchpad
hl.bind(mod .. " + SHIFT + minus", hl.dsp.window.move({ workspace = "special:scratchpad", follow = false }), { description = "Hide the window (scratchpad)" })
hl.bind(mod .. " + minus",         hl.dsp.workspace.toggle_special("scratchpad"), { description = "Show hidden windows (scratchpad)" })

-- Resize mode
hl.bind(mod .. " + r", hl.dsp.submap("resize"), { description = "Resize mode" })
hl.define_submap("resize", function()
    local resizes = {
        { left,  "left",  -10,   0 }, -- shrink width
        { down,  "down",    0,  10 }, -- grow height
        { up,    "up",      0, -10 }, -- shrink height
        { right, "right",  10,   0 }, -- grow width
    }
    for _, r in ipairs(resizes) do
        local vimKey, arrowKey, x, y = r[1], r[2], r[3], r[4]
        hl.bind(vimKey,   hl.dsp.window.resize({ x = x, y = y, relative = true }), { repeating =true, description = "Resize the window" })
        hl.bind(arrowKey, hl.dsp.window.resize({ x = x, y = y, relative = true }), { repeating =true, description = "Resize the window" })
    end

    hl.bind("Return", hl.dsp.submap("reset"), { description = "Leave resize mode" })
    hl.bind("escape", hl.dsp.submap("reset"), { description = "Leave resize mode" })
end)

-- Volume via PulseAudio
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("pactl set-sink-mute @DEFAULT_SINK@ toggle"),     { locked = true, description = "Mute" })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("pactl set-sink-volume @DEFAULT_SINK@ -5%"),      { locked = true, repeating = true, description = "Volume down" })
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("pactl set-sink-volume @DEFAULT_SINK@ +5%"),      { locked = true, repeating = true, description = "Volume up" })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("pactl set-source-mute @DEFAULT_SOURCE@ toggle"), { locked =true, description = "Mute the microphone" })

-- Media via playerctl
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked =true, description = "Play / pause" })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked =true, description = "Play / pause" })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true, description = "Previous track" })
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true, description = "Next track" })
hl.bind("XF86AudioStop",  hl.dsp.exec_cmd("playerctl stop"),       { locked = true, description = "Stop playback" })

-- Brightness via brightnessctl
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"), { locked = true, repeating =true, description = "Brightness down" })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl set 5%+"), { locked = true, repeating =true, description = "Brightness up" })

-- Screenshot
-- Screenshots (hyprshot): Print copies the focused display to the clipboard, $mod+Print saves it to a file
-- (~/Pictures by default, $HYPRSHOT_DIR), $mod+Shift+S copies a region you drag out
hl.bind("Print", hl.dsp.exec_cmd("hyprshot -m active -m output --clipboard-only"), { description = "Screenshot cbonly" })
hl.bind(mod .. " + Print", hl.dsp.exec_cmd("hyprshot -m active -m output"), { description = "Screenshot" })
hl.bind(mod .. " + SHIFT + s", hl.dsp.exec_cmd("hyprshot -m region --clipboard-only"), {description = "Region Screenshot cbonly" })


--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

if pick(S.float_by_default, true) then
    hl.window_rule({
        -- Windows open floating and centered, like on macOS; $mod+SHIFT+space tiles one
        name  = "float-by-default",
        match = { class = ".*" },

        float  = true,
        center = true,
    })
end

hl.window_rule({
    -- Ignore maximize requests from apps
    name  = "suppress-maximize-events",
    match = { class = ".*" },

    suppress_event = "maximize",
})

hl.window_rule({
    -- Fix some dragging issues with XWayland
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },

    no_focus = true,
})


-- Floating windows reopen at the size you last gave them, like on macOS.
-- Resize a floating window and close it: that size is saved for the app. Next time the app opens
-- floating, or you float it with $mod+SHIFT+space, it gets that size back, centered.
-- Dialogs are left alone: only an app's first window, or one you float yourself, is restored or saved.
-- Saved in ~/.local/state/hypr-float-sizes.tsv; delete the file to forget every size.
do
    local stateDir = os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")
    local path     = stateDir .. "/hypr-float-sizes.tsv"
    local maxSaved = 100   -- the least recently used apps are forgotten past this
    local minSide  = 150   -- don't remember anything smaller than this

    -- Lines of "width<TAB>height<TAB>app class", most recently used first. Read as plain data:
    -- window classes come from apps, so this file is never run as code.
    local saved, order = {}, {}
    local f = io.open(path, "r")
    if f then
        for line in f:lines() do
            local w, h, class = line:match("^(%d+)\t(%d+)\t([^%c]+)$")
            if class and not saved[class] and #order < maxSaved then
                saved[class] = { tonumber(w), tonumber(h) }
                order[#order + 1] = class
            end
        end
        f:close()
    end

    local function save()
        local tmp = path .. ".tmp"
        local out = io.open(tmp, "w")
        if not out then
            return
        end
        for _, class in ipairs(order) do
            out:write(saved[class][1], "\t", saved[class][2], "\t", class, "\n")
        end
        out:close()
        os.rename(tmp, path)
    end

    -- Windows this applies to, by address: { base = size it had once floating, to tell if you resized it }
    local tracked = {}

    local function classOf(win)
        local class = win.initial_class
        if class == "" or class:find("%c") then
            return nil
        end
        return class
    end

    local function onFloat(win)
        local t = tracked[win.address]
        if t == nil or t.base or win.fullscreen ~= 0 then
            return -- floated before this session: Hyprland keeps its own size and position
        end
        local size = saved[classOf(win) or ""]
        if size then
            -- Never larger than the screen
            local w, h = size[1], size[2]
            local mon = win.monitor
            if mon then
                local scale = mon.scale or 1
                w = math.min(w, math.floor(mon.width / scale))
                h = math.min(h, math.floor(mon.height / scale))
            end
            local target = "address:" .. win.address
            hl.dispatch(hl.dsp.window.resize({ x = w, y = h, window = target }))
            hl.dispatch(hl.dsp.window.center({ window = target }))
            t.base = { w, h }
        else
            t.base = { win.size.x, win.size.y }
        end
    end

    hl.on("window.open", function(win)
        local class = win and classOf(win)
        if class == nil then
            return
        end
        -- Only the app's first window; later ones are usually its dialogs
        for _, other in ipairs(hl.get_windows()) do
            if other.address ~= win.address and other.initial_class == class then
                return
            end
        end
        tracked[win.address] = {}
        if win.floating then
            onFloat(win)
        end
    end)

    hl.on("window.update_state", function(win, changes)
        if win and changes and changes.float == true and classOf(win) then
            -- Floating a window yourself always counts
            tracked[win.address] = tracked[win.address] or {}
            onFloat(win)
        end
    end)

    hl.on("window.close", function(win)
        if win == nil then
            return
        end
        local t = tracked[win.address]
        tracked[win.address] = nil
        local class = classOf(win)
        if t == nil or t.base == nil or class == nil or not win.floating or win.fullscreen ~= 0 then
            return
        end
        local w, h = math.floor(win.size.x), math.floor(win.size.y)
        -- Only sizes you chose: skip windows you never resized
        if w < minSide or h < minSide or (math.abs(w - t.base[1]) < 4 and math.abs(h - t.base[2]) < 4) then
            return
        end
        for i, c in ipairs(order) do
            if c == class then
                table.remove(order, i)
                break
            end
        end
        table.insert(order, 1, class)
        saved[class] = { w, h }
        while #order > maxSaved do
            saved[table.remove(order)] = nil
        end
        save()
    end)
end


-- The menu bar is translucent, like macOS's: blur what's behind it
hl.layer_rule({
    name  = "waybar-blur",
    match = { namespace = "^waybar$" },

    blur = true,
})

-- So is the Dock (light frosted glass in Light mode). Its surface is larger than the bar it draws,
-- so only its visible parts are blurred.
hl.layer_rule({
    name  = "dock-blur",
    match = { namespace = "^sway-dock$" },

    blur         = true,
    ignore_alpha = 0.3,
})

-- The window switcher (Alt+Tab) is frosted glass too. It animates itself, so Hyprland doesn't.
hl.layer_rule({
    name  = "app-switcher-blur",
    match = { namespace = "^app-switcher$" },

    blur         = true,
    ignore_alpha = 0.3,
    no_anim      = true,
})


------------------------------
---- TITLE BARS (hyprbars) ----
------------------------------

-- Install once (needs cmake and meson):
--   hyprpm add https://github.com/hyprwm/hyprland-plugins
--   hyprpm enable hyprbars
-- Hyprland reloads this config after the plugin loads, so this block applies then.
if hl.plugin.hyprbars ~= nil then
    -- Light or dark like apps, following System Settings → Appearance (its appearance.sh writes the
    -- choice to GTK's settings.ini and reloads this config when it switches)
    local light = false
    local ini = io.open(os.getenv("HOME") .. "/.config/gtk-3.0/settings.ini")
    if ini then
        light = ini:read("a"):match("gtk%-application%-prefer%-dark%-theme%s*=%s*0") ~= nil
        ini:close()
    end
    local bar         = light and "rgb(e8e8e8)" or ab
    local barText     = light and "rgb(262626)" or ta
    local barUnfocused     = light and "rgb(f6f6f6)" or bg
    local barTextUnfocused = light and "rgb(a6a6a6)" or uf

    hl.config({
        plugin = {
            hyprbars = {
                bar_height                 = 28,
                bar_color                  = bar,
                col                        = { text = barText },
                bar_text_font              = "SF Pro Text",
                bar_text_size              = 10,
                bar_text_weight            = "medium",
                bar_text_align             = "center",
                bar_buttons_alignment      = "left",
                bar_padding                = 10,
                bar_button_padding         = 8,
                bar_part_of_window         = true,
                bar_precedence_over_border = true,
                icon_on_hover              = true,
                inactive_button_color      = light and "rgb(cdcdcd)" or "rgb(8a8a8a)",
                on_double_click            = [[hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })']],
            },
        },
    })

    -- Traffic lights, left to right: close, hide to the scratchpad ($mod+minus brings it back), maximize
    hl.plugin.hyprbars.add_button({
        bg_color = "rgb(ff5f57)",
        fg_color = "rgba(4d000099)",
        size     = 12,
        icon     = "×",
        action   = "hyprctl dispatch 'hl.dsp.window.close()'",
    })
    hl.plugin.hyprbars.add_button({
        bg_color = "rgb(febc2e)",
        fg_color = "rgba(5c3d0099)",
        size     = 12,
        icon     = "−",
        action   = [[hyprctl dispatch 'hl.dsp.window.move({ workspace = "special:scratchpad", follow = false })']],
    })
    hl.plugin.hyprbars.add_button({
        bg_color = "rgb(28c840)",
        fg_color = "rgba(00400099)",
        size     = 12,
        icon     = "+",
        action   = [[hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })']],
    })

    -- Unfocused windows get a lighter bar with dimmer text
    hl.window_rule({
        name  = "hyprbars-unfocused",
        match = { focus = false },

        ["hyprbars:bar_color"]   = barUnfocused,
        ["hyprbars:title_color"] = barTextUnfocused,
    })

    -- Apps that draw their own title bar (client-side decorations) get no hyprbar.
    -- Add an app here if it shows two title bars; find its class with: hyprctl clients
    local nativeTitleBarApps = {
        "^org\\.gnome\\.",               -- Nautilus, Zenity and other libadwaita apps
        "^com\\.saivert\\.pwvucontrol$",
        "^xdg-desktop-portal-gtk$",      -- GTK file chooser
        "^zenity$",
        "^firefox$",
        "^chromium$",
        "^obsidian$",
        "^discord$",
        "^vesktop$",
        "^steam$",
    }
    hl.window_rule({
        name  = "hyprbars-skip-native-title-bars",
        match = { class = "(" .. table.concat(nativeTitleBarApps, "|") .. ")" },

        ["hyprbars:no_bar"] = true,
    })

    -- Title bars turned off in System Settings → Desktop & Dock
    if not pick(S.title_bars, true) then
        hl.window_rule({
            name  = "hyprbars-off",
            match = { class = ".*" },

            ["hyprbars:no_bar"] = true,
        })
    end
end
