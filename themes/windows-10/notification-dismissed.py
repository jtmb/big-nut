#!/usr/bin/env python3
"""Persist dismissed notification keys for the Windows action center.

Usage:
  notification-dismissed.py list
  notification-dismissed.py add <key> [key ...]
"""

import json
import os
from pathlib import Path
import sys
import tempfile

STATE = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / \
    "omarchy/windows-10-dismissed.json"
LIMIT = 300


def load():
    try:
        rows = json.loads(STATE.read_text())
    except (OSError, ValueError):
        return []
    return [str(row) for row in rows] if isinstance(rows, list) else []


def save(rows):
    STATE.parent.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(prefix=".windows-10-dismissed-", dir=STATE.parent)
    try:
        with os.fdopen(fd, "w") as stream:
            json.dump(rows[-LIMIT:], stream)
            stream.write("\n")
        os.replace(name, STATE)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def main():
    command = sys.argv[1] if len(sys.argv) > 1 else "list"
    rows = load()
    if command == "list":
        print(json.dumps(rows))
        return
    if command == "add":
        for key in sys.argv[2:]:
            key = str(key)
            if key and key not in rows:
                rows.append(key)
        save(rows)
        print(json.dumps(rows[-LIMIT:]))
        return
    print("usage: notification-dismissed.py list|add <key> ...", file=sys.stderr)
    raise SystemExit(2)


if __name__ == "__main__":
    main()
