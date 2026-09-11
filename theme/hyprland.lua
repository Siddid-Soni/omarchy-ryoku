-- Ryoku: geometry, decoration, motion, and grain.
-- Runs after Omarchy's default looknfeel/windows, before the user's own
-- ~/.config/hypr/looknfeel.lua. Switching themes unloads all of this atomically.

local active_border_color = { colors = { "rgba(958f87ee)", "rgba(cdc4baee)" }, angle = 45 }
local inactive_border_color = "rgba(7a756e55)"

hl.config({
  general = {
    gaps_in = 12,
    gaps_out = 18,
    border_size = 2,
    resize_on_border = false,
    col = {
      active_border = active_border_color,
      inactive_border = inactive_border_color,
    },
  },

  group = {
    col = {
      border_active = active_border_color,
      border_inactive = inactive_border_color,
    },
  },

  decoration = {
    -- Note: looknfeel.lua currently hardcodes rounding = 8 and loads after
    -- this file, so it wins -- sharp corners are deferred until that's
    -- addressed separately (left alone per instruction, for now).
    rounding_power = 4,
    active_opacity = 0.985,
    inactive_opacity = 0.96,

    shadow = {
      enabled = true,
      range = 45,
      render_power = 4,
      color = "rgba(0a0807d1)",   -- Ryoku's 0xd10a0807 (ARGB) as rgba
    },

    blur = {
      enabled = true,
      size = 5,
      passes = 1,
      vibrancy = 0.17,
      noise = 0.01,
      new_optimizations = true,
    },

    -- 5.5% film grain over the whole output. Color is untouched -- apps,
    -- video and photos keep full color; only the shell chrome (bar, menus,
    -- terminal, borders) goes bone-on-black via colors.toml.
    -- Shader ships nested inside this theme (shaders/grain.glsl) and is
    -- staged to this same relative path under the live theme dir on every
    -- `omarchy theme set`, so it travels with the theme.
    screen_shader = os.getenv("HOME") .. "/.local/state/omarchy/current/theme/shaders/grain.glsl",
  },
})

-- Ryoku's own layer_rule list (checked directly against their decoration.lua)
-- blurs exactly five surfaces: app launcher, workspace overview, keybind
-- cheatsheet (+ its first-boot hint), and the wallpaper picker -- notably NOT
-- the bar, which is plain alpha transparency like ours. Omarchy's shell only
-- has one of those five as a real, currently-enabled equivalent: the
-- background/wallpaper switcher (omarchy.image-picker, SUPER+CTRL+SPACE,
-- namespace "omarchy-image-selector"). ignore_alpha keeps the frost off the
-- picker's own transparent margins, same as Ryoku's wallpaper-picker-blur.
hl.layer_rule({
  name = "ryoku-wallpaper-picker-blur",
  match = { namespace = "^omarchy-image-selector$" },
  blur = true,
  ignore_alpha = 0.05,
})

-- easeOutQuint / quick / almostLinear already exist with matching control
-- points in Omarchy's default looknfeel -- only Ryoku's two named curves
-- need declaring here.
hl.curve("ryokuBloom", { type = "bezier", points = { { 0.16, 1.12 }, { 0.24, 1 } } })
hl.curve("ryokuSettle", { type = "bezier", points = { { 0.18, 0.86 }, { 0.24, 1 } } })

hl.animation({ leaf = "global", enabled = true, speed = 3.2, bezier = "ryokuSettle" })
hl.animation({ leaf = "windows", enabled = true, speed = 3.2, bezier = "ryokuSettle" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 3.8, bezier = "ryokuBloom", style = "popin 78%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 2.4, bezier = "ryokuSettle", style = "popin 86%" })
hl.animation({ leaf = "border", enabled = true, speed = 3.5, bezier = "quick" })
hl.animation({ leaf = "fade", enabled = true, speed = 3, bezier = "almostLinear" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 3.2, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 2.2, bezier = "almostLinear" })
hl.animation({ leaf = "layers", enabled = true, speed = 7, bezier = "easeOutQuint", style = "popin 90%" })
-- Not in Ryoku's own file: Omarchy's defaults pin layersIn/layersOut to
-- `fade`, which as children override the `layers` parent above. Without
-- these two lines the popin never actually takes effect.
hl.animation({ leaf = "layersIn", enabled = true, speed = 7, bezier = "easeOutQuint", style = "popin 90%" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 7, bezier = "easeOutQuint", style = "popin 90%" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 7, bezier = "easeOutQuint" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 7, bezier = "easeOutQuint" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 3.5, bezier = "easeOutQuint", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 6, bezier = "easeOutQuint", style = "slidefadevert 20%" })

-- Ryoku's active/inactive window opacity. default/hypr/windows.lua tags
-- every window `+default-opacity` and applies its own windowrule, which
-- overrides decoration:active_opacity above -- so the rule has to be
-- re-issued here (this file runs after windows.lua, so this wins). Apps
-- that opt out (browsers, PiP, DaVinci, qemu, RetroArch) set their own
-- explicit opacity elsewhere and are unaffected.
o.window({ tag = "default-opacity" }, { opacity = "0.985 0.96" })
