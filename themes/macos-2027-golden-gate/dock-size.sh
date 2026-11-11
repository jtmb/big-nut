#!/bin/bash
# Keep dock size a user setting across light/dark switches and other themes.
set -euo pipefail

case "${1:-}" in
  small) size=23 ;;
  medium) size=29 ;;
  large) size=38 ;;
  default) size= ;;
  *) echo "Usage: dock-size.sh small|medium|large|default" >&2; exit 2 ;;
esac

source omarchy-shell-config
if [[ -n $size ]]; then
  commit "$NORMALIZE | .dock.iconSize = \$size" --argjson size "$size"
else
  commit "$NORMALIZE | del(.dock.iconSize)"
fi
