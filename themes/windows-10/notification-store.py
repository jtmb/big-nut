#!/usr/bin/env python3
"""Maintain the Windows-shaped notification store for the action center.

Omarchy still delivers notifications, but the Windows theme keeps its own
store with stable ids, app/title/body/icon/timestamp fields, a read flag and a
dismissed flag. The action center reads this file, not Omarchy's history.

Usage:
  notification-store.py sync
  notification-store.py list
  notification-store.py dismiss <id>
  notification-store.py clear
"""

import json
import os
from pathlib import Path
import sys
import tempfile
import time

STATE_HOME = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state"))
OMARCHY = STATE_HOME / "omarchy/notifications"
STORE = STATE_HOME / "omarchy/windows-10-notifications.json"
DISMISSED = STATE_HOME / "omarchy/windows-10-dismissed.json"
LIMIT = 50


def load(path, fallback):
    try:
        value = json.loads(path.read_text())
    except (OSError, ValueError):
        return fallback
    return value if isinstance(value, type(fallback)) else fallback


def save(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(prefix=".windows-10-notifications-", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as stream:
            json.dump(value, stream, indent=2)
            stream.write("\n")
        os.replace(name, path)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def dismissed_ids():
    rows = load(DISMISSED, [])
    return {str(row) for row in rows if row}


def normalise(row):
    if not isinstance(row, dict):
        return None
    key = str(row.get("key") or "")
    if not key:
        return None
    app = str(row.get("app") or row.get("source") or "Notification")
    title = str(row.get("summary") or app)
    body = str(row.get("body") or "")
    try:
        timestamp = float(row.get("ts") or time.time())
    except (TypeError, ValueError):
        timestamp = time.time()
    return {
        "id": key,
        "app": app,
        "source": str(row.get("source") or app),
        "title": title,
        "body": body,
        "icon": str(row.get("appIcon") or ""),
        "glyph": str(row.get("glyph") or ""),
        "timestamp": timestamp,
        "read": bool(row.get("read", False)),
        "dismissed": False,
        "urgency": int(row.get("urgency") or 0) if str(row.get("urgency") or "0").isdigit() else 0,
        "execArgv": row.get("execArgv") or "",
        "execActions": row.get("execActions") or "",
        "link": row.get("link") or "",
        "image": row.get("image") or "",
    }


def sync():
    live = load(OMARCHY / "live.json", [])
    history = load(OMARCHY / "history.json", [])
    dismissed = dismissed_ids()
    rows = []
    seen = set()
    for row in list(live) + list(history):
        item = normalise(row)
        if not item or item["id"] in seen or item["id"] in dismissed:
            continue
        seen.add(item["id"])
        rows.append(item)
    rows.sort(key=lambda item: item["timestamp"], reverse=True)
    rows = rows[:LIMIT]
    save(STORE, {
        "version": 1,
        "updated": time.time(),
        "notifications": rows,
    })
    return rows


def main():
    command = sys.argv[1] if len(sys.argv) > 1 else "list"
    if command == "sync":
        rows = sync()
        print(json.dumps({"count": len(rows)}))
        return
    if command == "list":
        sync()
        print(json.dumps(load(STORE, {}).get("notifications", [])))
        return
    if command == "dismiss":
        if len(sys.argv) < 3:
            raise SystemExit("usage: notification-store.py dismiss <id>")
        ids = set(load(DISMISSED, []))
        for key in sys.argv[2:]:
            key = str(key)
            if key:
                ids.add(key)
        save(DISMISSED, sorted(ids)[-300:])
        sync()
        print(json.dumps({"dismissed": sorted(ids)[-300:]}))
        return
    if command == "clear":
        rows = load(STORE, {}).get("notifications", [])
        ids = set(load(DISMISSED, []))
        for row in rows:
            if isinstance(row, dict) and row.get("id"):
                ids.add(str(row["id"]))
        save(DISMISSED, sorted(ids)[-300:])
        save(STORE, {"version": 1, "updated": time.time(), "notifications": []})
        print(json.dumps({"cleared": len(rows)}))
        return
    raise SystemExit("usage: notification-store.py sync|list|dismiss <id>|clear")


if __name__ == "__main__":
    main()
