"""Check managed rule ordering, migration, and preservation of plugin additions."""

from pathlib import Path
import subprocess
import unittest


SOURCE = Path(__file__).resolve().parents[1] / "chezmoi"
BEGIN = "<!-- BEGIN chezmoi-managed rules -->"
END = "<!-- END chezmoi-managed rules -->"
FFF = (SOURCE / ".chezmoitemplates/agent-file-search.md").read_text(encoding="utf-8").rstrip("\n")
TOKEN = (SOURCE / ".chezmoitemplates/agent-token-efficiency.md").read_text(encoding="utf-8").rstrip("\n")
WRAPPERS = {
    "codex": SOURCE / "dot_codex/modify_AGENTS.md",
    "opencode": SOURCE / "dot_config/opencode/modify_AGENTS.md",
}


def render(agent, current):
    result = subprocess.run(
        ["chezmoi", "--source", str(SOURCE), "execute-template", "--with-stdin", "--file", str(WRAPPERS[agent])],
        input=current.encode("utf-8"), capture_output=True, check=True,
    )
    return result.stdout.decode("utf-8")


class AgentRulesTests(unittest.TestCase):
    def check_rules(self, agent, current, external=""):
        output = render(agent, current)
        rules = TOKEN + "\n\n" + FFF
        expected = f"{BEGIN}\n{rules}\n{END}\n"
        if external:
            expected += "\n" + external + "\n"
        self.assertEqual(output, expected)
        self.assertEqual(render(agent, output), output)
        return output

    def test_new_files(self):
        for agent in WRAPPERS:
            with self.subTest(agent=agent):
                self.check_rules(agent, "")

    def test_migrate_codex_rtk_reference(self):
        rtk = "@/home/test/.codex/RTK.md"
        self.check_rules("codex", f"{rtk}\n\n{FFF}\n", rtk)

    def test_migrate_opencode_rules_and_plugin_content(self):
        plugin = "# Plugin instructions\nPreserve this text."
        self.check_rules("opencode", f"{TOKEN}\n\n{FFF}\n\n{plugin}\n", plugin)

    def test_migrate_opencode_before_fff_was_added(self):
        self.check_rules("opencode", TOKEN + "\n")

    def test_plugin_appends_after_apply(self):
        plugin = "<!-- RTK -->\n@/home/test/.codex/RTK.md\n<!-- /RTK -->\n\n# Other plugin\nKeep me."
        for agent in WRAPPERS:
            with self.subTest(agent=agent):
                first = self.check_rules(agent, "")
                self.check_rules(agent, first + "\n" + plugin + "\n", plugin)

    def test_replace_outdated_managed_rules(self):
        self.check_rules("codex", f"{BEGIN}\nOld rules.\n{END}\n\nPlugin text.\n", "Plugin text.")

    def test_external_prefix_moves_after_managed_rules(self):
        self.check_rules("codex", f"Plugin prefix.\n{BEGIN}\nOld rules.\n{END}\nPlugin suffix.", "Plugin prefix.\n\nPlugin suffix.")

    def test_windows_line_endings_and_unicode(self):
        rtk = r"@C:\Users\Test User\.codex\RTK.md"
        plugin = rtk + "\n\n# Notes\n工具"
        self.check_rules("codex", "\ufeff" + (plugin + "\n\n" + FFF).replace("\n", "\r\n"), plugin)

    def test_incomplete_or_duplicate_markers_fail(self):
        for current in (BEGIN, END, f"{END}\n{BEGIN}", f"{BEGIN}\n{END}\n{BEGIN}\n{END}"):
            with self.subTest(current=current):
                with self.assertRaises(subprocess.CalledProcessError) as error:
                    render("codex", current)
                self.assertIn(b"AGENTS.md", error.exception.stderr)


if __name__ == "__main__":
    unittest.main()
