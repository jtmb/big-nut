#!/usr/bin/env python3
"""Apply the Windows 10 taskbar layout and keep it reversible."""

import copy
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

THEME = "windows-10"
CONFIG = Path.home() / ".config/omarchy/shell.json"
STATE = Path.home() / ".local/state/omarchy/windows-10-ui.json"
FONTS = Path.home() / ".local/share/fonts/selawik"
TITLEBARS = Path.home() / ".local/share/windows-10-titlebars/titlebars.so"
ENV_DROPIN = Path.home() / ".config/environment.d/90-windows-10.conf"
THEME_DIR = Path(__file__).resolve().parent
KEYS = ("bar", "dock", "plugins", "disabledPlugins", "cloneSourceRestores")
PINNED = ["org.gnome.Nautilus", "chromium", "foot", "libreoffice-writer"]


def save(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(prefix=".windows-10-", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as stream:
            json.dump(data, stream, indent=2, ensure_ascii=False)
            stream.write("\n")
        os.replace(name, path)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def snapshot(data):
    return {key: copy.deepcopy(data[key]) for key in KEYS if key in data}


def install_fonts():
    """Selawik is Microsoft's OFL, Segoe UI-metric-compatible UI face."""
    source = THEME_DIR / "fonts"
    if not source.is_dir():
        return
    FONTS.mkdir(parents=True, exist_ok=True)
    changed = False
    for font in source.glob("*.ttf"):
        target = FONTS / font.name
        if not target.is_file() or target.read_bytes() != font.read_bytes():
            shutil.copy2(font, target)
            changed = True
    if changed:
        subprocess.run(["fc-cache", "-f", str(FONTS)], check=False,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def install_gtk_environment():
    """Ask GTK apps for server-side decorations; ignored by GTK4/libadwaita."""
    if os.environ.get("WINDOWS10_SKIP_ENV"):
        return
    ENV_DROPIN.parent.mkdir(parents=True, exist_ok=True)
    text = "GTK_CSD=0\n"
    if not ENV_DROPIN.is_file() or ENV_DROPIN.read_text() != text:
        ENV_DROPIN.write_text(text)
    subprocess.run(["systemctl", "--user", "set-environment", "GTK_CSD=0"],
                   check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def remove_gtk_environment():
    if os.environ.get("WINDOWS10_SKIP_ENV"):
        return
    if ENV_DROPIN.is_file():
        ENV_DROPIN.unlink()
    subprocess.run(["systemctl", "--user", "unset-environment", "GTK_CSD"],
                   check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def install_titlebars():
    """Build the hover-capable Windows titlebar fork against live Hyprland."""
    if os.environ.get("WINDOWS10_SKIP_TITLEBARS"):
        return
    build = THEME_DIR / "titlebars/build.sh"
    if not build.is_file():
        return
    sources = list((THEME_DIR / "titlebars").glob("*.cpp")) + \
        list((THEME_DIR / "titlebars").glob("*.hpp"))
    newest = max((path.stat().st_mtime for path in sources), default=0)
    if TITLEBARS.is_file() and TITLEBARS.stat().st_mtime >= newest:
        return
    if not shutil.which("g++"):
        return
    subprocess.run(["bash", str(build), str(TITLEBARS)], check=False,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def apply(config):
    before = snapshot(config)
    install_fonts()
    install_gtk_environment()
    install_titlebars()

    bar = copy.deepcopy(config.get("bar", {}))
    bar["background"] = "opaque"
    bar["position"] = "bottom"
    bar["layout"] = {
        "left": [{"id": "brajam.windows-taskbar"}],
        "centerBegin": [], "center": [], "centerEnd": [],
        "right": [
            {"id": "brajam.windows-tray"},
            {"id": "omarchy.network"},
            {"id": "omarchy.audio"},
            {"id": "omarchy.power"},
            {"id": "brajam.windows-clock"},
        ],
        "tray": copy.deepcopy(config.get("bar", {}).get("layout", {}).get("tray", [])),
    }

    plugins = copy.deepcopy(config.get("plugins", []))
    for plugin_id in ("brajam.windows-taskbar", "brajam.windows-clock", "brajam.windows-tray"):
        if not any(isinstance(item, dict) and item.get("id") == plugin_id for item in plugins):
            plugins.append({"id": plugin_id})
    disabled = copy.deepcopy(config.get("disabledPlugins", []))
    for plugin_id in ("brajam.dock", "omarchy.dock", "brajam.golden-gate-menu",
                      "brajam.golden-gate-widgets"):
        if plugin_id not in disabled:
            disabled.append(plugin_id)

    taskbar = copy.deepcopy(config.get("windowsTaskbar", {}))
    if not isinstance(taskbar.get("pinned"), list) or not taskbar["pinned"]:
        taskbar["pinned"] = copy.deepcopy(PINNED)

    config.update(bar=bar, plugins=plugins, disabledPlugins=disabled, windowsTaskbar=taskbar)
    applied = snapshot(config)
    save(STATE, {"before": before, "applied": applied, "slug": THEME})
    save(CONFIG, config)


def rollback(config):
    state = json.loads(STATE.read_text())
    before = state["before"]

    original_bar = before.get("bar", {})
    applied_bar = state["applied"].get("bar", {})
    current_bar = config.get("bar", {})
    for field in ("layout", "position", "background"):
        if current_bar.get(field) == applied_bar.get(field):
            if field in original_bar:
                current_bar[field] = original_bar[field]
            else:
                current_bar.pop(field, None)
    config["bar"] = current_bar

    for key in ("plugins", "disabledPlugins"):
        if config.get(key) == state["applied"].get(key):
            if key in before:
                config[key] = before[key]
            else:
                config.pop(key, None)

    save(CONFIG, config)
    # Hyprland keeps a loaded plugin across theme switches; do not leave the
    # white Windows caption bars on the next theme.
    remove_gtk_environment()
    subprocess.run(["hyprctl", "plugin", "unload", str(TITLEBARS)],
                   check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    subprocess.run(["hyprctl", "eval",
                    "hl.config({ plugin = { hyprbars = { enabled = false } } })"],
                   check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    STATE.unlink()


def main():
    if not CONFIG.is_file():
        return
    slug = sys.argv[1] if len(sys.argv) > 1 else ""
    if slug != THEME and not STATE.is_file():
        return
    config = json.loads(CONFIG.read_text())
    if slug == THEME:
        if STATE.is_file():
            install_fonts()
            install_gtk_environment()
            install_titlebars()
            state = json.loads(STATE.read_text())
            if state.get("slug") == THEME:
                return
            state["slug"] = THEME
            save(STATE, state)
            return
        apply(config)
    elif STATE.is_file():
        rollback(config)


if __name__ == "__main__":
    main()
