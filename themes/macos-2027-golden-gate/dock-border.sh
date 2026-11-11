#!/bin/bash
# Persist the optional outline without rewriting dock pins or theme settings.
set -euo pipefail

source omarchy-shell-config
case "${1:-}" in
  on) commit "$NORMALIZE | .dock.showBorder = true" ;;
  off) commit "$NORMALIZE | .dock.showBorder = false" ;;
  default) commit "$NORMALIZE | del(.dock.showBorder)" ;;
  *) echo "Usage: dock-border.sh on|off|default" >&2; exit 2 ;;
esac
