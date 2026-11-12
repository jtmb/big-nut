#!/bin/bash
# Pin or unpin an app on the Windows taskbar without touching other settings.
set -euo pipefail

case "${1:-}" in
  pin)
    [[ -n ${2:-} ]] || exit 2
    source omarchy-shell-config
    commit "$NORMALIZE | .windowsTaskbar = (.windowsTaskbar // {}) | .windowsTaskbar.pinned = (((.windowsTaskbar.pinned // []) + [\$id]) | unique)" --arg id "$2"
    ;;
  unpin)
    [[ -n ${2:-} ]] || exit 2
    source omarchy-shell-config
    commit "$NORMALIZE | .windowsTaskbar = (.windowsTaskbar // {}) | .windowsTaskbar.pinned = ((.windowsTaskbar.pinned // []) - [\$id])" --arg id "$2"
    ;;
  *)
    echo "Usage: taskbar-pin.sh pin|unpin <app-id>" >&2
    exit 2
    ;;
esac
