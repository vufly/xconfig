"""Regression checks for Pi MCP config. Run: python3 -m unittest discover -s tests."""

import json
import unittest

from test_fff_config import MAGY_PATHS, render


class PiMCPConfigTests(unittest.TestCase):
    def assert_config(self, current="", platform="linux", magy=None):
        output = render("pi-mcp.json", current, platform, magy=magy)
        parsed = json.loads(output)
        self.assertNotIn("\r", output)
        self.assertFalse(output.startswith("\ufeff"))
        self.assertTrue(output.endswith("\n"))
        self.assertEqual(render("pi-mcp.json", output, platform, magy=magy), output)
        return parsed

    def test_empty_input_on_each_platform(self):
        for platform, command in MAGY_PATHS.items():
            with self.subTest(platform=platform):
                server = self.assert_config(platform=platform)["mcpServers"]["magy"]
                self.assertEqual(server["command"], command)
                self.assertEqual(server["exposure"], "codemode")
                self.assertIn("Agy", server["description"])

    def test_preserves_other_servers_and_local_preferences(self):
        preferences = {
            "enabled": False,
            "exposure": "deferred",
            "toolExposure": {"profiles": "direct"},
            "timeout": 90,
            "env": {"MAGY_HOME": "/custom/state"},
            "cwd": "~/repos",
        }
        current = {
            "autoEnableCodemode": False,
            "mcpServers": {
                "other": {"url": "https://example.com/mcp"},
                "magy": {"command": "old-magy-mcp", **preferences},
            },
        }
        parsed = self.assert_config(json.dumps(current))
        self.assertFalse(parsed["autoEnableCodemode"])
        self.assertEqual(parsed["mcpServers"]["other"], current["mcpServers"]["other"])
        server = parsed["mcpServers"]["magy"]
        self.assertEqual(server["command"], MAGY_PATHS["linux"])
        for key, value in preferences.items():
            self.assertEqual(server[key], value)

    def test_missing_magy_removes_only_managed_server(self):
        current = {
            "autoEnableCodemode": False,
            "mcpServers": {
                "other": {"command": "other-mcp"},
                "magy": {"command": "old-magy-mcp"},
            },
        }
        parsed = self.assert_config(json.dumps(current), magy="")
        self.assertNotIn("magy", parsed["mcpServers"])
        self.assertEqual(parsed["mcpServers"]["other"], current["mcpServers"]["other"])
        self.assertFalse(parsed["autoEnableCodemode"])
        self.assertEqual(self.assert_config(magy=""), {"mcpServers": {}})

    def test_path_with_spaces_and_unicode(self):
        command = r"C:\Users\Test User\工具\magy-mcp.exe"
        parsed = self.assert_config(platform="windows", magy=command)
        self.assertEqual(parsed["mcpServers"]["magy"]["command"], command)

    def test_bom_and_crlf_input(self):
        parsed = self.assert_config(
            "\ufeff" + json.dumps({"mcpServers": {"other": {"command": "keep"}}}, indent=2)
            .replace("\n", "\r\n")
        )
        self.assertEqual(parsed["mcpServers"]["other"], {"command": "keep"})


if __name__ == "__main__":
    unittest.main()
