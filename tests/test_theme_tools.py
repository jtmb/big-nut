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
        self.env = dict(os.environ, HOME=str(self.home), XDG_STATE_HOME=str(self.home / ".local/state"), OMARCHY_PATH="/usr/share/omarchy",
                        PATH=str(stub.parent) + os.pathsep + os.environ["PATH"])

    def read_config(self):
        return json.loads(self.config.read_text())

    def run_tool(self, name, value, check=True):
        interpreter = "python3" if name.endswith(".py") else "bash"
        return subprocess.run([interpreter, str(THEME / name), value], env=self.env,
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
