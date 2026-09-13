"""Check installation with isolated paths; never change HOME or control real apps."""
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class InstallationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="harmony-test-", dir=os.environ.get("HARMONY_TEST_TMPDIR"))
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.user = self.root / "User with spaces"
        self.user.mkdir()
        self.xdg = self.user / ".config"
        self.support = self.xdg / "aerospace"
        self.project = self.root / "source"
        self.project.mkdir()
        for name in ["aerospace.toml", "ghostty.conf"]:
            shutil.copyfile(ROOT / name, self.project / name)
        self.write(self.project / "build.sh", '''#!/bin/bash
set -eu
project_dir="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$project_dir/bin"
printf 'fake helper\\n' > "$project_dir/bin/aerospace-shortcuts"
''', executable=True)

    def write(self, path, text, executable=False):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
        if executable:
            path.chmod(0o755)
        return path

    def shell(self, script, *args, env=None):
        return subprocess.run(["/bin/bash", "-c", 'source "$1/install.sh"\n' + script,
                               "test", str(ROOT), *map(str, args)],
                              text=True, capture_output=True, env=env)

    def install(self, ghostty=False, dry_run=False):
        return self.shell('install_payload "$2" "$3" "$4" "$5" "$6"',
                          self.project, self.user, self.xdg, "yes" if ghostty else "no",
                          "--dry-run" if dry_run else "")

    def assert_ok(self, result):
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_clean_install_without_ghostty(self):
        self.assert_ok(self.install())
        self.assertEqual((self.user / ".aerospace.toml").read_bytes(), (ROOT / "aerospace.toml").read_bytes())
        self.assertTrue(os.access(self.support / "bin/aerospace-shortcuts", os.X_OK))
        self.assertFalse((self.support / "ghostty.conf").exists())
        self.assertFalse((self.support / "backups").exists())

    def test_ghostty_preserves_settings_backs_up_and_is_repeatable(self):
        original = '# My settings\nfont-size = 17\nconfig-file = custom.conf\nkeybind = super+t=new_tab'
        config = self.write(self.xdg / "ghostty/config", original)
        config.chmod(0o600)
        self.write(self.user / ".aerospace.toml", "# Previous AeroSpace configuration\n")
        self.write(self.support / "bin/aerospace-shortcuts", "previous helper")
        self.assert_ok(self.install(ghostty=True))
        installed = config.read_text()
        self.assertEqual(config.stat().st_mode & 0o777, 0o600)
        include = f'config-file = "{self.support}/ghostty.conf"'
        self.assertTrue(installed.startswith(original + "\n"))
        self.assertEqual(installed.splitlines()[-1], include)
        backups = list((self.support / "backups").iterdir())
        self.assertEqual(len(backups), 1)
        self.assertEqual((backups[0] / "ghostty-config").read_text(), original)
        self.assertEqual((backups[0] / "aerospace-shortcuts").read_text(), "previous helper")
        self.assert_ok(self.install(ghostty=True))
        self.assertEqual(config.read_text(), installed)
        self.assertEqual(list((self.support / "backups").iterdir()), backups)
        # A later user include must not silently undo Harmony when installation is rerun.
        config.write_text(installed + "config-file = later.conf\n")
        self.assert_ok(self.install(ghostty=True))
        self.assertEqual(config.read_text().count(include), 1)
        self.assertEqual(config.read_text().splitlines()[-1], include)

    def test_last_ghostty_location_wins(self):
        mac = self.user / "Library/Application Support/com.mitchellh.ghostty"
        paths = [self.xdg / "ghostty/config.ghostty", self.xdg / "ghostty/config",
                 mac / "config.ghostty", mac / "config"]
        for index, path in enumerate(paths):
            self.write(path, f"# settings {index}\n")
        self.assert_ok(self.install(ghostty=True))
        for index, path in enumerate(paths[:-1]):
            self.assertEqual(path.read_text(), f"# settings {index}\n")
        self.assertIn("AeroSpace Harmony", paths[-1].read_text())

    def test_new_ghostty_config_and_custom_xdg(self):
        self.xdg = self.user / "custom configuration"
        self.assert_ok(self.install(ghostty=True))
        config = self.user / "Library/Application Support/com.mitchellh.ghostty/config"
        self.assertIn(str(self.support / "ghostty.conf"), config.read_text())
        self.assertFalse((self.xdg / "ghostty").exists())

    def test_dry_run_changes_nothing(self):
        config = self.write(self.xdg / "ghostty/config", "font-size = 16\n")
        self.assert_ok(self.install(ghostty=True, dry_run=True))
        self.assertEqual(config.read_text(), "font-size = 16\n")
        self.assertFalse((self.project / "bin").exists())
        self.assertFalse((self.user / ".aerospace.toml").exists())
        self.assertFalse(self.support.exists())

    def test_build_failure_leaves_existing_files_untouched(self):
        config = self.write(self.user / ".aerospace.toml", "original\n")
        ghostty = self.write(self.xdg / "ghostty/config", "original Ghostty\n")
        self.write(self.project / "build.sh", "#!/bin/bash\nexit 1\n", executable=True)
        self.assertNotEqual(self.install(ghostty=True).returncode, 0)
        self.assertEqual(config.read_text(), "original\n")
        self.assertEqual(ghostty.read_text(), "original Ghostty\n")
        self.assertFalse(self.support.exists())

    def test_missing_payload_stops_before_writes_and_cleans_staging(self):
        config = self.write(self.user / ".aerospace.toml", "original\n")
        (self.project / "ghostty.conf").unlink()
        result = self.install(ghostty=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Missing installation file", result.stderr)
        self.assertNotIn("unbound variable", result.stderr)
        self.assertEqual(config.read_text(), "original\n")
        for stage in Path(tempfile.gettempdir()).glob("aerospace-harmony-install.*/ghostty-config"):
            self.assertNotIn(str(self.user), stage.read_text(), "Failed installation left staging files behind")

    def test_symlinks_and_alternate_config_stop_before_build(self):
        target = self.write(self.root / "dotfile", "original\n")
        for path in [self.user / ".aerospace.toml", self.xdg / "ghostty/config"]:
            with self.subTest(path=path):
                path.parent.mkdir(parents=True, exist_ok=True)
                path.symlink_to(target)
                result = self.install(ghostty=True)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("symlink", result.stderr)
                self.assertEqual(target.read_text(), "original\n")
                self.assertFalse((self.project / "bin").exists())
                path.unlink()
        self.write(self.support / "aerospace.toml", "alternate\n")
        self.assertNotEqual(self.install().returncode, 0)
        self.assertFalse((self.project / "bin").exists())

    def test_restart_targets_only_the_exact_helper(self):
        self.write(self.user / "Library/Logs/.keep", "")
        calls = self.root / "calls"
        script = r'''
calls="$3"
pgrep() { return 0; }
fake_cli() { printf 'cli %s\n' "$*" >> "$calls"; }
# Use a literal helper path when producing the process list; ps receives its own arguments.
process_line="101 $2/.config/aerospace/bin/aerospace-shortcuts hotkey"
ps() { printf '%s\n' "$process_line" '102 /unrelated/aerospace-shortcuts hotkey'; }
kill() {
    if [[ "$1" == -0 && "$2" == 101 ]]; then return 1; fi
    if [[ "$1" != -0 ]]; then printf 'kill %s\n' "$*" >> "$calls"; fi
}
sleep() { :; }
nohup() { printf 'helper %s\n' "$*" >> "$calls"; }
activate_harmony fake_cli "$2"
wait
'''
        self.assert_ok(self.shell(script, self.user, calls))
        output = calls.read_text()
        self.assertIn("cli reload-config --no-gui", output)
        self.assertIn("kill 101\n", output)
        self.assertNotIn("102", output)
        self.assertIn(f"helper {self.user}/.config/aerospace/bin/aerospace-shortcuts hotkey", output)

    def test_starts_aerospace_when_it_is_not_running(self):
        result = self.shell('''
pgrep() { return 1; }
open() { printf 'open %s\\n' "$*"; }
activate_harmony unused "$2"
''', self.user)
        self.assert_ok(result)
        self.assertIn("open -a AeroSpace", result.stdout)

    def test_failed_reload_does_not_stop_the_existing_helper(self):
        result = self.shell('''
pgrep() { return 0; }
fake_cli() { return 1; }
kill() { echo UNEXPECTED_KILL; }
activate_harmony fake_cli "$2"
''', self.user)
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("UNEXPECTED_KILL", result.stdout)

    def bootstrap(self, fail=False):
        archive_root = self.root / "archive/harmony-main"
        self.write(archive_root / "aerospace.toml", "config snapshot\n")
        self.write(archive_root / "install.sh", '''#!/bin/bash
set -eu
test -f "$(dirname "$0")/aerospace.toml"
printf 'installer received: %s\\n' "$*"
''')
        archive = self.root / "source.tar.gz"
        with tarfile.open(archive, "w:gz") as handle:
            handle.add(archive_root, arcname="harmony-main")
        fake_bin = self.root / "commands"
        self.write(fake_bin / "curl", '''#!/bin/bash
set -eu
while [[ "$1" != --output ]]; do shift; done
printf '%s' "$2" > "$HARMONY_TEST_DOWNLOAD_PATH"
cp "$HARMONY_TEST_ARCHIVE" "$2"
exit "$HARMONY_TEST_CURL_STATUS"
''', executable=True)
        record = self.root / "download-path"
        environment = dict(os.environ, PATH=f"{fake_bin}:{os.environ['PATH']}",
                           HARMONY_TEST_ARCHIVE=str(archive), HARMONY_TEST_DOWNLOAD_PATH=str(record),
                           HARMONY_TEST_CURL_STATUS="22" if fail else "0")
        result = subprocess.run(["/bin/bash", "-s", "--", "--dry-run"],
                                input=(ROOT / "setup.sh").read_text(), env=environment,
                                text=True, capture_output=True)
        self.assertFalse(Path(record.read_text()).parent.exists(), "Downloaded files were not cleaned up")
        return result

    def test_bootstrap_downloads_before_installing_and_forwards_arguments(self):
        result = self.bootstrap()
        self.assert_ok(result)
        self.assertIn("installer received: --dry-run", result.stdout)

    def test_failed_download_never_runs_installer(self):
        result = self.bootstrap(fail=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("installer received", result.stdout)


if __name__ == "__main__":
    unittest.main()
