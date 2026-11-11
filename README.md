# Big Nut: Golden Gate themes

Two macOS Golden Gate-inspired appearances for Omarchy, sharing a dock, app grid, settings window and desktop widgets. This is a Linux customization, not macOS or an Apple product.

| Directory | Contents |
| --- | --- |
| `themes/macos-2027-golden-gate/` | Light theme, wallpapers and theme utilities |
| `themes/macos-2027-golden-gate-dark/` | Dark theme and wallpapers |
| `shared/` | Golden Gate Omarchy shell plugins |
| `libs/` | Shared deployed hook |
| `docs/` | Deployment notes |
| `tests/` | Isolated configuration tests |

The live user configuration is symlinked to this working tree. See [deployment](docs/deployment.md) and [project rules](RULES.md). The wallpaper source and credits are in the theme READMEs.

## Using the theme

- Open **Settings** in the top bar for Appearance, Desktop & Dock, Displays, Wallpaper, and Workspaces. The robot icon opens Omarchy's Agents panel.
- **Settings → Displays** mirrors macOS's Displays pane: the built-in display, resolution presets (Larger Text, Default, More Space), all of Omarchy's scale presets, text size, brightness, Night Shift, and display mirroring when an external screen is connected. Rotation, refresh rate, color profiles, and automatic brightness are not exposed by this display, so those macOS-only rows are omitted.
- **Settings → Appearance → Menu Bar → Peanut logo** swaps the Apple mark for a monochrome peanut shell drawn in the same bar color and optical size. It is off by default and stays set when switching between the light and dark appearances.
- In Golden Gate Dark, **Settings → Appearance → Dark theme outlines** controls the linked window, dock, widget, and shell-surface outlines. The setting is also available under **Desktop & Dock**, and starts off. Light mode retains its own dock-outline setting.
- Drag the three-dot handle at the end of the Dock to a screen edge and release to move it. Release away from an edge to cancel. **Settings → Desktop & Dock → Lock Dock position** prevents accidental moves until unlocked.
- Running apps show a small white dot on the screen-edge side of their icon (left on a left dock, right on a right dock); pinned apps without a window do not.
- **Super+M** minimizes the focused window to the Dock, including on tiled workspaces; **Window → Minimize** in the top bar does the same. Click the app's Dock icon to bring it back.
- Click the desktop calendar to open Omarchy's calendar, the weather card for its forecast, or the purple picture for Wallpaper settings. The forecast and calendar are Omarchy panels, not native macOS apps; the picture opens settings rather than a photo library.
- **Frosted Glass** uses Omarchy's global window-transparency mode and therefore also affects other themes.

Run tests with `python3 -m unittest discover -s tests -v`. They use temporary home directories and do not modify the live desktop.
