#!/bin/bash
# Linked Golden Gate Dark window and shell outlines. Light remains independent.
set -euo pipefail

case "${1:-}" in
  on) value=true ;;
  off) value=false ;;
  *) echo "Usage: dark-border.sh on|off" >&2; exit 2 ;;
esac

source omarchy-shell-config
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy"
mkdir -p "$state_dir"
# QML watches shell.json while Hyprland reads the small state file on reload.
# Prepare the latter first, and replace it only after the config commit succeeds.
tmp=$(mktemp "$state_dir/.golden-gate-border.XXXXXX")
trap 'rm -f "$tmp"; cleanup_shell_config_tmp' EXIT
printf '%s\n' "$1" > "$tmp"
commit "$NORMALIZE | .dock.goldenGateDarkBorders = $value"
mv "$tmp" "$state_dir/golden-gate-dark-borders"
if [[ $(cat "$state_dir/current/theme.name" 2>/dev/null || true) == macos-2027-golden-gate-dark ]]; then
  hyprctl reload >/dev/null
  python3 "$HOME/.config/omarchy/themes/macos-2027-golden-gate/shell-borders.py"
fi
