# Windows 10 comparison notes

Reference material used for the clone:

- [Windows 10 taskbar capture, Wikimedia Commons](https://commons.wikimedia.org/wiki/File:Barre_des_t%C3%A2ches_Windows_10_(taskbar).jpg)
- [Windows 10 Start capture, Wikimedia Commons](https://commons.wikimedia.org/wiki/File:Capture_d%27%C3%A9cran_du_Menu_D%C3%A9marrer_de_Windows_10.jpg)
- [Windows 10 Settings scale and layout, Wikimedia Commons](https://commons.wikimedia.org/wiki/File:Windows_10_Scale_and_Layout_Settings.jpg)
- [Windows 10 dark Start capture](https://www.bleepstatic.com/images/news/u/1097497/Windows-10/Old-Start-Menu-Dark.jpg) — dark Windows mode, black taskbar
- [Microsoft: Windows app title bar design](https://learn.microsoft.com/en-us/windows/apps/design/basics/titlebar-design)

The reference taskbar and Start captures use a user-selected accent color. This
theme follows the Windows 10 default instead: black taskbar, dark Start, and the
default `#0078d7` accent.

## Measured implementation, live

| Surface | Windows 10 | Big Nut live | Evidence |
| --- | --- | --- | --- |
| Taskbar height | 40px at 100% | 40 logical px; sampled `#0f0f0f` | `/tmp/opencode/final-desktop2-half.png` |
| Taskbar icons | 24px in ~40px slots | 24px in 40px slots | `/tmp/opencode/final4-half.png` |
| Taskbar order | Start, search, Task View, apps, tray, clock, action center | same order | `/tmp/opencode/final-desktop2-half.png` |
| Clock | two lines, time over date | two lines, `h:mm AP` over `M/d/yyyy` | `/tmp/opencode/final-desktop2-half.png` |
| Start size | about 640×600 at 1080p | 640×600 | `/tmp/opencode/compare-start-final.png` |
| Start palette | dark `#1f1f1f` by default | `#1f1f1f` with `#191919` rail | `start-recent-half.png` |
| Start content | Recently added, All apps, grouped medium/wide/large tiles, rail, power | Recently added, All apps, grouped medium/wide/large tiles (Life at a glance, Productivity, Explore), rail, power | `/tmp/opencode/compare-start-large.png` |
| Titlebar | 30px white bar, left title, square caption buttons, red `#e81123` close hover | 30px white bar, left title, square buttons, red close hover; GTK/libadwaita apps adopt white bars, square controls and left titles | `/tmp/opencode/compare-title-left.png` |
| Settings | drop-down scale, text size, display resolution, orientation | drop-down scale, text size, resolution and orientation, brightness, Night Shift; same sidebar order | `/tmp/opencode/compare-settings-resolution.png` |
| Action center | dark flyout, notification cards above a 4-column quick-action grid | live cards with real app icons/glyphs, summary, app, time, click-to-invoke, dismiss and Clear all; dismissed keys persist | `/tmp/opencode/compare-action-icons.png` |
| Jump list | taskbar app context menu with recent files | right-click/`jump <id>` menu with Open, Pin/Unpin, Close all and recent documents from the XDG recent store | `/tmp/opencode/jump-final-half.png` |
| Live tiles | Calendar, Weather and media update | Calendar shows the live date; Weather refreshes every 15 minutes; a Now Playing tile follows MPRIS players | `/tmp/opencode/start-final2.png` |

GTK apps are styled by `themes/windows-10/gtk/`: a small override sheet for
GTK3 and GTK4 (`gtk-3.0/gtk.css`, `gtk-4.0/gtk.css`) plus `settings.ini` with
`gtk-decoration-layout=menu:minimize,maximize,close`, Selawik and the light
theme. The hook installs them into `~/.config`, snapshots any previous files
and gsettings values, and restores both on theme rollback. This gives standard
GTK header bars a white Windows bar with min/max/close and the red close hover.
libadwaita apps also get square min/max/close controls with the red close
hover by styling `windowcontrols > button > image`. Their titles are moved into
the header bar start slot by the title-left shim described below.

The server-side title bars come from `themes/windows-10/titlebars/`, a fork of
`omarchy-hyprland-titlebars` built against the live Hyprland headers. It adds
`hover_bg_color` / `hover_fg_color` per caption button. The theme hook builds it
to `~/.local/share/windows-10-titlebars/titlebars.so`, loads it as `winbars`,
and disables Omarchy's stock `hyprbars` so only one decoration owns the edge.

The theme also sets `GTK_CSD=0` (Hyprland environment, an
`environment.d/90-windows-10.conf` drop-in and the systemd user environment) so
GTK apps request server-side decorations. Measured results:

- **gcr-viewer (GTK3, honours xdg-decoration):** one Windows 30px bar with
  left title, square min/max/close and the red close hover.
  Evidence `/tmp/opencode/compare-titlebar-gtk.png`.
- **Nautilus and Evince (GTK4/libadwaita):** always draw their own header bar;
  `GTK_CSD=0` cannot remove it. The GTK CSS styles standard header bars white
  with min/max/close (Evince), while libadwaita's own controls remain circular
  (Nautilus). A `winbars:no_bar` window rule (`^org\.gnome\..*`) suppresses
  the plugin bar so they never show two title bars.
- **Chromium, Pinta and LibreOffice:** the same no-bar rule prevents duplicates
  because they draw their own client-side chrome.
- `GTK_CSD` reaches apps spawned by Hyprland immediately and launcher apps after
  the next login, when `environment.d` is re-read.

Live checks: `plugin:winbars:enabled` → true, `bar_height` → 30,
`plugin:hyprbars:enabled` → false; the monitor is eDP-1 at 2160×1440, scale 2
(200%), 60 Hz. Tests: `python3 -m unittest discover -s tests -v` → 22/22.

## Side-by-side comparisons

- Taskbar/desktop: `/tmp/opencode/compare-taskbar-final5.png` (same black-taskbar layout; the reference uses a black wallpaper and the 1607 search placeholder)
- Start (like-for-like dark, grouped wide/large tiles): `/tmp/opencode/compare-start-large.png`
- Settings: `/tmp/opencode/compare-settings-resolution.png`
- Action center (like-for-like dark, real icons and clickable cards): `/tmp/opencode/compare-action-icons.png`
- GTK app styling: `/tmp/opencode/compare-gtk-style2.png`
- Left-aligned GTK/libadwaita titles: `/tmp/opencode/compare-title-left.png`
- Title alignment attempts: `/tmp/opencode/compare-title-alignment.png`
- Titlebar on a GTK SSD app + close hover: `/tmp/opencode/compare-titlebar-gtk.png`
- Titlebar default-white reference: `/tmp/opencode/compare-titlebar-default.png`

The taskbar, Start and action-center comparisons use dark Windows mode references with black surfaces, matching Big Nut's defaults. The wallpaper in the full desktop capture is an original drawing, so the taskbar strip comparison is the like-for-like surface comparison. The titlebar comparison uses a Windows 10 About dialog with a default white titlebar; it has one close button because dialogs do not show minimize/maximize. The accent-colored Settings capture documents the reference's custom accent, not Big Nut's palette.

## Left-aligned titles

GTK header bars place their title in the centre slot of a `GtkCenterBox`, which
CSS cannot move. The theme therefore builds `gtk/title-left-shim.c` with
`gtk/build-shim.sh` into
`~/.local/share/windows-10-titlebars/libtitleleft.so` and loads it with
`LD_PRELOAD` (Hyprland `hl.env`, `environment.d` and the systemd user
environment).

The shim wraps the GTK3, GTK4, libadwaita and libhandy title setters:

- custom title widgets (`set_title_widget` / `set_custom_title`) are detached
  from the centre slot and packed into the header bar start slot;
- string titles are cleared from the centred label and shown in a start-packed
  label that updates when the app changes its title.

Verified live:

- **Evince** — `manual.pdf` sits at the left edge after the toolbar buttons.
- **Nautilus** — the path bar sits at the left, with app and window controls at
  the right.
- **Nautilus close hover** — square `#e81123` fill with a white glyph.

Evidence `/tmp/opencode/compare-title-left.png`. No `Adwaita-CRITICAL` or
packing warnings appeared in the app logs. Apps that do not use these header
bars are unaffected.

## Intentional deviations

- The action center shows up to six live/history entries as cards with a real
  app icon (icon theme, desktop entry or the sender's glyph), time,
  click-to-invoke, per-card dismiss and Clear all. Clicking a card
  runs its `execArgv` command or opens its link; entries without either open
  the notification history. Dismissed keys persist in
  `~/.local/state/omarchy/windows-10-dismissed.json`, so cleared history cards
  stay hidden across restarts (Omarchy's history file itself is read-only).
- Calendar, Weather and MPRIS Now Playing tiles are live and grouped as
  Life at a glance, Productivity and Explore. Calendar, LibreOffice Writer and
  Now Playing use wide tiles; Files uses a large 2x2 tile. Other tiles are
  static because their feeds are application-owned. Jump lists include recent
  XDG documents. The live store was populated by opening a real document in
  LibreOffice Writer and verified through the jump-list Recent row.
- Settings provides the Windows 10 sidebar order and drop-down scale,
  text-size, resolution and orientation controls: Home, System, Devices, Network & Internet, Personalization,
  Accounts, Time & language, Privacy & security, Update & security. System links to Display, Sound,
  Power & battery, Notifications and Multitasking; Devices reads Bluetooth and
  CUPS state; Network & Internet reads NetworkManager state. Actions are real
  Omarchy/NetworkManager/CUPS commands, not Windows services.
- GTK4/libadwaita apps (Nautilus, Evince, Pinta) draw their own header bars.
  The GTK CSS turns standard GTK header bars white with Windows min/max/close
  and red close hover (Evince). libadwaita's window controls are made square
  with the same hover by styling `windowcontrols > button > image`. Titles are
  moved to the header bar start slot by the `LD_PRELOAD` shim, so they sit at
  the left like Windows 10. The plugin's own bar is suppressed for those
  classes so there is never a duplicate title bar. GTK3 apps that honour xdg-decoration
  (gcr-viewer) get the server-side Windows bar.
- Jump-list Recent rows are live: the helper reads the real XDG recent store.
  The LO Writer row was verified with `~/Documents/Windows 10 notes.txt`.
- Inactive caption buttons use `#d0d0d0` rather than Windows' exact
  `#cccccc`; the difference is a few RGB points and only shows on unfocused
  server-decorated windows.
- The wallpaper and four-pane artwork are original drawings, not Microsoft
  assets. No Microsoft font, icon, logo or wallpaper file is included;
  Selawik is Microsoft's SIL OFL Segoe UI substitute.
