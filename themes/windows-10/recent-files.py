#!/usr/bin/env python3
"""Print recent application documents as JSON for the Windows jump lists.

Usage: recent-files.py [desktop-id-or-name ...]

All arguments are used as application hints. Matching is case-insensitive and
tokenised, so "libreoffice-writer", "LibreOffice Writer" and an XBEL app of
"LibreOffice 26.8" all match through the shared "libreoffice" token.
"""

import json
from pathlib import Path
import re
import sys
from urllib.parse import unquote
import xml.etree.ElementTree as ET

XBEL = Path.home() / ".local/share/recently-used.xbel"
NAMESPACES = {
    "x": "http://www.freedesktop.org/standards/desktop-bookmarks",
    "b": "http://www.freedesktop.org/standards/desktop-bookmarks",
}
ALIASES = {
    "files": {"nautilus"},
    "nautilus": {"files"},
    "document": {"evince"},
    "viewer": {"evince"},
    "evince": {"document"},
    "writer": {"libreoffice", "soffice"},
    "calc": {"libreoffice", "soffice"},
    "impress": {"libreoffice", "soffice"},
    "libreoffice": {"soffice"},
    "text": {"editor"},
}
GENERIC = {"org", "com", "gnome", "kde", "the", "app", "desktop"}


def words(text):
    return set(re.findall(r"[a-z0-9]+", str(text).lower()))


def hints(values):
    tokens = set()
    for value in values:
        for token in words(value):
            tokens.add(token)
            tokens |= ALIASES.get(token, set())
    return {token for token in tokens if len(token) >= 3 and token not in GENERIC}


def main():
    needles = hints(sys.argv[1:])
    if not XBEL.is_file():
        print("[]")
        return
    try:
        root = ET.parse(XBEL).getroot()
    except (ET.ParseError, OSError):
        print("[]")
        return

    rows = []
    for bookmark in root.findall("bookmark"):
        href = bookmark.get("href", "")
        if not href.startswith("file://"):
            continue
        application = bookmark.find("info/metadata/b:applications/b:application", NAMESPACES)
        app = application.get("name", "") if application is not None else ""
        executable = application.get("exec", "") if application is not None else ""
        title = Path(unquote(href[7:])).name or href
        haystack = words(app) | words(executable) | words(title)
        if needles and not (needles & haystack) and not any(
                needle in token for needle in needles for token in haystack):
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
