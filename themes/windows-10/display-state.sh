#!/bin/bash
# One snapshot of the display state for the Windows Settings window.
set -euo pipefail

monitors=$(hyprctl monitors all -j)
focused=$(jq -r 'first(.[] | select(.focused == true) | .name) // empty' <<<"$monitors")
brightness=""
if [[ -n $focused ]]; then
  brightness=$(timeout 2 omarchy brightness display --monitor "$focused" 2>/dev/null | head -n 1 || true)
fi
nightlight=$(omarchy toggle nightlight --status 2>/dev/null || printf '%s\n' '{"enabled":false,"temperature":null}')
text_size=$(omarchy display text size 2>/dev/null | sed -n 's/^text size: \([0-9][0-9]*\).*/\1/p')
mirror=false
omarchy-hyprland-toggle-enabled internal-monitor-mirror >/dev/null 2>&1 && mirror=true
external=false
omarchy-hyprland-monitor-external-active >/dev/null 2>&1 && external=true

jq -n \
  --argjson monitors "$monitors" \
  --arg brightness "$brightness" \
  --argjson nightlight "$nightlight" \
  --arg textSize "$text_size" \
  --argjson mirror "$mirror" \
  --argjson external "$external" '
  {
    monitors: [$monitors[] | {
      name,
      description,
      make,
      model,
      width,
      height,
      refreshRate,
      scale,
      transform,
      focused: (.focused == true),
      enabled: (.disabled != true),
      internal: (.name | test("^(eDP|LVDS|DSI)-")),
      modes: (.availableModes // [])
    }],
    enabledCount: ([$monitors[] | select(.disabled != true)] | length),
    brightness: (($brightness | tonumber?) // null),
    textSize: (($textSize | tonumber?) // null),
    nightlight: $nightlight,
    mirror: $mirror,
    external: $external
  }'
