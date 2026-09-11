"""Regression checks for the FFF templates. Run: python3 -m unittest discover -s tests."""

import json
from pathlib import Path
import subprocess
import tomllib
import unittest


ROOT = Path(__file__).resolve().parents[1]
TEMPLATES = ROOT / "chezmoi" / ".chezmoitemplates"
PROVIDER = '[model_providers.cliproxyapi]\nname = "OpenAI"\n'
MISE_PATHS = {
    "linux": "/home/test/.local/bin/mise",
    "darwin": "/opt/homebrew/bin/mise",
    "windows": r"C:\ProgramData\chocolatey\bin\mise.exe",
}


def render(name, current="", platform="linux", mise=None):
    """Stub host discovery and credentials; execute the real template with chezmoi."""
    mise = MISE_PATHS[platform] if mise is None else mise
    source = (TEMPLATES / name).read_text(encoding="utf-8")
    source = source.replace('lookPath "mise"', ".testMise")
    source = source.replace('lookPath "bw"', '""')
    data = {"testMise": mise, "machine": "test", "chezmoi": {"os": platform}}
    result = subprocess.run(
        [
            "chezmoi",
            "--source", str(ROOT / "chezmoi"),
            "--override-data", json.dumps(data),
            "execute-template", "--with-stdin", source,
        ],
        input=current.encode("utf-8"), capture_output=True, check=True,
    )
    return result.stdout.decode("utf-8")


class FFFConfigTests(unittest.TestCase):
    def assert_codex(self, current, platform="linux"):
        output = render("codex-config.toml", current, platform)
        parsed = tomllib.loads(output)
        self.assertEqual(parsed["mcp_servers"]["fff"], {
            "command": MISE_PATHS[platform], "args": ["exec", "--", "fff-mcp"],
        })
        self.assertNotIn("\r", output)
        self.assertFalse(output.startswith("\ufeff"))
        self.assertTrue(output.endswith("\n"))
        self.assertEqual(render("codex-config.toml", output, platform), output)
        return output, parsed

    def test_empty_input_on_each_platform(self):
        for platform in MISE_PATHS:
            with self.subTest(platform=platform):
                _, parsed = self.assert_codex("", platform)
                self.assertEqual(parsed["features"], {"hooks": True})

    def test_preserves_runtime_sections(self):
        runtime = '''[features]
hooks = false

[projects."/home/test/project"]
trust_level = "trusted"

[mcp_servers.other]
command = "other-mcp"
args = ["--verbose"]

[mcp_servers.fff_extra]
command = "unrelated"

[hooks.state."/home/test/hooks.json:stop:0:0"]
enabled = true
'''
        _, parsed = self.assert_codex(PROVIDER + runtime)
        del parsed["mcp_servers"]["fff"]
        for key, value in tomllib.loads(runtime).items():
            self.assertEqual(parsed[key], value)

    def test_preserves_top_level_settings_and_other_providers(self):
        current = '''model = "gpt-6-astra"
model_reasoning_effort = "high"
approvals_reviewer = "user"

[model_providers.other]
name = "Keep this provider"
base_url = "http://localhost:1234/v1"

[features]
hooks = false
'''
        _, parsed = self.assert_codex(current)
        original = tomllib.loads(current)
        for key in ("model", "model_reasoning_effort", "approvals_reviewer", "features"):
            self.assertEqual(parsed[key], original[key])
        self.assertEqual(parsed["model_providers"]["other"], original["model_providers"]["other"])

    def test_replaces_existing_fff_and_subtables(self):
        for header in (
            "[mcp_servers.fff]",
            '[ "mcp_servers" . "fff" ] # existing server',
            "['mcp_servers'.'fff']",
        ):
            with self.subTest(header=header):
                current = PROVIDER + f'''[features]
hooks = false

{header}
command = "/old/version/fff-mcp"
args = ["--old-flag"]
enabled = false

[mcp_servers.fff.env]
OLD_SETTING = "old"

[mcp_servers.other]
command = "keep-me"

[tui]
theme = "light"
'''
                output, parsed = self.assert_codex(current)
                self.assertNotIn("OLD_SETTING", output)
                self.assertEqual(parsed["features"], {"hooks": False})
                self.assertEqual(parsed["mcp_servers"]["other"], {"command": "keep-me"})
                self.assertEqual(parsed["tui"], {"theme": "light"})

    def test_fff_only_input(self):
        self.assert_codex(PROVIDER + '[mcp_servers.fff]\ncommand = "old"\n')

    def test_multiline_value_with_fff_header(self):
        runtime = '''[mcp_servers.other]
command = "other"
instructions = """Example configuration:
[mcp_servers.fff]
command = "example"
"""

[mcp_servers.fff]
command = "old"
'''
        _, parsed = self.assert_codex(PROVIDER + runtime)
        self.assertEqual(parsed["mcp_servers"]["other"], tomllib.loads(runtime)["mcp_servers"]["other"])

    def test_inline_fff_table(self):
        runtime = '[mcp_servers]\nfff = { command = "old" }\nother = { command = "keep-me" }\n'
        _, parsed = self.assert_codex(PROVIDER + runtime)
        self.assertEqual(parsed["mcp_servers"]["other"], {"command": "keep-me"})

    def test_crlf_input_normalized(self):
        self.assert_codex((PROVIDER + "[features]\nhooks = true\n").replace("\n", "\r\n"))

    def test_mise_and_opencode_on_each_platform(self):
        for platform, mise in MISE_PATHS.items():
            with self.subTest(platform=platform):
                config = tomllib.loads(render("mise-config.toml", platform=platform))
                self.assertEqual(config["tool_alias"]["fff-mcp"], "github:dmtrKovalenko/fff")
                self.assertEqual(config["tools"]["fff-mcp"], {
                    "version": "latest", "matching": "fff-mcp-", "bin": "fff-mcp",
                })
                output = render("opencode.json", platform=platform)
                self.assertNotIn("\r", output)
                config = json.loads(output)
                self.assertEqual(config["mcp"]["fff"], {
                    "type": "local", "command": [mise, "exec", "--", "fff-mcp"],
                    "enabled": True,
                })

    def test_path_with_spaces_and_unicode(self):
        mise = r"C:\Users\Test User\工具\mise.exe"
        codex = tomllib.loads(render("codex-config.toml", platform="windows", mise=mise))
        opencode = json.loads(render("opencode.json", platform="windows", mise=mise))
        self.assertEqual(codex["mcp_servers"]["fff"]["command"], mise)
        self.assertEqual(opencode["mcp"]["fff"]["command"][0], mise)

    def test_missing_mise_fails_clearly(self):
        for name in ("codex-config.toml", "opencode.json"):
            with self.subTest(template=name):
                with self.assertRaises(subprocess.CalledProcessError) as error:
                    render(name, mise="")
                self.assertIn(b"mise must be installed and on PATH", error.exception.stderr)


if __name__ == "__main__":
    unittest.main()
