"""Regression checks for mise npm build approvals."""

import json
from pathlib import Path
import subprocess
import tomllib
import unittest


ROOT = Path(__file__).resolve().parents[1]


class MiseConfigTests(unittest.TestCase):
    def test_npm_build_approvals_on_each_platform(self):
        for platform in ("linux", "darwin", "windows"):
            for machine in ("test", "ohp360-wsl"):
                with self.subTest(platform=platform, machine=machine):
                    result = subprocess.run(
                        [
                            "chezmoi", "--source", str(ROOT / "chezmoi"),
                            "--override-data", json.dumps({
                                "machine": machine,
                                "chezmoi": {"os": platform},
                            }),
                            "execute-template",
                            '{{ includeTemplate ".chezmoitemplates/mise-config.toml" . }}',
                        ],
                        capture_output=True, text=True, check=True,
                    )
                    config = tomllib.loads(result.stdout)
                    self.assertEqual(
                        config["tool_alias"]["claude-code"],
                        "npm:@anthropic-ai/claude-code",
                    )
                    expected = {"claude-code": "@anthropic-ai/claude-code"}
                    if machine == "ohp360-wsl":
                        expected["agent-browser"] = "agent-browser"
                    else:
                        self.assertNotIn("agent-browser", config["tools"])
                    for tool, package in expected.items():
                        self.assertEqual(config["tools"][tool], {
                            "version": "latest", "allow_builds": [package],
                        })
                    self.assertNotIn("allowBuilds", result.stdout)


if __name__ == "__main__":
    unittest.main()
