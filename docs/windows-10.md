# Windows 10 comparison notes

Reference material used for the clone:

- [Windows 10 taskbar capture, Wikimedia Commons](https://commons.wikimedia.org/wiki/File:Barre_des_t%C3%A2ches_Windows_10_(taskbar).jpg)
- [Windows 10 Start capture, Wikimedia Commons](https://commons.wikimedia.org/wiki/File:Capture_d%27%C3%A9cran_du_Menu_D%C3%A9marrer_de_Windows_10.jpg)
- [Windows 10 Settings scale and layout, Wikimedia Commons](https://commons.wikimedia.org/wiki/File:Windows_10_Scale_and_Layout_Settings.jpg)
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
| Titlebar | 30px Windows 10 bar, square caption buttons | 30px white bar, square transparent buttons, Selawik | `/tmp/opencode/final4-half.png` |
| Settings | light page, `#f2f2f2` nav, `#0078d7` accent | same palette; 900×660 window with 32px title bar | `/tmp/opencode/live-settings-half.png`, `live-displays-half.png` |
| Action center | dark flyout, notifications above quick actions | same structure; quick actions work and notifications are listed | `/tmp/opencode/action-notifs-half.png` |
| Jump list | taskbar app context menu | right-click/`jump <id>` menu with Open, Pin/Unpin, Close all | `/tmp/opencode/jump-final-half.png` |
| Live tile | Weather/Calendar tiles update | Weather tile refreshes every 15 minutes from `omarchy weather status` | `/tmp/opencode/start-weather4.png` |

Live checks: `hyprctl getoption plugin:hyprbars:enabled` → true,
`bar_height` → 30; the monitor is eDP-1 at 2160×1440, scale 2 (200%), 60 Hz.
Tests: `python3 -m unittest discover -s tests -v` → 20/20.

## Side-by-side comparisons

- Desktop: `/tmp/opencode/compare-desktop2.png`
- Start: `/tmp/opencode/compare-start2.png`
- Settings: `/tmp/opencode/compare-settings2.png`
- Action center: `/tmp/opencode/compare-action2.png`
- Titlebar: `/tmp/opencode/compare-titlebar4.png`

The reference captures use a user-selected accent color for Start/action
center; Big Nut uses the Windows 10 default black/dark surfaces.

## Intentional deviations

- The action center shows the three most recent entries from Omarchy's
  persisted notification history; clicking one opens the full history.
- The Weather Start tile is live; the remaining tiles are static because their
  live-tile feeds are application-owned. Jump lists provide Open, Pin/Unpin
  and Close all, but not application recent-file lists.
- Settings provides a Home category page plus Personalization, Taskbar,
  Display, Background and Multitasking. Accounts, Time & language, Privacy and
  Update remain Omarchy-managed and are called out on the Home page.
- Caption buttons do not have the Windows 10 red close-hover fill, and inactive
  caption buttons can show their white backplates against a gray inactive bar.
- The wallpaper and four-pane artwork are original drawings, not Microsoft
  assets.
