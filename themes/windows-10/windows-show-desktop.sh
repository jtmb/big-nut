#!/bin/bash
# Windows 10 "Show desktop": minimize every window on the active workspace, or
# restore the windows already waiting on the taskbar's hidden workspace.
set -euo pipefail

ACTIVE=$(hyprctl activeworkspace -j | jq -r '.id')
[[ $ACTIVE =~ ^[0-9]+$ ]] || exit 1

CLIENTS=$(hyprctl clients -j)
VISIBLE=$(jq -r --argjson active "$ACTIVE" \
  '[.[] | select(.workspace.id == $active) | select(.hidden != true)] | length' <<<"$CLIENTS")

if (( VISIBLE > 0 )); then
  while read -r address; do
    [[ -n $address ]] && bash "$(dirname "$0")/window-minimize.sh" "$address" || true
  done < <(jq -r --argjson active "$ACTIVE" '.[] | select(.workspace.id == $active) | .address' <<<"$CLIENTS")
else
  while read -r address; do
    [[ -n $address ]] || continue
    hyprctl dispatch "hl.dsp.window.move({ workspace = \"$ACTIVE\", window = \"address:$address\" })" >/dev/null
    hyprctl dispatch "hl.dsp.focus({ window = \"address:$address\" })" >/dev/null
  done < <(jq -r '.[] | select(.workspace.name == "special:minimized") | .address' <<<"$CLIENTS")
fi
