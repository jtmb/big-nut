#!/usr/bin/env python3
"""Keep the Golden Gate bar and dock reversible on every Omarchy theme switch."""

import copy
import json
import os
from pathlib import Path
import sys
import tempfile
import subprocess

THEME = "macos-2027-golden-gate"
DARK_THEME = "macos-2027-golden-gate-dark"
CONFIG = Path.home() / ".config/omarchy/shell.json"
STATE = Path.home() / ".local/state/omarchy/golden-gate-ui.json"
OPENCODE_CLI = Path.home() / ".config/opencode/cli.json"
LIGHT_OPENCODE = {"name": "opencode", "mode": "light"}
DARK_OPENCODE = {"name": "opencode", "mode": "dark"}
KEYS = ("bar", "dock", "plugins", "disabledPlugins", "cloneSourceRestores")


def save(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(prefix=".golden-gate-", dir=path.parent)
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


def main():
    if not CONFIG.is_file():
        return
    slug = sys.argv[1] if len(sys.argv) > 1 else ""
    if slug not in (THEME, DARK_THEME) and not STATE.is_file():
        return
    config = json.loads(CONFIG.read_text())
    if slug == DARK_THEME:
        # The shell's staged palette is regenerated on a theme switch.
        # Reapply the dark outline preference without touching other themes.
        subprocess.run([sys.executable, str(Path(__file__).with_name("shell-borders.py"))], check=True)

    if slug in (THEME, DARK_THEME):
        # Switching light/dark retains the initial rollback snapshot, rather
        # than accidentally treating the first Golden Gate mode as the user's
        # original configuration.
        if STATE.exists():
            state = json.loads(STATE.read_text())
            # Upgrade only the original preset, not a bar appearance the user
            # changed while Golden Gate was active. Keep rollback tracking in sync.
            applied_bar = state.get("applied", {}).get("bar", {})
            current_bar = config.get("bar", {})
            if applied_bar.get("background") == "none" and current_bar.get("background") == "none":
                current_bar["background"] = "glassy"
                applied_bar["background"] = "glassy"
                save(CONFIG, config)
                save(STATE, state)
            # Older Golden Gate presets omitted the Agents widget. Upgrade the
            # untouched preset only; a customized layout belongs to the user.
            layout = current_bar.get("layout", {})
            if layout == applied_bar.get("layout") and isinstance(layout.get("right"), list):
                sections = ("left", "centerBegin", "center", "centerEnd", "right")
                has_agents = any(
                    isinstance(item, dict) and item.get("id") == "omarchy.agents"
                    for section in sections for item in layout.get(section, [])
                )
                if not has_agents:
                    layout["right"].insert(0, {"id": "omarchy.agents"})
                    applied_bar["layout"] = copy.deepcopy(layout)
                    save(CONFIG, config)
                    save(STATE, state)
                # The desktop weather card opens Omarchy's real forecast panel,
                # which requires its bar widget to be mounted.
                has_weather = any(
                    isinstance(item, dict) and item.get("id") == "omarchy.weather"
                    for section in sections for item in layout.get(section, [])
                )
                if not has_weather:
                    layout["right"].insert(0, {"id": "omarchy.weather"})
                    applied_bar["layout"] = copy.deepcopy(layout)
                    save(CONFIG, config)
                    save(STATE, state)
            if state.get("slug", THEME) == slug:
                return
            dock = config.get("dock", {})
            previous_dock = state["applied"].get("dock", {})
            if dock.get("goldenGateDark") == previous_dock.get("goldenGateDark"):
                dock["goldenGateDark"] = slug == DARK_THEME
                config["dock"] = dock
                state["applied"]["dock"]["goldenGateDark"] = dock["goldenGateDark"]
                save(CONFIG, config)
            if OPENCODE_CLI.is_file() and "cli_theme_applied" in state:
                cli = json.loads(OPENCODE_CLI.read_text())
                if cli.get("theme") == state["cli_theme_applied"]:
                    cli["theme"] = copy.deepcopy(DARK_OPENCODE if slug == DARK_THEME else LIGHT_OPENCODE)
                    state["cli_theme_applied"] = copy.deepcopy(cli["theme"])
                    save(OPENCODE_CLI, cli)
            state["slug"] = slug
            save(STATE, state)
            return
        before = snapshot(config)
        bar = copy.deepcopy(config.get("bar", {}))
        bar["background"] = "glassy"
        bar["position"] = "top"
        bar["layout"] = {
            "left": [{"id": "brajam.golden-gate-menu"}, {"id": "omarchy.workspaces"}],
            "centerBegin": [], "center": [], "centerEnd": [],
            "right": [
                {"id": "omarchy.weather"},
                {"id": "omarchy.agents"},
                {"id": "omarchy.network"},
                {"id": "omarchy.audio"},
                {"id": "omarchy.tray"},
                {"id": "omarchy.clock", "format": "ddd MMM d  h:mm AP"},
                {"id": "omarchy.power"},
            ],
            "tray": copy.deepcopy(config.get("bar", {}).get("layout", {}).get("tray", [])),
        }
        dock = copy.deepcopy(config.get("dock", {}))
        # A locked position remains fixed even when applying the preset.
        if dock.get("positionLocked") is not True:
            dock["position"] = "bottom"
        dock["autohide"] = False
        dock["goldenGate"] = True
        dock["goldenGateDark"] = slug == DARK_THEME
        pinned = dock.get("pinned", [])
        for app in ("Google Photos", "Google Messages", "mpv", "org.gnome.Papers"):
            if app not in pinned:
                pinned.append(app)
        dock["pinned"] = pinned

        plugins = copy.deepcopy(config.get("plugins", []))
        for plugin_id in ("brajam.dock", "brajam.golden-gate-widgets"):
            if not any(isinstance(item, dict) and item.get("id") == plugin_id for item in plugins):
                plugins.append({"id": plugin_id})
        disabled = copy.deepcopy(config.get("disabledPlugins", []))
        if "omarchy.dock" not in disabled:
            disabled.append("omarchy.dock")
        config.update(bar=bar, dock=dock, plugins=plugins, disabledPlugins=disabled)
        applied = snapshot(config)
        cli = json.loads(OPENCODE_CLI.read_text()) if OPENCODE_CLI.is_file() else {}
        cli_before = copy.deepcopy(cli.get("theme"))
        cli_applied = DARK_OPENCODE if slug == DARK_THEME else LIGHT_OPENCODE
        save(STATE, {"before": before, "applied": applied, "slug": slug,
                     "cli_theme_before": cli_before, "cli_theme_applied": cli_applied})
        save(CONFIG, config)
        cli["theme"] = copy.deepcopy(cli_applied)
        save(OPENCODE_CLI, cli)
    else:
        state = json.loads(STATE.read_text())
        before = state["before"]
        # Restore only fields still matching the preset; user edits to any
        # field while it was active are theirs, not ours to discard.
        # Omarchy can independently cycle bar.background when a theme changes,
        # so compare bar fields separately rather than demanding a full match.
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
        # Per-setting dock restoration leaves any pins the user changed while
        # using Golden Gate intact, but removes our mode/autohide flags.
        original_dock = before.get("dock", {})
        applied_dock = state["applied"].get("dock", {})
        current_dock = config.get("dock", {})
        for field in ("pinned", "position", "autohide", "goldenGate", "goldenGateDark"):
            if field == "position" and current_dock.get("positionLocked") is True:
                continue
            if current_dock.get(field) == applied_dock.get(field):
                if field in original_dock:
                    current_dock[field] = original_dock[field]
                else:
                    current_dock.pop(field, None)
        if "dock" in before or current_dock:
            config["dock"] = current_dock
        else:
            config.pop("dock", None)
        for key in KEYS:
            if key in ("bar", "dock"):
                continue
            if config.get(key) == state["applied"].get(key):
                if key in before:
                    config[key] = before[key]
                else:
                    config.pop(key, None)
        save(CONFIG, config)
        if "cli_theme_applied" in state and OPENCODE_CLI.is_file():
            cli = json.loads(OPENCODE_CLI.read_text())
            if cli.get("theme") == state["cli_theme_applied"]:
                if state.get("cli_theme_before") is not None:
                    cli["theme"] = state["cli_theme_before"]
                else:
                    cli.pop("theme", None)
                save(OPENCODE_CLI, cli)
        STATE.unlink()


if __name__ == "__main__":
    main()
