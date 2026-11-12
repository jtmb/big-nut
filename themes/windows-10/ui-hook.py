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
THEME_DIR = Path(__file__).resolve().parent
TITLEBARS = Path.home() / ".local/share/windows-10-titlebars/titlebars.so"
ENV_DROPIN = Path.home() / ".config/environment.d/90-windows-10.conf"
ENV_STATE = Path.home() / ".local/state/omarchy/windows-10-env.json"
SHIM = Path.home() / ".local/share/windows-10-titlebars/libtitleleft.so"
ENV_MARKER = "# managed by the windows-10 theme"
GTK_SOURCE = THEME_DIR / "gtk"
GTK_STATE = Path.home() / ".local/state/omarchy/windows-10-gtk.json"
GTK_FILES = (
    (GTK_SOURCE / "gtk-3.0/gtk.css", Path.home() / ".config/gtk-3.0/gtk.css"),
    (GTK_SOURCE / "settings.ini", Path.home() / ".config/gtk-3.0/settings.ini"),
    (GTK_SOURCE / "gtk-4.0/gtk.css", Path.home() / ".config/gtk-4.0/gtk.css"),
    (GTK_SOURCE / "settings.ini", Path.home() / ".config/gtk-4.0/settings.ini"),
)
GTK_SETTINGS = (
    ("org.gnome.desktop.interface", "gtk-theme", "'Adwaita'"),
    ("org.gnome.desktop.interface", "font-name", "'Selawik 10'"),
    ("org.gnome.desktop.interface", "color-scheme", "'prefer-light'"),
    ("org.gnome.desktop.wm.preferences", "button-layout", "'menu:minimize,maximize,close'"),
)
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


def gsettings(*args):
    if os.environ.get("WINDOWS10_SKIP_GTK_GSETTINGS"):
        return ""
    result = subprocess.run(["gsettings", *args], check=False,
                            capture_output=True, text=True)
    return result.stdout.strip()


def install_gtk_style():
    """Install square, light GTK overrides and Windows caption layout."""
    if not (GTK_SOURCE / "gtk-3.0/gtk.css").is_file():
        return
    state = {}
    if GTK_STATE.is_file():
        try:
            state = json.loads(GTK_STATE.read_text())
        except (OSError, ValueError):
            state = {}
    files = state.get("files")
    if not isinstance(files, dict):
        files = {}
        for _, target in GTK_FILES:
            files[str(target)] = target.read_text() if target.is_file() else None
    gtk_settings = state.get("gsettings")
    if not isinstance(gtk_settings, dict):
        gtk_settings = {}
        for schema, key, _ in GTK_SETTINGS:
            gtk_settings[f"{schema}:{key}"] = gsettings("get", schema, key)
    for source, target in GTK_FILES:
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
    if not os.environ.get("WINDOWS10_SKIP_GTK_GSETTINGS"):
        for schema, key, value in GTK_SETTINGS:
            subprocess.run(["gsettings", "set", schema, key, value], check=False,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    save(GTK_STATE, {"files": files, "gsettings": gtk_settings})


def remove_gtk_style():
    if not GTK_STATE.is_file():
        return
    try:
        state = json.loads(GTK_STATE.read_text())
    except (OSError, ValueError):
        GTK_STATE.unlink()
        return
    for name, original in (state.get("files") or {}).items():
        target = Path(name)
        if original is None:
            target.unlink(missing_ok=True)
        else:
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(original)
    if not os.environ.get("WINDOWS10_SKIP_GTK_GSETTINGS"):
        for name, value in (state.get("gsettings") or {}).items():
            schema, key = name.split(":", 1)
            if value:
                subprocess.run(["gsettings", "set", schema, key, value], check=False,
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    GTK_STATE.unlink()


def install_title_shim():
    """Build the title-left shim loaded into GTK apps with LD_PRELOAD."""
    if os.environ.get("WINDOWS10_SKIP_SHIM"):
        return
    source = THEME_DIR / "gtk/title-left-shim.c"
    build = THEME_DIR / "gtk/build-shim.sh"
    if not source.is_file() or not build.is_file():
        return
    if SHIM.is_file() and SHIM.stat().st_mtime >= source.stat().st_mtime:
        return
    if not shutil.which("cc"):
        return
    subprocess.run(["bash", str(build), str(SHIM)], check=False,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def systemd_environment(name):
    if os.environ.get("WINDOWS10_SKIP_ENV"):
        return ""
    result = subprocess.run(["systemctl", "--user", "show-environment"],
                            check=False, capture_output=True, text=True)
    prefix = name + "="
    for line in result.stdout.splitlines():
        if line.startswith(prefix):
            return line[len(prefix):]
    return ""


def install_gtk_environment():
    """Ask GTK apps for server-side decorations and left-aligned titles."""
    if os.environ.get("WINDOWS10_SKIP_ENV"):
        return
    state = {}
    if ENV_STATE.is_file():
        try:
            state = json.loads(ENV_STATE.read_text())
        except (OSError, ValueError):
            state = {}
    if not state:
        original = None
        if ENV_DROPIN.is_file():
            current = ENV_DROPIN.read_text()
            if not current.lstrip().startswith(ENV_MARKER):
                original = current
        state = {
            "dropin": original,
            "gtk_csd": systemd_environment("GTK_CSD"),
            "ld_preload": systemd_environment("LD_PRELOAD"),
        }
    lines = [ENV_MARKER, "GTK_CSD=0"]
    preload = ""
    if SHIM.is_file():
        preload = str(SHIM)
        if state.get("ld_preload"):
            preload += ":" + state["ld_preload"]
        lines.append("LD_PRELOAD=" + preload)
    ENV_DROPIN.parent.mkdir(parents=True, exist_ok=True)
    ENV_DROPIN.write_text("\n".join(lines) + "\n")
    subprocess.run(["systemctl", "--user", "set-environment", "GTK_CSD=0"],
                   check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    if preload:
        subprocess.run(["systemctl", "--user", "set-environment", "LD_PRELOAD=" + preload],
                       check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    save(ENV_STATE, state)


def remove_gtk_environment():
    if os.environ.get("WINDOWS10_SKIP_ENV"):
        return
    state = {}
    if ENV_STATE.is_file():
        try:
            state = json.loads(ENV_STATE.read_text())
        except (OSError, ValueError):
            state = {}
    original = state.get("dropin")
    if original is None:
        ENV_DROPIN.unlink(missing_ok=True)
    else:
        ENV_DROPIN.parent.mkdir(parents=True, exist_ok=True)
        ENV_DROPIN.write_text(original)
    for name, previous in (("GTK_CSD", state.get("gtk_csd")),
                           ("LD_PRELOAD", state.get("ld_preload"))):
        if previous:
            subprocess.run(["systemctl", "--user", "set-environment", f"{name}={previous}"],
                           check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        else:
            subprocess.run(["systemctl", "--user", "unset-environment", name],
                           check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    ENV_STATE.unlink(missing_ok=True)


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
    install_gtk_style()
    install_title_shim()
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
    remove_gtk_style()
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
            install_gtk_style()
            install_title_shim()
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
