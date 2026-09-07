#!/usr/bin/python3
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SETUP = ROOT / "setup.sh"
AUTOSTART_REL = Path(".config/autostart/kdeconnectd.desktop")


class SetupUninstallTest(unittest.TestCase):
    def _uninstall(self, home: Path) -> subprocess.CompletedProcess:
        return subprocess.run(
            [str(SETUP), "uninstall"],
            env={**os.environ, "HOME": str(home)},
            cwd=str(ROOT),
            capture_output=True,
            text=True,
            check=True,
        )

    def _write_autostart(self, home: Path, comment: str) -> Path:
        path = home / AUTOSTART_REL
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(
            "[Desktop Entry]\n"
            "Type=Application\n"
            "Name=KDE Connect\n"
            f"Comment={comment}\n"
            "Exec=/usr/bin/kdeconnectd\n",
            encoding="utf-8",
        )
        return path

    def test_uninstall_removes_new_autostart_mark(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            path = self._write_autostart(home, "Phone connect daemon for Konnectarchy")
            result = self._uninstall(home)
            self.assertFalse(path.exists())
            self.assertIn(str(path), result.stdout)

    def test_uninstall_removes_legacy_autostart_mark(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            path = self._write_autostart(home, "Phone connect daemon for Connect")
            result = self._uninstall(home)
            self.assertFalse(path.exists())
            self.assertIn(str(path), result.stdout)

    def test_uninstall_leaves_foreign_autostart(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            path = self._write_autostart(home, "Started by the user")
            result = self._uninstall(home)
            self.assertTrue(path.exists())
            self.assertIn("No Konnectarchy autostart entry found.", result.stdout)


if __name__ == "__main__":
    unittest.main()
