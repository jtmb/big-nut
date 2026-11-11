#!/bin/bash
# Lock movement without changing the dock's position or pinned applications.
set -euo pipefail

case "${1:-}" in
  on) value=true ;;
  off) value=false ;;
  *) echo "Usage: dock-position-lock.sh on|off" >&2; exit 2 ;;
esac

source omarchy-shell-config
commit "$NORMALIZE | .dock.positionLocked = $value"
