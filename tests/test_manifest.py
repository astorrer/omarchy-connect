#!/usr/bin/python3
import json
import re
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class ManifestTest(unittest.TestCase):
    def setUp(self):
        self.manifest = json.loads((ROOT / "manifest.json").read_text(encoding="utf-8"))

    def test_required_fields(self):
        self.assertEqual(self.manifest["schemaVersion"], 1)
        for field in ("id", "name", "version", "author", "description", "kinds", "entryPoints"):
            self.assertIn(field, self.manifest)
        self.assertTrue(self.manifest["id"])
        self.assertFalse(self.manifest["id"].startswith("omarchy."))
        self.assertNotIn("..", self.manifest["id"])
        self.assertIsInstance(self.manifest["kinds"], list)
        self.assertGreater(len(self.manifest["kinds"]), 0)
        self.assertIn("bar-widget", self.manifest["kinds"])

    def test_entry_points_exist(self):
        points = self.manifest["entryPoints"]
        self.assertIsInstance(points, dict)
        self.assertIn("barWidget", points)
        for key, rel in points.items():
            self.assertFalse(rel.startswith("/"), key)
            self.assertNotIn("..", rel)
            self.assertTrue((ROOT / rel).is_file(), rel)

    def test_default_section(self):
        section = self.manifest.get("barWidget", {}).get("defaultSection")
        if section is not None:
            self.assertIn(section, ("left", "center", "right"))

    def test_no_plugin_symlinks(self):
        skip = {".git"}
        for path in ROOT.rglob("*"):
            if any(part in skip for part in path.parts):
                continue
            self.assertFalse(path.is_symlink(), f"symlink not allowed: {path}")

    def test_footer_version_matches_manifest(self):
        model = (ROOT / "Model.js").read_text(encoding="utf-8")
        match = re.search(r'PLUGIN_VERSION = "([^"]+)"', model)
        self.assertIsNotNone(match, "PLUGIN_VERSION missing from Model.js")
        self.assertEqual(match.group(1), self.manifest["version"])

    def test_stdlib_modules_have_no_gi(self):
        for name in ("contacts.py", "messages.py", "notice.py", "util.py"):
            text = (ROOT / "connectlib" / name).read_text(encoding="utf-8")
            self.assertNotIn("import gi", text, name)
            self.assertNotIn("gi.repository", text, name)

    def test_sms_app_names_match_model(self):
        sys.path.insert(0, str(ROOT))
        from connectlib.notice import SMS_APP_NAMES

        model = (ROOT / "Model.js").read_text(encoding="utf-8")
        block = re.search(r"var SMS_APP_NAMES = \{([^}]+)\}", model)
        self.assertIsNotNone(block)
        js_names = set(re.findall(r'"([^"]+)"', block.group(1)))
        self.assertEqual(js_names, set(SMS_APP_NAMES))


if __name__ == "__main__":
    unittest.main()
