#!/bin/bash
# Build the LD_PRELOAD shim that packs GTK/libadwaita title widgets into the
# header bar's start slot, so titles sit at the left edge like Windows 10.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
OUTPUT=${1:-${XDG_DATA_HOME:-$HOME/.local/share}/windows-10-titlebars/libtitleleft.so}
mkdir -p "$(dirname "$OUTPUT")"
cc -shared -fPIC -O2 -o "$OUTPUT" "$HERE/title-left-shim.c" -ldl
echo "$OUTPUT"
