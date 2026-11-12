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
| Start size | about 640×600 at 1080p | 640×600 | `/tmp/opencode/start-recent-half.png` |
| Start palette | dark `#1f1f1f` by default | `#1f1f1f` with `#191919` rail | `start-recent-half.png` |
| Start content | Recently added, All apps, tiles, rail, power | Recently added, All apps, tiles, rail, power | `start-recent-half.png` |
| Titlebar | 30px white bar, square caption buttons, red `#e81123` close hover | 30px white bar, left-aligned Selawik title, square buttons, red close hover | `/tmp/opencode/compare-titlebar-hover.png` |
| Settings | light page, `#f2f2f2` nav, `#0078d7` accent | same palette; Home/Accounts/Time/Privacy/Update plus the existing pages | `/tmp/opencode/settings-home3.png`, `live-displays.png` |
| Action center | dark flyout, notifications above a 4-column quick-action grid | same structure; up to six live/history notifications, 4-column grid, active tiles blue | `/tmp/opencode/compare-action-dark3.png` |
| Jump list | taskbar app context menu with recent files | right-click/`jump <id>` menu with Open, Pin/Unpin, Close all and recent documents from the XDG recent store | `/tmp/opencode/jump-final-half.png` |
| Live tiles | Calendar, Weather and media update | Calendar shows the live date; Weather refreshes every 15 minutes; a Now Playing tile follows MPRIS players | `/tmp/opencode/start-final2.png` |

The title bars come from `themes/windows-10/titlebars/`, a fork of
`omarchy-hyprland-titlebars` built against the live Hyprland headers. It adds
`hover_bg_color` / `hover_fg_color` per caption button. The theme hook builds it
to `~/.local/share/windows-10-titlebars/titlebars.so`, loads it as `winbars`,
and disables Omarchy's stock `hyprbars` so only one decoration owns the edge.

Live checks: `plugin:winbars:enabled` → true, `bar_height` → 30,
`plugin:hyprbars:enabled` → false; the monitor is eDP-1 at 2160×1440, scale 2
(200%), 60 Hz. Tests: `python3 -m unittest discover -s tests -v` → 22/22.

## Side-by-side comparisons

- Desktop: `/tmp/opencode/compare-desktop4.png`
- Start (like-for-like dark): `/tmp/opencode/compare-start6.png`
- Settings: `/tmp/opencode/compare-settings4.png`
- Action center (like-for-like dark): `/tmp/opencode/compare-action-dark3.png`
- Titlebar (default white, like-for-like): `/tmp/opencode/compare-titlebar-default.png`
- Titlebar close hover: `/tmp/opencode/compare-titlebar-hover.png`

The Start and action-center comparisons use dark Windows mode references with black surfaces, matching Big Nut's defaults. The titlebar comparison uses a Windows 10 About dialog with a default white titlebar; it has one close button because dialogs do not show minimize/maximize. The accent-colored Settings capture documents the reference's custom accent, not Big Nut's palette.

## Intentional deviations

- The action center shows up to six recent live/history entries; clicking one
  opens Omarchy's full notification history rather than a Windows notification
  database view.
- Calendar, Weather and MPRIS Now Playing tiles are live. Other tiles are
  static because their feeds are application-owned. Jump lists include recent
  XDG documents; the live store on this machine is empty, so the helper is
  covered by a synthetic-XBEL test.
- Settings provides Home, Accounts, Time & language, Privacy & security,
  Update & security, Personalization, Taskbar, Display, Background and
  Multitasking pages. The actions behind the new categories are real Omarchy
  commands or panels, not Windows services.
- Inactive caption buttons use `#d0d0d0` rather than Windows' exact
  `#cccccc`; the difference is a few RGB points and only shows on unfocused
  windows.
- The wallpaper and four-pane artwork are original drawings, not Microsoft
  assets. No Microsoft font, icon, logo or wallpaper file is included;
  Selawik is Microsoft's SIL OFL Segoe UI substitute.
