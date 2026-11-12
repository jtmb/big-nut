# Windows titlebar plugin

A fork of [omarchy-hyprland-titlebars](https://github.com/omacom/omarchy-hyprland-titlebars)
(BSD-3-Clause, see `LICENSE`) used only by the Windows 10 theme.

Changes from upstream:

- Optional `hover_bg_color` and `hover_fg_color` fields on each
  `hl.plugin.winbars.add_button({...})` table. The close button uses
  `#e81123` / `#ffffff`, the Windows 10 red close hover.
- Plugin, config namespace and decoration display name renamed to `winbars` /
  `Winbar` so it can coexist with Omarchy's stock `hyprbars` plugin. The theme
  disables stock `hyprbars` so only one bar is drawn.
- The legacy `hyprbars-button` config keyword keeps its upstream name for
  compatibility, but uses the `plugin:winbars:hyprbars-button` config key.

`build.sh [output]` compiles the plugin with `g++` against the installed
Hyprland headers. The theme hook builds it to
`~/.local/share/windows-10-titlebars/titlebars.so` when missing or older than
the sources.
