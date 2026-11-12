# Deployment on this machine

The following Omarchy paths are symbolic links into this repository:

| User configuration path | Repository path |
| --- | --- |
| `~/.config/omarchy/themes/macos-2027-golden-gate` | `themes/macos-2027-golden-gate` |
| `~/.config/omarchy/themes/macos-2027-golden-gate-dark` | `themes/macos-2027-golden-gate-dark` |
| `~/.config/omarchy/themes/windows-10` | `themes/windows-10` |
| `~/.config/omarchy/plugins/brajam.dock` | `shared/brajam.dock` |
| `~/.config/omarchy/plugins/brajam.golden-gate-menu` | `shared/brajam.golden-gate-menu` |
| `~/.config/omarchy/plugins/brajam.golden-gate-widgets` | `shared/brajam.golden-gate-widgets` |
| `~/.config/omarchy/plugins/brajam.windows-taskbar` | `shared/brajam.windows-taskbar` |
| `~/.config/omarchy/plugins/brajam.windows-clock` | `shared/brajam.windows-clock` |
| `~/.config/omarchy/plugins/brajam.windows-tray` | `shared/brajam.windows-tray` |
| `~/.config/omarchy/hooks/theme-set.d/golden-gate-ui-hook.sh` | `libs/golden-gate-ui-hook.sh` |
| `~/.config/omarchy/hooks/theme-set.d/windows-10-ui-hook.sh` | `libs/windows-10-ui-hook.sh` |

The links use absolute paths. Moving or renaming this repository requires updating them. They point *from* the active user configuration *to* the tracked files, not the other way around. No packaged `/usr/share/omarchy` files are modified.

Omarchy stages a copy of a theme when it is applied; editing a theme file does not automatically rewrite that staged copy. Reapply the theme when needed, noting that reapplying the currently active theme cycles its wallpaper. Save the background path first and restore it using `omarchy theme bg set <path>`. Omarchy's recursive plugin watcher does not follow symlinked plugin directories: use `omarchy-shell shell rescanPlugins`, or `omarchy restart shell` if necessary.

The hook delegates to `themes/macos-2027-golden-gate/ui-hook.py` via the user theme path. The dock size and outline scripts also live in the light theme directory because the settings plugin calls them through that path for both appearances.

There is one theme-specific integration block in the user's existing `~/.config/hypr/hyprland.lua`, after the default imports. It restores Golden Gate transparency on floating workspaces. That file contains unrelated personal configuration and is intentionally not symlinked or copied wholesale into this repository. The hook's live rollback snapshot, shell settings, OpenCode settings, and selected wallpaper are machine state, not tracked source.

## Desktop cards

The desktop plugin creates a bottom-layer card group per screen. Its input mask
covers only the cards, so the remaining desktop is click-through and app windows
remain above it. The calendar opens Omarchy's clock/calendar panel; the weather
card opens Omarchy's forecast panel; the purple image opens Golden Gate Wallpaper
settings. These are working Linux actions, not native macOS apps or a photo
library. Omarchy's weather panel has a bar widget in the Golden Gate preset
because it must be mounted for the desktop card to open it. The Agents widget
is included as well. Customized bar layouts are not overwritten by preset
upgrades; if either widget is removed, its panel may not be available.

The weather card runs the existing `omarchy weather status` command at startup
and every 15 minutes using the user's configured weather location. It displays
bounded plain text; forecast data and connectivity are handled by Omarchy.

## Dock position and lock

