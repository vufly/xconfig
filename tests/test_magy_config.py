"""Regression checks for Magy chezmoi template. Run: python3 -m unittest discover -s tests."""

import json
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
TEMPLATES = ROOT / "chezmoi" / ".chezmoitemplates"


def render(name: str, current: str = "", platform: str = "linux") -> str:
    source = (TEMPLATES / name).read_text(encoding="utf-8")
    data = {"machine": "test", "chezmoi": {"os": platform}}
    result = subprocess.run(
        [
            "chezmoi",
            "--source", str(ROOT / "chezmoi"),
            "--override-data", json.dumps(data),
            "execute-template", "--with-stdin", source,
        ],
        input=current.encode("utf-8"),
        capture_output=True,
        check=True,
    )
    return result.stdout.decode("utf-8")


class MagyConfigTests(unittest.TestCase):
    def test_magy_config_renders_on_all_platforms(self):
        for platform in ("linux", "darwin", "windows"):
            with self.subTest(platform=platform):
                output = render("magy-config.json", platform=platform)
                parsed = json.loads(output)
                self.assertEqual(parsed["agy_resolver"], ["mise", "which", "agy"])
                self.assertNotIn("\r", output)
                self.assertTrue(output.endswith("\n"))


if __name__ == "__main__":
    unittest.main()
