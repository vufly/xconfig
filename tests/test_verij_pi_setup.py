"""Regression checks for the Verij Pi monitoring after-apply hook."""

import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
HOOK = ROOT / "chezmoi/.chezmoiscripts/run_after_setup-verij-pi.sh.tmpl"


def render(platform="linux"):
    return subprocess.run(
        ["chezmoi", "--source", str(ROOT / "chezmoi"),
         "--override-data", json.dumps({"chezmoi": {"os": platform}}),
         "execute-template", "--file", str(HOOK)],
        capture_output=True, text=True, check=True,
    ).stdout


class VerijPiSetupTests(unittest.TestCase):
    def run_hook(self, *, pi=True, verij=True, version="1.2.0", setup_status=0):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            log = root / "setup.log"
            if pi:
                binary = root / "pi"
                binary.write_text(f"#!/bin/sh\nprintf '%s\\n' '{version}'\n")
                binary.chmod(0o755)
            if verij:
                binary = root / "verij"
                binary.write_text(
                    "#!/bin/sh\n"
                    'printf "%s|%s\\n" "$*" "$PI_CODING_AGENT_DIR" >> "$SETUP_LOG"\n'
                    f"exit {setup_status}\n"
                )
                binary.chmod(0o755)
            agent_dir = str(root / "custom agent")
            result = subprocess.run(
                ["/bin/sh"], input=render(), text=True, capture_output=True,
                env={**os.environ, "PATH": directory, "HOME": directory,
                     "PI_CODING_AGENT_DIR": agent_dir, "SETUP_LOG": str(log)},
            )
            return result, log.read_text() if log.exists() else "", agent_dir

    def test_supported_setup_honors_agent_directory(self):
        result, log, agent_dir = self.run_hook()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(log, f"agent setup pi|{agent_dir}\n")

    def test_missing_tools_skip_setup(self):
        for missing in ("pi", "verij"):
            with self.subTest(missing=missing):
                result, log, _ = self.run_hook(**{missing: False})
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(log, "")

    def test_unsupported_version_skips_setup(self):
        result, log, _ = self.run_hook(version="2.0.0")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(log, "")
        self.assertIn("unsupported", result.stderr)

    def test_setup_failure_is_not_silenced(self):
        result, _, _ = self.run_hook(setup_status=7)
        self.assertEqual(result.returncode, 7)

    def test_linux_script_and_other_platforms(self):
        script = render()
        self.assertTrue(script.startswith("#!/bin/sh\n"))
        self.assertNotIn("\r", script)
        self.assertEqual(subprocess.run(["/bin/sh", "-n"], input=script, text=True).returncode, 0)
        for platform in ("windows", "darwin"):
            with self.subTest(platform=platform):
                self.assertEqual(render(platform).strip(), "")


if __name__ == "__main__":
    unittest.main()
