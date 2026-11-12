-- Windows 10: square, opaque windows with a 1px accent border.
hl.config({
  decoration = {
    rounding = 0,
    blur = { enabled = false },
    shadow = { enabled = true, range = 8, render_power = 3 },
  },
  general = {
    border_size = 1,
    gaps_in = 0,
    gaps_out = 0,
    col = {
      active_border = "#0078d7",
      inactive_border = "#b3b3b3",
    },
  },
  group = {
    col = { border_active = "#0078d7", border_inactive = "#b3b3b3" },
  },
})

o.transparent_window(".*", "1.0 override 1.0 override")

-- Windows 10 flyouts are opaque rather than blurred glass.
hl.layer_rule({
  match = { namespace = "^(omarchy-menu|omarchy-notifications|omarchy-keyboard-panel|omarchy-osd|omarchy-dock|omarchy-dock-apps|windows-taskbar)$" },
  blur = false,
})
