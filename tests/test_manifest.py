#!/usr/bin/python3
import json
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


if __name__ == "__main__":
    unittest.main()
