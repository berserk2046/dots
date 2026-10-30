-- /etc/greetd/hyprland.lua: Hyprland for the login screen only. It runs greeter.qml and exits
-- with it, after which greetd starts your session.

hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = 1,
})

hl.config({
    general = {
        border_size = 0,
    },
    animations = {
        enabled = false,
    },
    input = {
        kb_layout = "us,latam",
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
    hl.exec_cmd([[export XDG_CACHE_HOME="$XDG_RUNTIME_DIR/cache" XDG_STATE_HOME="$XDG_RUNTIME_DIR/state"; qs -p /etc/greetd/lockscreen/greeter.qml; hyprctl dispatch 'hl.dsp.exit()']])
end)
