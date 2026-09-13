"""Exercise app launching without opening apps or moving the user's windows."""
import json
import os
import plistlib
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

HELPER = Path(__file__).resolve().parents[1] / "bin/aerospace-shortcuts"

FAKE = r'''
import json, os, sys
from pathlib import Path
root = Path(os.environ['SHORTCUT_TEST_DIR'])
args = sys.argv[1:]
with (root/'calls.jsonl').open('a') as f:
    f.write(json.dumps([Path(sys.argv[0]).name, args])+'\n')
scenario = os.environ['SHORTCUT_TEST_SCENARIO']
active = (root/'opened').exists()
if Path(sys.argv[0]).name == 'open-app':
    (root/'opened').touch()
elif args[0] == 'list-windows':
    focused = '--focused' in args
    windows = [
        {'window-id': 42, 'app-bundle-id': 'org.example.browser', 'workspace': '3'},
        {'window-id': 43, 'app-bundle-id': 'org.example.browser', 'workspace': 'B'},
    ]
    if focused:
        windows = windows[:1] if active and scenario != 'no-focus' else []
    elif scenario == 'new' and not active:
        windows = []
    print(json.dumps(windows))
'''


class LaunchTest(unittest.TestCase):
    def launch(self, scenario):
        with tempfile.TemporaryDirectory(prefix="aerospace-launch-test-") as directory:
            root = Path(directory)
            for name in ["aerospace", "open-app"]:
                path = root / name
                path.write_text(f"#!{sys.executable}\n" + FAKE)
                path.chmod(0o700)
            browser = root / "Browser.app"
            (browser / "Contents").mkdir(parents=True)
            with (browser / "Contents/Info.plist").open("wb") as stream:
                plistlib.dump({"CFBundleIdentifier": "org.example.browser", "CFBundleName": "Browser"}, stream)
            environment = dict(os.environ, AEROSPACE_BROWSER_APP=str(browser), AEROSPACE_CLI=str(root / "aerospace"),
                               AEROSPACE_APP_OPENER=str(root / "open-app"),
                               SHORTCUT_TEST_DIR=directory, SHORTCUT_TEST_SCENARIO=scenario,
                               AEROSPACE_WINDOW_ID="999", AEROSPACE_WORKSPACE="Z")
            result = subprocess.run([str(HELPER), "launch", "b"], env=environment,
                                    capture_output=True, text=True, timeout=15)
            self.assertEqual(result.returncode, 0, result.stderr)
            return [json.loads(line) for line in (root / "calls.jsonl").read_text().splitlines()]

    def assert_move(self, calls, window_id):
        commands = [args for name, args in calls if name == "aerospace"]
        moves = [args for args in commands if args[0] == "move-node-to-workspace"]
        self.assertEqual(moves, [["move-node-to-workspace", "--window-id", str(window_id),
                                  "--focus-follows-window", "B"]])
        self.assertIn(["focus", "--window-id", str(window_id)], commands)
        self.assertEqual(commands[-1][0], "eval")
        self.assertIn("move-mouse", commands[-1][1])

    def test_existing_selected_window_moves_from_another_workspace(self):
        self.assert_move(self.launch("existing"), 42)

    def test_new_app_waits_for_its_window(self):
        self.assert_move(self.launch("new"), 42)

    def test_fallback_prefers_the_destination_workspace(self):
        self.assert_move(self.launch("no-focus"), 43)


if __name__ == "__main__":
    unittest.main()
