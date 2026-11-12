#!/bin/bash
# Build the Windows 10 titlebar plugin against the running Hyprland headers.
#
# The plugin is a fork of omarchy-hyprland-titlebars (BSD-3-Clause, see
# LICENSE) with Windows caption buttons: per-button hover colours so the close
# button can turn Windows red (#e81123) under the pointer.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
OUTPUT=${1:-${XDG_DATA_HOME:-$HOME/.local/share}/windows-10-titlebars/titlebars.so}

command -v g++ >/dev/null || { echo "g++ is required to build the titlebar plugin" >&2; exit 1; }
pkg-config --exists hyprland || { echo "Hyprland development headers are required" >&2; exit 1; }

mkdir -p "$(dirname "$OUTPUT")"
g++ -std=c++23 -shared -fPIC -fno-gnu-unique -O2 \
  -o "$OUTPUT" \
  "$HERE/main.cpp" "$HERE/barDeco.cpp" "$HERE/BarPassElement.cpp" "$HERE/appName.cpp" \
  $(pkg-config --cflags --libs hyprland libdrm libinput libudev pixman-1 wayland-server xkbcommon) \
  -lrt 2>"$OUTPUT.build.log" || {
    echo "titlebar plugin build failed; see $OUTPUT.build.log" >&2
    tail -20 "$OUTPUT.build.log" >&2
    exit 1
  }
rm -f "$OUTPUT.build.log"
echo "$OUTPUT"
