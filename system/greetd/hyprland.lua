-- /etc/greetd/hyprland.lua: Hyprland for the login screen only. It runs greeter.qml and exits
-- with it, after which greetd starts your session.

-- Your displays' arrangement and keyboard layouts, copied from System Settings by greetd-install
-- (checked values only: this file is data, written by root).
local S = {}
do
    local ok, settings = pcall(dofile, "/etc/greetd/greeter-settings.lua")
    if ok and type(settings) == "table" then
        S = settings
    end
end

hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = 1,
})

for _, m in ipairs(S.monitors or {}) do
    hl.monitor(m)
end

hl.config({
    general = {
        border_size = 0,
    },
    animations = {
        enabled = false,
    },
    input = {
        -- hyprland.lua's own default, when System Settings → Keyboard hasn't set any
        kb_layout  = S.kb_layout or "us,latam",
        kb_variant = S.kb_variant or "",
    },
    misc = {
        force_default_wallpaper  = 0,
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
    },
    ecosystem = {
        no_update_news    = true,
        no_donation_nag   = true,
    },
})

hl.env("XCURSOR_SIZE", "24")

hl.on("hyprland.start", function()
    -- The greeter user's home is /, so Quickshell keeps its cache and state in the runtime dir.
    hl.exec_cmd([[export XDG_CACHE_HOME="$XDG_RUNTIME_DIR/cache" XDG_STATE_HOME="$XDG_RUNTIME_DIR/state" MALLOC_CONF=narenas:1; qs -p /etc/greetd/lockscreen/greeter.qml; hyprctl dispatch 'hl.dsp.exit()']])
end)
