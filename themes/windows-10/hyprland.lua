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

-- Windows 10 caption bars. Omarchy only loads its titlebar plugin for floating
-- workspaces; the Windows theme wants the normal white 30px bar on every
-- window. The transparent (white) square buttons keep the Windows caption
-- layout while avoiding the rounded circles of the default plugin style.
local titlebars = "/usr/lib/omarchy-hyprland-titlebars/titlebars.so"
local titlebars_file = io.open(titlebars, "r")
if titlebars_file then
  titlebars_file:close()
  hl.plugin.load(titlebars)
  if hl.plugin.hyprbars then
    local window = [[window = "address:%WINDOW%"]]
    hl.config({
      plugin = {
        hyprbars = {
          enabled = true,
          bar_height = 30,
          bar_color = "#ffffff",
          col = { text = "#000000" },
          bar_text_font = "Selawik",
          bar_text_size = 12,
          bar_text_weight = "normal",
          bar_text_align = "left",
          bar_buttons_alignment = "right",
          bar_part_of_window = true,
          bar_precedence_over_border = true,
          bar_padding = 8,
          bar_button_padding = 6,
          button_rounding = 0,
          icon_on_hover = false,
          inactive_button_color = "#ffffff",
          on_double_click = "hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = \"maximized\", action = \"toggle\", " .. window .. " })'",
        },
      },
    })
    for _, button in ipairs({
      { icon = "×", action = "hyprctl dispatch 'hl.dsp.window.close({ " .. window .. " })'" },
      { icon = "□", action = "hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = \"maximized\", action = \"toggle\", " .. window .. " })'" },
      { icon = "—", action = "omarchy-hyprland-window-minimize %WINDOW%" },
    }) do
      hl.plugin.hyprbars.add_button({
        bg_color = "#ffffff",
        fg_color = "#000000",
        size = 22,
        icon = button.icon,
        action = button.action,
      })
    end
  end
end


-- Windows 10 flyouts are opaque rather than blurred glass.
hl.layer_rule({
  match = { namespace = "^(omarchy-menu|omarchy-notifications|omarchy-keyboard-panel|omarchy-osd|omarchy-dock|omarchy-dock-apps|windows-taskbar)$" },
  blur = false,
})
