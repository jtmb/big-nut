"""Exercise Golden Gate configuration changes in disposable HOME directories."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
THEME = ROOT / "themes/macos-2027-golden-gate"
WINDOWS = ROOT / "themes/windows-10"


class DockModelTest(unittest.TestCase):
    @unittest.skipUnless(shutil.which("node"), "Node.js is required to test the JavaScript dock model")
    def test_edge_at(self):
        script = r'''
const assert = require("assert");
const model = require(process.argv[1]);
for (const [x, y, edge] of [[5, 300, "left"], [995, 300, "right"],
                             [500, 5, "top"], [500, 595, "bottom"],
                             [500, 300, ""], [-1, 300, ""], [0, 0, "left"]])
  assert.strictEqual(model.edgeAt(x, y, 1000, 600, 80), edge);
assert.strictEqual(model.edgeAt(NaN, 5, 1000, 600, 80), "");
assert.strictEqual(model.edgeAt(5, 5, Infinity, 600, 80), "");
assert.strictEqual(model.edgeAt(5, 5, 1000, 600, 0), "");
'''
        subprocess.run(["node", "-e", script, str(ROOT / "shared/brajam.dock/DockModel.js")], check=True)


class ThemeToolsTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name)
        self.config = self.home / ".config/omarchy/shell.json"
        self.config.parent.mkdir(parents=True)
        self.before = {
            "bar": {"background": "opaque", "position": "bottom", "layout": {"left": []}},
            "dock": {"pinned": ["keep.app"], "position": "left"},
            "plugins": [],
            "disabledPlugins": [],
        }
        self.config.write_text(json.dumps(self.before))
        stub = self.home / "bin/omarchy-shell"
        stub.parent.mkdir()
        stub.write_text("#!/bin/sh\nexit 0\n")
        stub.chmod(0o755)
        hyprctl = self.home / "bin/hyprctl"
        hyprctl.write_text("#!/bin/sh\nexit 0\n")
        hyprctl.chmod(0o755)
        systemctl = self.home / "bin/systemctl"
        systemctl.write_text("#!/bin/sh\nexit 0\n")
        systemctl.chmod(0o755)
        self.env = dict(os.environ, HOME=str(self.home), XDG_STATE_HOME=str(self.home / ".local/state"), OMARCHY_PATH="/usr/share/omarchy",
                        WINDOWS10_SKIP_TITLEBARS="1", WINDOWS10_SKIP_GTK_GSETTINGS="1", WINDOWS10_SKIP_SHIM="1",
                        PATH=str(stub.parent) + os.pathsep + os.environ["PATH"])

    def read_config(self):
        return json.loads(self.config.read_text())

    def run_tool(self, name, value, check=True, theme=THEME):
        interpreter = "python3" if name.endswith(".py") else "bash"
        return subprocess.run([interpreter, str(theme / name), value], env=self.env,
                              check=check, capture_output=True, text=True)

    def test_hook_restores_prior_settings_after_switching_appearances(self):
        self.run_tool("ui-hook.py", "macos-2027-golden-gate")
        self.assertEqual(self.read_config()["bar"]["background"], "glassy")
        self.assertIn({"id": "omarchy.agents"}, self.read_config()["bar"]["layout"]["right"])
        self.assertIn({"id": "omarchy.weather"}, self.read_config()["bar"]["layout"]["right"])
        self.run_tool("ui-hook.py", "macos-2027-golden-gate-dark")
        self.assertTrue(self.read_config()["dock"]["goldenGateDark"])
        self.run_tool("ui-hook.py", "gruvbox")
        after = self.read_config()
        for key, value in self.before.items():
            self.assertEqual(after[key], value)
        self.assertFalse((self.home / ".local/state/omarchy/golden-gate-ui.json").exists())

    def test_existing_preset_adds_agents_and_remains_reversible(self):
        self.run_tool("ui-hook.py", "macos-2027-golden-gate-dark")
        state_path = self.home / ".local/state/omarchy/golden-gate-ui.json"
        state = json.loads(state_path.read_text())
        config = self.read_config()
        config["bar"]["layout"]["right"].remove({"id": "omarchy.agents"})
        config["bar"]["layout"]["right"].remove({"id": "omarchy.weather"})
        state["applied"]["bar"]["layout"] = config["bar"]["layout"]
        self.config.write_text(json.dumps(config))
        state_path.write_text(json.dumps(state))
        self.run_tool("ui-hook.py", "macos-2027-golden-gate-dark")
        self.assertIn({"id": "omarchy.agents"}, self.read_config()["bar"]["layout"]["right"])
        self.assertIn({"id": "omarchy.weather"}, self.read_config()["bar"]["layout"]["right"])
        self.run_tool("ui-hook.py", "gruvbox")
        self.assertEqual(self.read_config()["bar"], self.before["bar"])

    def test_customized_layout_is_not_overwritten_during_upgrade(self):
        self.run_tool("ui-hook.py", "macos-2027-golden-gate")
        config = self.read_config()
        config["bar"]["layout"]["right"] = [{"id": "my.widget"}]
        self.config.write_text(json.dumps(config))
        self.run_tool("ui-hook.py", "macos-2027-golden-gate-dark")
        self.assertEqual(self.read_config()["bar"]["layout"]["right"], [{"id": "my.widget"}])

    def test_first_apply_uses_default_workspace_layout(self):
        layouts = self.home / ".local/state/omarchy/workspace-layouts"
        layouts.mkdir(parents=True)
        workspace_one = layouts / "1.lua"
        workspace_one.write_text('o.workspace_mode({ workspace = "1", mode = "scrolling" })\n')
        workspace_three = layouts / "3.lua"
        workspace_three.write_text('o.workspace_mode({ workspace = "3", mode = "scrolling" })\n')
        self.run_tool("ui-hook.py", "macos-2027-golden-gate")
        self.assertFalse(workspace_one.exists())
        self.assertTrue(workspace_three.exists())

    def test_theme_installs_mise_update_command(self):
        self.run_tool("ui-hook.py", "macos-2027-golden-gate")
        command = self.home / ".config/opencode/commands/update.md"
        self.assertTrue(command.exists())
        self.assertIn("mise upgrade opencode", command.read_text())
        self.run_tool("ui-hook.py", "gruvbox")
        self.assertFalse(command.exists())

    def test_opencode_sidebar_is_hidden_and_restored(self):
        cli_path = self.home / ".config/opencode/cli.json"
        cli_path.parent.mkdir(parents=True)
        original = {"$schema": "https://opencode.ai/v2/cli.json",
                    "theme": {"name": "opencode", "mode": "light"}}
        cli_path.write_text(json.dumps(original))
        self.run_tool("ui-hook.py", "macos-2027-golden-gate")
        cli = json.loads(cli_path.read_text())
        self.assertEqual(cli["session"]["sidebar"], "hide")
        self.assertEqual(cli["theme"], {"name": "opencode", "mode": "light"})
        self.run_tool("ui-hook.py", "macos-2027-golden-gate-dark")
        cli = json.loads(cli_path.read_text())
        self.assertEqual(cli["session"]["sidebar"], "hide")
        self.assertEqual(cli["theme"], {"name": "opencode", "mode": "dark"})
        self.run_tool("ui-hook.py", "gruvbox")
        cli = json.loads(cli_path.read_text())
        self.assertNotIn("session", cli)
        self.assertEqual(cli["theme"], {"name": "opencode", "mode": "light"})

    def test_dock_border_preference_and_invalid_input(self):
        for action, expected in [("on", True), ("off", False), ("default", None)]:
            self.run_tool("dock-border.sh", action)
            dock = self.read_config()["dock"]
            self.assertEqual(dock.get("showBorder"), expected)
            self.assertEqual(dock["pinned"], ["keep.app"])
        before = self.config.read_bytes()
        self.assertEqual(self.run_tool("dock-border.sh", "invalid", check=False).returncode, 2)
        self.assertEqual(self.config.read_bytes(), before)

    def test_dock_size_preference(self):
        for action, expected in [("small", 23), ("medium", 29), ("large", 38), ("default", None)]:
            self.run_tool("dock-size.sh", action)
            dock = self.read_config()["dock"]
            self.assertEqual(dock.get("iconSize"), expected)
            self.assertEqual(dock["pinned"], ["keep.app"])
        before = self.config.read_bytes()
        self.assertEqual(self.run_tool("dock-size.sh", "invalid", check=False).returncode, 2)
        self.assertEqual(self.config.read_bytes(), before)

    def test_position_lock_preserves_position_and_pins(self):
        for action, expected in [("on", True), ("off", False)]:
            self.run_tool("dock-position-lock.sh", action)
            dock = self.read_config()["dock"]
            self.assertEqual(dock["positionLocked"], expected)
            self.assertEqual(dock["position"], "left")
            self.assertEqual(dock["pinned"], ["keep.app"])
        before = self.config.read_bytes()
        self.assertEqual(self.run_tool("dock-position-lock.sh", "invalid", check=False).returncode, 2)
        self.assertEqual(self.config.read_bytes(), before)

    def test_locked_position_survives_theme_apply_and_rollback(self):
        self.run_tool("dock-position-lock.sh", "on")
        self.run_tool("ui-hook.py", "macos-2027-golden-gate")
        self.assertEqual(self.read_config()["dock"]["position"], "left")
        self.run_tool("ui-hook.py", "macos-2027-golden-gate-dark")
        self.assertEqual(self.read_config()["dock"]["position"], "left")
        self.run_tool("ui-hook.py", "gruvbox")
        self.assertEqual(self.read_config()["dock"]["position"], "left")
        self.assertTrue(self.read_config()["dock"]["positionLocked"])

    def test_lock_after_preset_prevents_rollback_move(self):
        self.run_tool("ui-hook.py", "macos-2027-golden-gate")
        self.run_tool("dock-position-lock.sh", "on")
        self.run_tool("ui-hook.py", "gruvbox")
        self.assertEqual(self.read_config()["dock"]["position"], "bottom")
        self.assertTrue(self.read_config()["dock"]["positionLocked"])

    def test_menu_bar_logo_preference(self):
        for action, expected in [("peanut", "peanut"), ("apple", None)]:
            self.run_tool("menu-logo.sh", action)
            dock = self.read_config()["dock"]
            self.assertEqual(dock.get("goldenGateMenuLogo"), expected)
            self.assertEqual(dock["pinned"], ["keep.app"])
        before = self.config.read_bytes()
        self.assertEqual(self.run_tool("menu-logo.sh", "invalid", check=False).returncode, 2)
        self.assertEqual(self.config.read_bytes(), before)

    def test_minimize_moves_tiled_window_to_the_dock_workspace(self):
        stub = self.home / "bin/hyprctl"
        stub.write_text(
            '#!/bin/sh\n'
            'case "$1" in\n'
            '  activewindow) if [ -f "$HOME/no-window" ]; then echo \'{}\'; '
            'else echo \'{"address":"0xabc","workspace":{"id":2}}\'; fi ;;\n'
            '  clients) echo \'[{"address":"0xabc","workspace":{"id":2}},'
            '{"address":"0xdef","workspace":{"id":3}}]\' ;;\n'
            '  dispatch) echo "$2" >> "$HOME/dispatches" ;;\n'
            'esac\n')
        stub.chmod(0o755)
        dispatches = self.home / "dispatches"

        self.run_tool("window-minimize.sh", "")
        lines = dispatches.read_text().splitlines()
        self.assertEqual(len(lines), 2)
        self.assertIn('special:minimized', lines[0])
        self.assertIn('address:0xabc', lines[0])
        self.assertIn('workspace = "2"', lines[1])

        dispatches.unlink()
        self.run_tool("window-minimize.sh", "0xdef")
        self.assertIn('workspace = "3"', dispatches.read_text().splitlines()[1])

        (self.home / "no-window").write_text("")
        before = dispatches.read_bytes()
        self.assertEqual(self.run_tool("window-minimize.sh", "", check=False).returncode, 1)
        self.assertEqual(dispatches.read_bytes(), before)

    def test_display_state_reports_focused_monitor(self):
        hyprctl = self.home / "bin/hyprctl"
        hyprctl.write_text(
            '#!/bin/sh\n'
            'echo \'[{"name":"eDP-1","description":"Built-in panel","make":"Test",'
            '"model":"Panel","width":2160,"height":1440,"refreshRate":60.0,'
            '"scale":2,"transform":0,"focused":true,"disabled":false,'
            '"availableModes":["2160x1440@60.00Hz"]}]\'\n')
        hyprctl.chmod(0o755)
        omarchy = self.home / "bin/omarchy"
        omarchy.write_text(
            '#!/bin/sh\n'
            'case "$1 $2" in\n'
            '  "brightness display") echo 77 ;;\n'
            '  "display text") echo "text size: 14 px" ;;\n'
            '  "toggle nightlight") echo \'{"enabled":true,"temperature":4000}\' ;;\n'
            'esac\n')
        omarchy.chmod(0o755)
        toggle = self.home / "bin/omarchy-hyprland-toggle-enabled"
        toggle.write_text("#!/bin/sh\nexit 1\n")
        toggle.chmod(0o755)
        external = self.home / "bin/omarchy-hyprland-monitor-external-active"
        external.write_text("#!/bin/sh\nexit 0\n")
        external.chmod(0o755)

        result = subprocess.run(["bash", str(THEME / "display-state.sh")], env=self.env,
                                check=True, capture_output=True, text=True)
        state = json.loads(result.stdout)
        self.assertEqual(state["monitors"][0]["name"], "eDP-1")
        self.assertTrue(state["monitors"][0]["internal"])
        self.assertTrue(state["monitors"][0]["focused"])
        self.assertEqual(state["brightness"], 77)
        self.assertEqual(state["textSize"], 14)
        self.assertTrue(state["nightlight"]["enabled"])
        self.assertFalse(state["mirror"])
        self.assertTrue(state["external"])

    def test_windows_theme_has_windows_titlebars_and_settings(self):
        lua = (WINDOWS / "hyprland.lua").read_text()
        self.assertIn("bar_height = 30", lua)
        self.assertIn('bar_color = "#ffffff"', lua)
        self.assertIn("button_rounding = 0", lua)
        self.assertIn("add_button", lua)
        self.assertIn('hover_bg_color = "#e81123"', lua)
        self.assertIn('hover_fg_color = "#ffffff"', lua)
        self.assertIn("winbars", lua)
        self.assertIn("hyprbars = { enabled = false }", lua)
        self.assertIn('hl.env("GTK_CSD", "0")', lua)
        self.assertIn("windows-csd-apps", lua)
        self.assertIn("winbars:no_bar", lua)
        source = (WINDOWS / "titlebars/main.cpp").read_text()
        self.assertIn('"hover_bg_color"', source)
        self.assertIn('"hover_fg_color"', source)
        self.assertIn("hoverbgcol", (WINDOWS / "titlebars/barDeco.cpp").read_text())
        self.assertTrue((WINDOWS / "titlebars/build.sh").is_file())
        taskbar = (ROOT / "shared/brajam.windows-taskbar/BarWidget.qml").read_text()
        self.assertIn("WindowsSettings", taskbar)
        self.assertIn('settingsView.open("home")', taskbar)

    def test_windows_recent_files_helper(self):
        share = self.home / ".local/share"
        share.mkdir(parents=True)
        (share / "recently-used.xbel").write_text(
            '<?xml version="1.0"?>'
            '<xbel version="1.0" '
            'xmlns:bookmark="http://www.freedesktop.org/standards/desktop-bookmarks">'
            '<bookmark href="file:///home/user/report.odt" modified="2026-01-02T00:00:00Z">'
            '<info><metadata owner="http://freedesktop.org">'
            '<bookmark:applications><bookmark:application name="LibreOffice 26.8" '
            'exec="&apos;soffice %u&apos;"/></bookmark:applications>'
            '</metadata></info></bookmark>'
            '<bookmark href="file:///home/user/photo.jpg" modified="2026-01-03T00:00:00Z">'
            '<info><metadata owner="http://freedesktop.org">'
            '<bookmark:applications><bookmark:application name="Nautilus" '
            'exec="&apos;nautilus %u&apos;"/></bookmark:applications>'
            '</metadata></info></bookmark>'
            '</xbel>')
        result = subprocess.run(["python3", str(WINDOWS / "recent-files.py"), "libreoffice-writer", "LibreOffice Writer"],
                                env=self.env, check=True, capture_output=True, text=True)
        rows = json.loads(result.stdout)
        self.assertEqual([row["title"] for row in rows], ["report.odt"])
        result = subprocess.run(["python3", str(WINDOWS / "recent-files.py"), "org.gnome.Nautilus", "Files"],
                                env=self.env, check=True, capture_output=True, text=True)
        rows = json.loads(result.stdout)
        self.assertEqual([row["title"] for row in rows], ["photo.jpg"])

    def test_windows_notification_store(self):
        state = self.home / ".local/state/omarchy/notifications"
        state.mkdir(parents=True)
        (state / "live.json").write_text(json.dumps([
            {"key": "live-1", "app": "Chromium", "summary": "Live title", "body": "Live body",
             "appIcon": "chromium", "ts": 1000, "source": "Chromium"},
        ]))
        (state / "history.json").write_text(json.dumps([
            {"key": "old-1", "app": "omarchy-action", "summary": "Old title", "body": "",
             "appIcon": "", "glyph": "\uf16a1", "ts": 900, "source": "omarchy-action"},
        ]))
        helper = WINDOWS / "notification-store.py"
        subprocess.run(["python3", str(helper), "sync"], env=self.env, check=True,
                       capture_output=True, text=True)
        result = subprocess.run(["python3", str(helper), "list"], env=self.env, check=True,
                                capture_output=True, text=True)
        rows = json.loads(result.stdout)
        self.assertEqual([row["id"] for row in rows], ["live-1", "old-1"])
        self.assertEqual(rows[0]["title"], "Live title")
        self.assertEqual(rows[0]["body"], "Live body")
        self.assertEqual(rows[0]["icon"], "chromium")
        subprocess.run(["python3", str(helper), "dismiss", "live-1"], env=self.env, check=True,
                       capture_output=True, text=True)
        result = subprocess.run(["python3", str(helper), "list"], env=self.env, check=True,
                                capture_output=True, text=True)
        self.assertEqual([row["id"] for row in json.loads(result.stdout)], ["old-1"])
        subprocess.run(["python3", str(helper), "clear"], env=self.env, check=True,
                       capture_output=True, text=True)
        result = subprocess.run(["python3", str(helper), "list"], env=self.env, check=True,
                                capture_output=True, text=True)
        self.assertEqual(json.loads(result.stdout), [])

    def test_windows_security_state_helper(self):
        result = subprocess.run(["bash", str(WINDOWS / "security-state.sh")], env=self.env,
                                check=True, capture_output=True, text=True)
        state = json.loads(result.stdout)
        for key in ("firewall", "secureBoot", "encrypted", "clamav", "tpm", "snapshots"):
            self.assertIn(key, state)

    def test_windows_notification_dismissed_store(self):
        helper = WINDOWS / "notification-dismissed.py"
        subprocess.run(["python3", str(helper), "add", "one", "two"], env=self.env,
                       check=True, capture_output=True, text=True)
        result = subprocess.run(["python3", str(helper), "list"], env=self.env,
                                check=True, capture_output=True, text=True)
        self.assertEqual(json.loads(result.stdout), ["one", "two"])
        subprocess.run(["python3", str(helper), "add", "two", "three"], env=self.env,
                       check=True, capture_output=True, text=True)
        result = subprocess.run(["python3", str(helper), "list"], env=self.env,
                                check=True, capture_output=True, text=True)
        self.assertEqual(json.loads(result.stdout), ["one", "two", "three"])
        self.assertTrue((self.home / ".local/state/omarchy/windows-10-dismissed.json").is_file())

    def test_windows_taskbar_pin_script(self):
        self.run_tool("ui-hook.py", "windows-10", theme=WINDOWS)
        subprocess.run(["bash", str(WINDOWS / "taskbar-pin.sh"), "pin", "chromium"],
                       env=self.env, check=True, capture_output=True, text=True)
        self.assertIn("chromium", self.read_config()["windowsTaskbar"]["pinned"])
        subprocess.run(["bash", str(WINDOWS / "taskbar-pin.sh"), "unpin", "chromium"],
                       env=self.env, check=True, capture_output=True, text=True)
        self.assertNotIn("chromium", self.read_config()["windowsTaskbar"]["pinned"])
        before = self.config.read_bytes()
        self.assertEqual(self.run_tool("taskbar-pin.sh", "invalid", check=False, theme=WINDOWS).returncode, 2)
        self.assertEqual(self.config.read_bytes(), before)

    def test_windows_action_center_and_recent_apps(self):
        clock = (ROOT / "shared/brajam.windows-clock/BarWidget.qml").read_text()
        self.assertIn("Quick actions", clock)
        self.assertIn("nmcli radio wifi toggle", clock)
        self.assertIn("omarchy-shell notifications toggleDnd", clock)
        self.assertIn("columns: 4", clock)
        self.assertIn('text: "Collapse"', clock)
        self.assertIn('text: "Clear all"', clock)
        self.assertIn("dismissNotification", clock)
        self.assertIn("clearNotifications", clock)
        self.assertIn("notificationIcon", clock)
        self.assertIn("activateNotification", clock)
        self.assertIn("execArgv", clock)
        self.assertIn("notification-store.py", clock)
        self.assertIn("storeView", clock)
        self.assertIn("notificationIcon(row)", clock)
        self.assertIn("glyphFamily", clock)
        self.assertIn("heuristicLookup", clock)
        self.assertIn('"Screen snip"', clock)
        start = (ROOT / "shared/brajam.windows-taskbar/StartMenu.qml").read_text()
        self.assertIn("Recently added", start)
        self.assertIn("All apps", start)
        self.assertIn("weatherProc", start)
        self.assertIn('"weather", "status"', start)
        self.assertIn("weatherOpen", start)
        self.assertIn("calendarCells", start)
        self.assertIn("buildTileGroups", start)
        self.assertIn("Flow {", start)
        self.assertIn("wide: true", start)
        self.assertIn("modelData.wide", start)
        self.assertIn("large: entry.id", start)
        self.assertIn("modelData.large", start)
        self.assertIn('"Productivity"', start)
        self.assertIn('"Explore"', start)
        self.assertIn("Mpris.players", start)
        self.assertIn("Now playing", start)
        self.assertIn("calendar: true", start)
        settings = (ROOT / "shared/brajam.windows-taskbar/WindowsSettings.qml").read_text()
        self.assertIn('id: "home"', settings)
        self.assertIn("Network & Internet", settings)
        for page in ("system", "devices", "network", "accounts", "time", "privacy", "update"):
            self.assertIn('id: "' + page + '"', settings)
        self.assertIn("nmcli radio wifi toggle", settings)
        self.assertIn("bluetoothctl power toggle", settings)
        self.assertIn("http://localhost:631", settings)
        self.assertIn("SettingsDropdown", settings)
        self.assertIn("Change the size of text, apps, and other items", settings)
        self.assertIn("scaleDropdown", settings)
        self.assertIn("Display resolution", settings)
        self.assertIn("Display orientation", settings)
        self.assertIn("setResolution", settings)
        self.assertIn("setOrientation", settings)
        self.assertIn("Windows Security", settings)
        self.assertIn("security-state.sh", settings)

    def test_windows_theme_applies_taskbar_and_rolls_back(self):
        gtk3 = self.home / ".config/gtk-3.0"
        gtk3.mkdir(parents=True)
        (gtk3 / "gtk.css").write_text("/* old gtk css */\n")
        (gtk3 / "settings.ini").write_text("[Settings]\ngtk-theme-name=Old\n")
        self.run_tool("ui-hook.py", "windows-10", theme=WINDOWS)
        config = self.read_config()
        self.assertEqual(config["bar"]["position"], "bottom")
        self.assertEqual(config["bar"]["background"], "opaque")
        self.assertEqual(config["bar"]["layout"]["left"], [{"id": "brajam.windows-taskbar"}])
        self.assertEqual(config["bar"]["layout"]["right"][0], {"id": "brajam.windows-tray"})
        self.assertEqual(config["bar"]["layout"]["right"][-1], {"id": "brajam.windows-clock"})
        self.assertIn({"id": "brajam.windows-taskbar"}, config["plugins"])
        self.assertIn({"id": "brajam.windows-clock"}, config["plugins"])
        self.assertIn({"id": "brajam.windows-tray"}, config["plugins"])
        self.assertIn("brajam.dock", config["disabledPlugins"])
        self.assertEqual(config["windowsTaskbar"]["pinned"],
                         ["org.gnome.Nautilus", "chromium", "foot", "libreoffice-writer"])
        env_file = self.home / ".config/environment.d/90-windows-10.conf"
        self.assertIn("GTK_CSD=0", env_file.read_text())
        self.assertIn("Windows 10 look", (self.home / ".config/gtk-3.0/gtk.css").read_text())
        self.assertIn("Windows 10 look", (self.home / ".config/gtk-4.0/gtk.css").read_text())
        self.assertIn("gtk-decoration-layout=menu:minimize,maximize,close",
                      (self.home / ".config/gtk-4.0/settings.ini").read_text())
        css = (self.home / ".config/gtk-4.0/gtk.css").read_text()
        self.assertIn("windowcontrols", css)
        self.assertIn("windowcontrols > button > image", css)
        self.assertIn("#e81123", css)
        self.assertIn("Selawik", css)
        shim = (WINDOWS / "gtk/title-left-shim.c").read_text()
        self.assertIn("hdy_header_bar_pack_start", shim)
        self.assertIn("adw_header_bar_pack_start", shim)
        self.assertIn("windows-title-left", shim)
        self.assertTrue((WINDOWS / "gtk/build-shim.sh").is_file())
        lua = (WINDOWS / "hyprland.lua").read_text()
        self.assertIn("libtitleleft.so", lua)
        self.assertIn('hl.env("LD_PRELOAD"', lua)

        self.run_tool("ui-hook.py", "gruvbox", theme=WINDOWS)
        after = self.read_config()
        for key, value in self.before.items():
            self.assertEqual(after[key], value)
        self.assertFalse((self.home / ".local/state/omarchy/windows-10-ui.json").exists())
        self.assertFalse(env_file.exists())
        self.assertEqual((self.home / ".config/gtk-3.0/gtk.css").read_text(), "/* old gtk css */\n")
        self.assertIn("gtk-theme-name=Old", (self.home / ".config/gtk-3.0/settings.ini").read_text())
        self.assertFalse((self.home / ".local/state/omarchy/windows-10-gtk.json").exists())
        self.assertFalse((self.home / ".local/state/omarchy/windows-10-env.json").exists())

    def test_dark_outline_setting_preserves_light_dock_and_pins(self):
        for action, expected in [("on", True), ("off", False)]:
            self.run_tool("dark-border.sh", action)
            dock = self.read_config()["dock"]
            self.assertEqual(dock["goldenGateDarkBorders"], expected)
            self.assertEqual(dock["pinned"], ["keep.app"])
            self.assertNotIn("showBorder", dock)
            self.assertEqual((self.home / ".local/state/omarchy/golden-gate-dark-borders").read_text().strip(), action)
        before = self.config.read_bytes()
        self.assertEqual(self.run_tool("dark-border.sh", "invalid", check=False).returncode, 2)
        self.assertEqual(self.config.read_bytes(), before)

    def test_shell_borders_are_scoped_to_dark_theme_and_reversible(self):
        current = self.home / ".local/state/omarchy/current"
        theme = current / "theme"
        theme.mkdir(parents=True)
        (current / "theme.name").write_text("macos-2027-golden-gate-dark\n")
        shell = theme / "shell.toml"
        shell.write_text('[popups]\nbackground = "#123456"\nborder-width = 3\n[menu]\ntext = "#abcdef"\n')
        (theme / "colors.toml").write_text('[colors]\n')
        flag = current.parent / "golden-gate-dark-borders"
        for action, width in [("off", "0"), ("on", "1")]:
            flag.write_text(action + "\n")
            self.run_tool("shell-borders.py", "")
            result = shell.read_text()
            self.assertEqual(result.count("border-width = " + width), 2)
            self.assertIn('background = "#123456"', result)
        (current / "theme.name").write_text("macos-2027-golden-gate\n")
        before = shell.read_bytes()
        flag.write_text("off\n")
        self.run_tool("shell-borders.py", "")
        self.assertEqual(shell.read_bytes(), before)


if __name__ == "__main__":
    unittest.main()
