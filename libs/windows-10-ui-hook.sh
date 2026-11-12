#!/bin/bash
# Omarchy's hook runner invokes every hook through bash, regardless of shebang.
exec python3 "$HOME/.config/omarchy/themes/windows-10/ui-hook.py" "$@"
