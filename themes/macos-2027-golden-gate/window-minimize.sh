#!/bin/bash
# Minimize a window to the Golden Gate dock. Omarchy's stock helper only allows
# this on floating workspaces because its dock is floating-only; this theme's
# dock is present on tiled workspaces too, so the same special workspace works
# everywhere. The dock restores the window to the workspace in front.
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
# Focus would otherwise stay with the minimized window, and the next window
# opened would join it on the hidden workspace.
hyprctl dispatch "hl.dsp.focus({ workspace = \"$WORKSPACE\" })" >/dev/null
