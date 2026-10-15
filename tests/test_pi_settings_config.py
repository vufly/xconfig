"""Regression checks for Pi settings config. Run: python3 -m unittest discover -s tests."""

import json
import unittest

from tests.test_fff_config import render


class PiSettingsConfigTests(unittest.TestCase):
    def assert_config(self, current="", platform="linux"):
        output = render("pi-settings.json", current, platform)
        parsed = json.loads(output)
        self.assertNotIn("\r", output)
        self.assertFalse(output.startswith("\ufeff"))
        self.assertTrue(output.endswith("\n"))
        self.assertEqual(render("pi-settings.json", output, platform), output)
        return parsed

    def test_empty_input_defaults(self):
        parsed = self.assert_config()
        self.assertEqual(
            parsed["theme"],
            "bearded-theme-milkshake-vanilla/bearded-theme-monokai-stone",
        )
        self.assertIn("npm:pi-pigment", parsed["packages"])
        self.assertEqual(parsed["transport"], "websocket-cached")

    def test_preserves_local_preferences(self):
        current = {
            "defaultThinkingLevel": "high",
            "fullscreenExitOutput": "transcript",
            "customKey": "preserved",
            "theme": "old-theme",
        }
        parsed = self.assert_config(json.dumps(current))
        self.assertEqual(parsed["defaultThinkingLevel"], "high")
        self.assertEqual(parsed["fullscreenExitOutput"], "transcript")
        self.assertEqual(parsed["customKey"], "preserved")
        self.assertEqual(
            parsed["theme"],
            "bearded-theme-milkshake-vanilla/bearded-theme-monokai-stone",
        )


if __name__ == "__main__":
    unittest.main()
