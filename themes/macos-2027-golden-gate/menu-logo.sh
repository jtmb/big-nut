#!/bin/bash
# Menu bar logo: the Apple mark or the Big Nut peanut. Persist independently
# of the light/dark appearance and other themes.
set -euo pipefail

case "${1:-}" in
  apple) ;;
  peanut) ;;
  *) echo "Usage: menu-logo.sh apple|peanut" >&2; exit 2 ;;
esac

source omarchy-shell-config
if [[ $1 == apple ]]; then
  commit "$NORMALIZE | del(.dock.goldenGateMenuLogo)"
else
  commit "$NORMALIZE | .dock.goldenGateMenuLogo = \"$1\""
fi
