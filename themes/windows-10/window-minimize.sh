#!/bin/bash
# Minimize a window to the Windows taskbar. The taskbar's app button restores
# it to the workspace in front.
set -euo pipefail

if [[ -n ${1:-} ]]; then
  ADDRESS=$1
else
  ADDRESS=$(hyprctl activewindow -j | jq -r '.address // empty')
fi
[[ -n $ADDRESS ]] || exit 1

WORKSPACE=$(hyprctl clients -j \
  | jq -r --arg address "$ADDRESS" 'first(.[] | select(.address == $address) | .workspace.id) // empty')
[[ $WORKSPACE =~ ^[0-9]+$ ]] || exit 1

hyprctl dispatch "hl.dsp.window.move({ workspace = \"special:minimized\", follow = false, window = \"address:$ADDRESS\" })" >/dev/null
hyprctl dispatch "hl.dsp.focus({ workspace = \"$WORKSPACE\" })" >/dev/null
