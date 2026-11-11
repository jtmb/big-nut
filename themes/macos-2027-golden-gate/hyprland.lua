-- Theme-local treatment: blurred Liquid Glass shell surfaces and restrained
-- silver borders. Switching themes removes these on the next Hyprland reload.
hl.config({
  decoration = {
    rounding = 8,
    blur = { enabled = true, size = 7, passes = 2, new_optimizations = true,
             xray = false, vibrancy = 0.15, noise = 0.008, popups = true },
  },
  general = {
    border_size = 1,
    col = {
      active_border = "#9e9da7",
      inactive_border = "#b5b2b7",
    },
  },
  group = {
    col = { border_active = "#ffffff", border_inactive = "#b5aba9" },
  },
})

-- Standard mode stays subtle; Omarchy's Glassy mode is deliberately more
-- see-through here. Its terminal renderer separately keeps text crisp.
local state_home = os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")
local glassy = io.open(state_home .. "/omarchy/toggles/hypr/window-glassy.lua", "r")
if glassy then glassy:close() end
o.transparent_window(".*", glassy and "0.86 0.80" or "0.94 0.88")

-- OpenCode's TUI paints its own opaque surface; keeping the agent window
-- opaque lets the terminal's one-cell remainder blend with the TUI instead of
-- showing the desktop through it as a border.
o.window("org.omarchy.agent", { opacity = "1.0 override 1.0 override" })

-- Omarchy's stock minimize helper only works on floating workspaces because
-- its dock is floating-only. This theme's dock is shown everywhere, so
-- minimize on tiled workspaces as well.
o.rebind("SUPER + M", "Minimize window to the Golden Gate Dock",
  "bash \"$HOME/.config/omarchy/themes/macos-2027-golden-gate/window-minimize.sh\"")

hl.layer_rule({
  match = { namespace = "^(omarchy-menu|omarchy-notifications|omarchy-keyboard-panel|omarchy-osd|omarchy-dock|omarchy-dock-apps|golden-gate-settings)$" },
  blur = true,
  ignore_alpha = 0.28,
})
