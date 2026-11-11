#!/bin/bash
# Omarchy's hook runner invokes every hook through bash, regardless of shebang.
exec python3 "$HOME/.config/omarchy/themes/macos-2027-golden-gate/ui-hook.py" "$@"