Drag the three-dot handle at the end of the dock with a mouse or touchscreen
toward an edge; a blue indicator previews the selected edge. Release near it
to move the dock, or away from the edges to cancel. The handle separates moving
the whole dock from dragging app icons to reorder them. Left, right, bottom and
top are supported; the top edge is an Omarchy extension. The divider-drag
interaction is based on [iMore's macOS Dock guide](https://www.imore.com/how-use-dock-your-mac),
with a visible handle and touch support added for this implementation.

**Settings → Desktop & Dock → Lock Dock position** persists as
`dock.positionLocked` in `shell.json` (absent means unlocked). It disables the
handle and the Golden Gate position selectors, and the theme hook respects it
when applying or rolling back a preset. It is an accidental-movement guard,
not a security boundary: external commands or manual configuration edits can
still change the position. Unlock to use the selectors or handle again. Dock
pins and auto-hide are independent of this preference.

## Outline preference

In Golden Gate Dark, **Settings → Appearance → Dark theme outlines** and the
corresponding control under **Desktop & Dock** operate the same preference. Off
is the default. It affects Hyprland window borders, the Golden Gate dock,
calendar card, launcher, settings and dropdowns, plus the staged Omarchy
popup, menu, launcher and notification surface borders. It does not remove
interior separators or outlines drawn by individual applications. A user's
separate shell theme overrides may also take precedence.

The shell plugins read `dock.goldenGateDarkBorders` in `shell.json`; Hyprland
reads `golden-gate-dark-borders` under `${XDG_STATE_HOME:-~/.local/state}/omarchy`.
Use `bash ~/.config/omarchy/themes/macos-2027-golden-gate/dark-border.sh on`
or `off` instead of manually editing either value so both stay in sync. The
script refreshes the active dark compositor configuration and invokes
`shell-borders.py`, which updates the **staged** dark `shell.toml` and reloads
the palette. The theme hook reapplies that staged palette adjustment on dark
theme switches. User `shell.toml` overrides and other themes are not changed.
Light mode retains its independent `dock.showBorder` preference.

## Window minimize

Omarchy's stock minimize helper only acts on floating workspaces because its
built-in dock is floating-only. The Golden Gate dock is mounted on tiled
workspaces too, so the theme rebinds **Super+M** to
`themes/macos-2027-golden-gate/window-minimize.sh`. That script moves the focused
window to Hyprland's `special:minimized` workspace, returns focus to the
workspace it came from, and the dock restores it when its app icon is clicked.
**Window → Minimize** in the top bar runs the same command. The helper also
accepts an optional window address, like Omarchy's version. Windows minimized
this way are not kept in a separate stack; the dock's existing restore path
brings them forward on the current workspace. Because Omarchy stages a copy of
the theme, reapply the theme after updating so the staged `hyprland.lua` gets
the new SUPER+M bind.

## Displays page

**Settings → Displays** follows the macOS 27 Golden Gate Displays pane
([512 Pixels screenshot](https://media.512pixels.net/downloads/macos-screenshots/27/27-Golden-Gate-Settings-Display.png)):
a display illustration and identity, Larger Text/Default/More Space resolution
choices, Omarchy's six scale presets, a text-size slider, a brightness slider,
and Night Shift. It also shows **Mirror built-in display** when an external
monitor is active.

`themes/macos-2027-golden-gate/display-state.sh` returns the focused monitor,
backlight percentage, text size, Night Shift state, mirroring state, enabled
display count, and whether an external monitor is connected as one JSON
snapshot. The page runs the existing Omarchy commands:

- Resolution: `omarchy hyprland monitor scaling <scale>`, using the
  2.4x / 2x / 1.6x presets for Larger Text / Default / More Space. It applies to the focused
  monitor, as Omarchy's own display panel does.
- Scale: the same `omarchy hyprland monitor scaling` path with Omarchy's
  1x / 1.25x / 1.6x / 2x / 3x / 4x presets; a custom current scale is added to
  the row so it always shows the live value.
- Text size: `omarchy display text size <px>` with Omarchy's
  9/10/11/12/14/16/20 px stops. This is the same control as Omarchy's monitor
  panel, including its GTK and terminal text scaling.
- Brightness: `omarchy brightness display --no-osd --monitor <name> <n>%`.
- Night Shift: `omarchy toggle nightlight`.
- Mirroring: `omarchy hyprland monitor internal mirror on|off`.
- Display enable/disable: `hyprctl eval` on the monitor rule, shown only when
  more than one display is connected (the last enabled display cannot be
  switched off).

macOS rows without a working Linux equivalent are intentionally omitted rather
than shown disabled: **Automatically adjust brightness** (no ambient-light
daemon is configured), **Color profile** (no ICC/color-management workflow), and
**When connected to TV**. Rotation, refresh rate, and HDR likewise stay in
Hyprland's own monitor configuration, not this page. The page states this in a
short footnote.

## Windows 10 theme

`themes/windows-10` is a separate Windows 10-inspired appearance, not a
Golden Gate variant. It uses a 40px black taskbar at the bottom:
`brajam.windows-taskbar` (Start, search, Task View, pinned/running apps) on the
left, `brajam.windows-tray` + Omarchy network/audio/battery +
`brajam.windows-clock` (two-line clock, notification action center, Show desktop) on the
right. The Start menu is the taskbar's own dark rail, all-apps list, live tiles
and power flyout. The same taskbar plugin hosts the Windows Settings window,
opened from Start's Settings button; it has Personalization, Taskbar, Display,
Background and Multitasking pages.

The hook `libs/windows-10-ui-hook.sh` installs Selawik (SIL OFL Segoe UI
metric-compatible font files under `themes/windows-10/fonts/`), snapshots the
current bar/plugin lists, places the Windows widgets, disables the Golden Gate
dock/menu/widget plugins, and rolls everything back on the next theme switch.
`windowsTaskbar.pinned` in `shell.json` stores the taskbar pins. The theme's
`hyprland.lua` sets square zero-gap windows, opaque surfaces and the
`#0078d7` accent border, and loads Omarchy's titlebar plugin with a 30px white
bar and square Windows caption buttons for every window.

References used: the Wikimedia Commons Windows 10 taskbar and Start captures,
the Windows 10 Settings scale-and-layout capture, and Microsoft's Windows app
title-bar guidance. The wallpaper is an original blue four-pane drawing; no
Microsoft wallpaper or logo asset is included.

## Menu bar logo

**Settings → Appearance → Menu Bar → Peanut logo** replaces the Apple mark in
the top bar with the theme's monochrome peanut-shell mark. The setting is stored
as `dock.goldenGateMenuLogo = "peanut"` in `shell.json`; removing it returns to
the Apple mark. Use
`bash ~/.config/omarchy/themes/macos-2027-golden-gate/menu-logo.sh peanut` or
`apple` instead of editing the file directly. The menu bar widget repaints in
the current bar foreground color, so the mark follows both appearances and the
shared `shared/brajam.golden-gate-menu/peanut.svg` asset. The mark's 13×13
logical slot keeps it at the Apple glyph's menu-bar size instead of overflowing
the slot. The asset's shell
proportions are informed by Twemoji's peanut artwork (CC-BY 4.0). The
preference is kept when switching themes, like the other Golden Gate dock
options.

## Verification

Run `python3 -m unittest discover -s tests -v` for isolated script and rollback
tests. For live UI changes, check the relevant cards and outline setting in
both appearances, then restore the user's selected theme and wallpaper. After
changing Hyprland Lua, run `hyprctl reload` and `hyprctl configerrors`; after
editing symlinked plugins, rescan or restart the shell and check its log.
