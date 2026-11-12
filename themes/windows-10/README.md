# Windows 10 for Omarchy

A Windows 10-inspired desktop for Omarchy: a 40px black taskbar at the bottom,
a dark Start menu with a two-column rail and live tiles, a search box, Task
View, running-app underlines, the action center and the Show desktop strip.
The app side uses Windows 10's light mode with the default blue accent.

This is a Linux theme, not Windows and not a Microsoft product. No Microsoft
wallpaper, icon, font or logo file is included. The blue four-pane wallpaper is
an original drawing, and the UI font is Selawik, Microsoft's SIL OFL
metric-compatible Segoe UI substitute.

## What it changes

- Taskbar: `brajam.windows-taskbar` (Start, search, Task View, pinned/running
  apps on the left) and `brajam.windows-clock` (two-line clock, action center,
  Show desktop strip on the right), plus Omarchy's tray, network, volume and
  battery widgets.
- Start menu: dark Windows 10 rail, all-apps list, grouped live tiles
  (Life at a glance, Productivity, Explore) with Windows-style wide and large
  tiles, power menu.
- Colors: white app surfaces, black window text, `#0078d7` accent, square
  corners, opaque windows and a 1px accent border.
- Wallpaper: `backgrounds/1-windows-10-blue.webp`, an original blue pane
  illustration.
- Font: `fonts/` contains Selawik Regular, Semilight, Light, Semibold and Bold
  (SIL Open Font License 1.1, see `fonts/LICENSE.txt`). The theme hook installs
  them for the current user and refreshes fontconfig.
- Title bars: `titlebars/` is a BSD-licensed fork of Omarchy's
  `omarchy-hyprland-titlebars` that adds per-button hover colours. The hook
  builds it against the installed Hyprland headers into
  `~/.local/share/windows-10-titlebars/titlebars.so`, loads it as `winbars`,
  and disables the stock `hyprbars` plugin against double decorations.
- GTK: `GTK_CSD=0` is set through Hyprland and
  `~/.config/environment.d/90-windows-10.conf`. `gtk/` contains GTK3/GTK4 CSS
  and a settings file that make header bars white, square and Windows-ordered
  (min/max/close, Selawik), with the red close hover. The hook installs and
  restores them, plus the matching gsettings values. GTK4/libadwaita apps keep
  their own circular window controls; those classes are excluded from the
  server-side bar so they never show two title bars.

## Install and apply

```bash
ln -s "$PWD/themes/windows-10" ~/.config/omarchy/themes/windows-10
ln -s "$PWD/libs/windows-10-ui-hook.sh" ~/.config/omarchy/hooks/theme-set.d/windows-10-ui-hook.sh
ln -s "$PWD/shared/brajam.windows-taskbar" ~/.config/omarchy/plugins/brajam.windows-taskbar
ln -s "$PWD/shared/brajam.windows-clock" ~/.config/omarchy/plugins/brajam.windows-clock
omarchy theme set windows-10
omarchy restart shell
```

Switching to another theme restores the previous bar, plugin and wallpaper
settings. The `windowsTaskbar.pinned` list in `shell.json` holds the taskbar
pins; edit it or use the START menu's pinned app list as a starting point.

## Interactions

- Start button: open/close Start. The hamburger expands the rail labels.
- Search box: type to filter the all-apps list in Start.
- Task View: show open windows as clickable cards.
- App button: launch, focus, or minimize the app's windows; a blue underline
  marks the active app.
- Action center: dark flyout with notification cards (real app icon or sender
  glyph, summary, time, click-to-invoke, dismiss and Clear all) above a 4-column quick-action grid
  (All settings, Network, Night light, Focus assist, Wi-Fi, Bluetooth,
  Screen snip). Dismissed keys persist across shell restarts.
- Show desktop: minimize everything on the workspace, or restore what the
  taskbar hid.
- Power button: Sleep, Shut down, Restart, Sign out.

## Fidelity notes

The taskbar height (40px), black taskbar, 24px app icons in 40px slots,
two-line clock, Start rail/tile proportions, square surfaces, 30px white window
caption bars with left-aligned titles, square min/max/close buttons, the
`#e81123` red close hover, light Settings palette and `#0078d7` accent follow
Windows 10 at 100% scale. Applications still draw their own client-area chrome
and menus. GTK3 apps with xdg-decoration support use the Windows caption bar;
GTK4/libadwaita apps keep one app-drawn header bar because they cannot be
forced into server-side decorations. Start's Settings button opens
the Windows Settings window (Home, System, Devices, Network & Internet,
Personalization, Accounts, Time & language, Privacy & security and
Update & security), and the action center has a working quick-actions flyout. The
reference screenshots used while building this were the
Wikimedia Commons Windows 10 taskbar and Start menu captures, the Windows 10
Settings scale and layout capture, and Microsoft's Windows app title bar design
guidance.

Remaining deviations: the action center embeds up to six current/history
notifications and links to the full history; the Calendar, Weather and MPRIS Now Playing Start
tiles are live while other application-owned tiles remain static; taskbar jump lists
provide open, pin/unpin, close-all and live recent XDG documents; Settings has
Home, Accounts, Time & language, Privacy & security, Update & security,
Personalization, Taskbar, Display, Background and Multitasking pages. These
are Linux limitations of the current Omarchy surfaces, not hidden fake controls.

See [docs/windows-10.md](../../docs/windows-10.md) for the reference measurements and deviations.

Not affiliated with or endorsed by Microsoft.
