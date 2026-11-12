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

-- Ask GTK apps for server-side decorations so the Windows caption bar can own
-- their frame. GTK3 apps that implement xdg-decoration (gcr-viewer, for one)
-- honour this; GTK4/libadwaita apps always draw their own header bar. Those
-- CSD apps skip the plugin bar so the window never shows two title bars.
hl.env("GTK_CSD", "0")
hl.window_rule({
  name = "windows-csd-apps",
  match = { class = "^(org\\.gnome\\..*|chromium|chrome-.*|com\\.github\\.PintaProject\\.Pinta|libreoffice-.*|soffice)$" },
  ["winbars:no_bar"] = true,
})

-- Windows 10 caption bars. Omarchy's stock titlebar plugin draws floating
-- workspace bars; it is loaded and disabled here so the Windows fork can own
-- every window without two decorations fighting over the same edge.
local stock = "/usr/lib/omarchy-hyprland-titlebars/titlebars.so"
local stock_file = io.open(stock, "r")
if stock_file then
  stock_file:close()
  hl.plugin.load(stock)
  if hl.plugin.hyprbars then
    hl.config({ plugin = { hyprbars = { enabled = false } } })
  end
end

-- The fork adds optional hover_bg_color / hover_fg_color per caption button,
-- which is what gives the close button Windows 10's red hover.
local data_home = os.getenv("XDG_DATA_HOME")
if not data_home or data_home == "" then
  data_home = (os.getenv("HOME") or "") .. "/.local/share"
end
local shim = data_home .. "/windows-10-titlebars/libtitleleft.so"
local shim_file = io.open(shim, "r")
if shim_file then
  shim_file:close()
  hl.env("LD_PRELOAD", shim)
end

local custom = data_home .. "/windows-10-titlebars/titlebars.so"
local custom_file = io.open(custom, "r")
if custom_file then
  custom_file:close()
  hl.plugin.load(custom)
  if hl.plugin.winbars then
    local window = [[window = "address:%WINDOW%"]]
    hl.config({
      plugin = {
        winbars = {
          enabled = true,
          bar_height = 30,
          bar_color = "#ffffff",
          bar_color_inactive = "#ffffff",
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
          inactive_button_color = "#d0d0d0",
        },
      },
    })
    for _, button in ipairs({
      {
        icon = "×",
        action = "hyprctl dispatch 'hl.dsp.window.close({ " .. window .. " })'",
        hover_bg_color = "#e81123",
        hover_fg_color = "#ffffff",
      },
      { icon = "□", action = "hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = \"maximized\", action = \"toggle\", " .. window .. " })'" },
      { icon = "—", action = "omarchy-hyprland-window-minimize %WINDOW%" },
    }) do
      hl.plugin.winbars.add_button({
        bg_color = "#ffffff",
        fg_color = "#000000",
        size = 22,
        icon = button.icon,
        action = button.action,
        hover_bg_color = button.hover_bg_color,
        hover_fg_color = button.hover_fg_color,
      })
    end
  end
end


-- Windows 10 flyouts are opaque rather than blurred glass.
hl.layer_rule({
  match = { namespace = "^(omarchy-menu|omarchy-notifications|omarchy-keyboard-panel|omarchy-osd|omarchy-dock|omarchy-dock-apps|windows-taskbar)$" },
  blur = false,
})
