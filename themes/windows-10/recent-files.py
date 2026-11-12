#!/usr/bin/env python3
"""Print recent application documents as JSON for the Windows jump lists."""

import json
import os
from pathlib import Path
import sys
import xml.etree.ElementTree as ET

XBEL = Path.home() / ".local/share/recently-used.xbel"
NS = {
    "x": "http://www.freedesktop.org/standards/desktop-bookmarks",
    "m": "http://www.freedesktop.org/standards/shared-mime-info",
    "a": "http://www.freedesktop.org/standards/desktop-bookmarks",
}


def main():
    needle = (sys.argv[1] if len(sys.argv) > 1 else "").strip().lower()
    if not XBEL.is_file():
        print("[]")
        return
    try:
        root = ET.parse(XBEL).getroot()
    except (ET.ParseError, OSError):
        print("[]")
        return

    rows = []
    for bookmark in root.findall("x:bookmark", NS):
        href = bookmark.get("href", "")
        if not href.startswith("file://"):
            continue
        app_node = bookmark.find("x:info/x:metadata/a:application", NS)
        app = (app_node.get("name", "") if app_node is not None else "")
        title = Path(href[7:]).name or href
        if needle and needle not in app.lower() and needle not in title.lower():
            continue
        rows.append({
            "title": title,
            "uri": href,
            "app": app,
            "modified": bookmark.get("modified", ""),
        })

    rows.sort(key=lambda row: row["modified"], reverse=True)
    print(json.dumps(rows[:5]))


if __name__ == "__main__":
    main()
