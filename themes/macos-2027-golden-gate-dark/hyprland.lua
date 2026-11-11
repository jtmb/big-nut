-- Dark outlines are off unless explicitly enabled in Golden Gate Settings.
local state_home = os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")
local borders_file = io.open(state_home .. "/omarchy/golden-gate-dark-borders", "r")
local show_borders = borders_file and borders_file:read("*l") == "on"
if borders_file then borders_file:close() end

-- Dark Golden Gate: soft blur on translucent shell surfaces.
hl.config({
  decoration = {
    rounding = 8,
    blur = { enabled = true, size = 7, passes = 2, new_optimizations = true,
             xray = false, vibrancy = 0.15, noise = 0.008, popups = true },
  },
  general = {
    border_size = show_borders and 1 or 0,
    col = {
      active_border = "#707483",
      inactive_border = "#41434a",
    },
  },
  group = {
    col = { border_active = "#a9b9e6", border_inactive = "#41475e" },
  },
})

local glassy = io.open(state_home .. "/omarchy/toggles/hypr/window-glassy.lua", "r")
if glassy then glassy:close() end
o.transparent_window(".*", glassy and "0.82 0.76" or "0.94 0.88")

hl.layer_rule({
  match = { namespace = "^(omarchy-menu|omarchy-notifications|omarchy-keyboard-panel|omarchy-osd|omarchy-dock|omarchy-dock-apps|golden-gate-settings)$" },
  blur = true,
  ignore_alpha = 0.28,
})
