# Deployment on this machine

The following Omarchy paths are symbolic links into this repository:

| User configuration path | Repository path |
| --- | --- |
| `~/.config/omarchy/themes/macos-2027-golden-gate` | `themes/macos-2027-golden-gate` |
| `~/.config/omarchy/themes/macos-2027-golden-gate-dark` | `themes/macos-2027-golden-gate-dark` |
| `~/.config/omarchy/plugins/brajam.dock` | `shared/brajam.dock` |
| `~/.config/omarchy/plugins/brajam.golden-gate-menu` | `shared/brajam.golden-gate-menu` |
| `~/.config/omarchy/plugins/brajam.golden-gate-widgets` | `shared/brajam.golden-gate-widgets` |
| `~/.config/omarchy/hooks/theme-set.d/golden-gate-ui-hook.sh` | `libs/golden-gate-ui-hook.sh` |

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

## Verification

Run `python3 -m unittest discover -s tests -v` for isolated script and rollback
tests. For live UI changes, check the relevant cards and outline setting in
both appearances, then restore the user's selected theme and wallpaper. After
changing Hyprland Lua, run `hyprctl reload` and `hyprctl configerrors`; after
editing symlinked plugins, rescan or restart the shell and check its log.
