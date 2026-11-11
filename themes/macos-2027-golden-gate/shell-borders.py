#!/usr/bin/env python3
"""Apply Golden Gate Dark's outline preference to the staged shell palette."""

import base64
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

state = Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local/state") / "omarchy"
current = state / "current"
try:
    if (current / "theme.name").read_text().strip() != "macos-2027-golden-gate-dark":
        sys.exit(0)
    enabled = (state / "golden-gate-dark-borders").read_text().strip() == "on"
except FileNotFoundError:
    enabled = False
    if not (current / "theme.name").is_file() or (current / "theme.name").read_text().strip() != "macos-2027-golden-gate-dark":
        sys.exit(0)

theme = current / "theme"
shell = theme / "shell.toml"
colors = theme / "colors.toml"
if not shell.is_file() or not colors.is_file():
    sys.exit(0)

# Change the staged theme only, not the user's shell.toml. Replace any prior
# width in each supported section so repeated calls remain valid TOML.
sections = {"popups", "menu", "launcher", "notifications"}
lines = shell.read_text().splitlines(keepends=True)
out = []
section = ""
for line in lines:
    match = re.match(r"^\s*\[([^\]]+)\]\s*(?:#.*)?$", line.rstrip("\n"))
    if match:
        section = match.group(1)
        out.append(line)
        if section in sections:
            out.append("border-width = " + ("1\n" if enabled else "0\n"))
    elif section in sections and re.match(r"^\s*border-width\s*=", line):
        continue
    else:
        out.append(line)
text = "".join(out)
if text != shell.read_text():
    fd, tmp = tempfile.mkstemp(prefix=".golden-gate-shell-", dir=theme)
    try:
        with os.fdopen(fd, "w") as stream:
            stream.write(text)
        os.replace(tmp, shell)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)

# Theme palette files are not watched by the shell. Reload only the current
# theme's colors; a user's separate shell.toml overrides remain in effect.
subprocess.run(["omarchy-shell", "-q", "shell", "applyTheme",
                base64.b64encode(colors.read_bytes()).decode(),
                base64.b64encode(shell.read_bytes()).decode()], check=True)
