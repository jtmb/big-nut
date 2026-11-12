# Wallpaper provenance

`windows-10-hero.svg` is an original drawing made for this Linux theme. It is
inspired by the composition of the Windows 10 "Hero" wallpaper — a dark blue
field, a glowing four-pane window and light beams — but it is not a copy of
Microsoft's artwork and contains no Microsoft asset.

The real Windows 10 Hero wallpaper is Microsoft copyright and is not bundled
here. Do not replace `1-windows-10-blue.webp` with Microsoft's file unless you
have a licence that permits redistribution.

Rendered asset: `1-windows-10-blue.webp` (3840×2160, WebP).

Rebuild:

```bash
rsvg-convert -w 3840 -h 2160 windows-10-hero.svg -o /tmp/windows-10-hero.png
magick /tmp/windows-10-hero.png -quality 92 1-windows-10-blue.webp
```
