---@diagnostic disable-next-line: undefined-global
local hl = hl
local colors = require("themes.catppuccin-mocha")
local terminal = "ghostty"
local fileManager = "nautilus"
local mainMod = "SUPER"
local currentLayout = "master"

hl.monitor({
  output = "eDP-1",
  mode = "preferred",
  position = "auto",
  scale = 1,
})

hl.on("hyprland.start", function()
  hl.config({ general = { layout = currentLayout } })
  hl.exec_cmd("hypridle")
  hl.exec_cmd("awww-daemon")
  hl.exec_cmd("awww-random-wallpaper")
  hl.exec_cmd("waybar")
  hl.exec_cmd("vicinae server")
end)

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

hl.config({
  general = {
    gaps_in = 5,
    gaps_out = 10,
    border_size = 2,
    col = {
      active_border = {
        colors = { colors.blue, colors.red },
        angle = 90,
      },
      inactive_border = colors.surface0,
    },
    resize_on_border = true,
    extend_border_grab_area = true,
    allow_tearing = false,
    layout = currentLayout,
  },
  decoration = {
    rounding = 10,
    rounding_power = 2,
    active_opacity = 0.85,
    inactive_opacity = 0.66,
    blur = {
      enabled = true,
      -- noise = 0.1,
      size = 2,
      passes = 4,
    },
  },
  animations = {
    enabled = true,
  },
  dwindle = {
    preserve_split = true,
  },
  master = {
    new_status = "master",
    new_on_top = true,
    mfact = (math.sqrt(5) - 1) / 2,
  },
  misc = {
    force_default_wallpaper = 0,
    disable_hyprland_logo = true,
  },
  input = {
    kb_layout = "ch",
    kb_variant = "de_nodeadkeys",
    kb_options = "lv3:ralt_switch",
    follow_mouse = 1,
    sensitivity = 0,
    repeat_rate = 50,
    repeat_delay = 200,
    touchpad = {
      natural_scroll = false,
      scroll_factor = 0.5,
      tap_to_click = false,
      clickfinger_behavior = true,
      disable_while_typing = true,
      drag_lock = true,
      tap_and_drag = true,
    },
  },
})

hl.layer_rule({
  match = { namespace = "vicinae" },
  name = "vicinae-blur",
  blur = true,
  ignore_alpha = 0,
})

hl.curve("MyCurve", {
  type = "bezier",
  points = {
    { 0.16, 1 },
    { 0.3,  1 },
  },
})

hl.animation({ leaf = "global", speed = 5, enabled = true, bezier = "MyCurve" })
hl.animation({ leaf = "windows", speed = 5, style = "slide", enabled = true, bezier = "MyCurve", })
hl.animation({ leaf = "layers", speed = 5, style = "fade", enabled = true, bezier = "MyCurve", })
hl.animation({ leaf = "workspaces", speed = 5, style = "slide", enabled = true, bezier = "MyCurve", })

hl.device({
  name = "epic-mouse-v1",
  sensitivity = -0.5,
})

hl.bind(mainMod .. " + SHIFT + M", hl.dsp.layout("swapwithmaster master ignoremaster"))
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + M", function()
  currentLayout = currentLayout == "dwindle" and "master" or "dwindle"
  hl.config({ general = { layout = currentLayout } })
  hl.exec_cmd(string.format(
    "notify-send --app-name=Hyprland 'Layout gewechselt' '%s'",
    currentLayout == "master" and "Master" or "Dwindle"
  ))
end)
hl.bind(mainMod .. " + F", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + Space", hl.dsp.exec_cmd("vicinae toggle"))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("hyprlock"))
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))

local resizeStep = 25

hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.resize({ x = resizeStep, y = 0, relative = true }),
  { repeating = true })
hl.bind(mainMod .. " + SHIFT + left", hl.dsp.window.resize({ x = -resizeStep, y = 0, relative = true }),
  { repeating = true })
hl.bind(mainMod .. " + SHIFT + up", hl.dsp.window.resize({ x = 0, y = resizeStep, relative = true }),
  { repeating = true })
hl.bind(mainMod .. " + SHIFT + down", hl.dsp.window.resize({ x = 0, y = -resizeStep, relative = true }),
  { repeating = true })

hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "l" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "r" }))
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "u" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "d" }))

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })

for i = 1, 10 do
  local key = i % 10
  hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
  hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"),
  { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
  { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
  { locked = true, repeating = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl s 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl s 5%-"), { locked = true, repeating = true })
