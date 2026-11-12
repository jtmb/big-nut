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
- Start menu: dark Windows 10 rail, all-apps list, live tiles, power menu.
- Colors: white app surfaces, black window text, `#0078d7` accent, square
  corners, opaque windows and a 1px accent border.
- Wallpaper: `backgrounds/1-windows-10-blue.webp`, an original blue pane
  illustration.
- Font: `fonts/` contains Selawik Regular, Semilight, Light, Semibold and Bold
  (SIL Open Font License 1.1, see `fonts/LICENSE.txt`). The theme hook installs
  them for the current user and refreshes fontconfig.

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
- Action center: opens Omarchy's notification history panel (the shell's notification service).
- Show desktop: minimize everything on the workspace, or restore what the
  taskbar hid.
- Power button: Sleep, Shut down, Restart, Sign out.

## Fidelity notes

The taskbar height (40px), black taskbar, 24px app icons in 40px slots,
two-line clock, Start rail/tile proportions, square surfaces, light Settings
palette and `#0078d7` accent follow Windows 10 at 100% scale. Linux applications
draw their own title bars and menus, so this theme cannot reproduce every
Windows app chrome; those parts are intentionally left to the applications.
The Start rail's Settings button opens Omarchy's system menu, and the action
center opens Omarchy's notification history rather than a full Windows quick
actions pane. The reference screenshots used while building this were the
Wikimedia Commons Windows 10 taskbar and Start menu captures, the Windows 10
Settings scale and layout capture, and Microsoft's Windows app title bar design
guidance.

Not affiliated with or endorsed by Microsoft.
