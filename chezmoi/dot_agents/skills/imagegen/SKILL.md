---
name: imagegen
description: Generate or edit raster images through Codex ImageGen CLI and configured compatible OpenAI endpoint. Use when users request AI-created photos, illustrations, textures, sprites, mockups, or transparent-background cutouts.
---

# Image Generation Proxy

Use this skill only for bitmap image generation or editing. This global skill proxies Codex's installed system image skill through configured compatible OpenAI endpoint.

## Workflow

1. Read `~/.codex/skills/.system/imagegen/SKILL.md` before work. Read only its relevant references, such as `references/cli.md` for CLI flags or `references/image-api.md` for model constraints.
2. Follow Codex skill's intent, prompting, output, editing, and model-selection guidance. This proxy overrides its execution mode: always use CLI proxy, never built-in `image_gen` tool.
3. Run Codex CLI only through proxy. Do not modify or invoke `~/.codex/skills/.system/imagegen/scripts/image_gen.py` directly.

```sh
uv run --with openai python "$HOME/.agents/skills/imagegen/imagegen_proxy.py" generate \
  --prompt "..." \
  --out output/imagegen/output.png
```

4. For edits, use proxy's `edit` command. For distinct multi-asset work, use its `generate-batch` command only when CLI batch behavior fits request.
5. Report saved output paths, final prompt, and that Codex CLI proxy was used.

## Proxy Contract

- `imagegen_proxy.py` resolves `CODEX_HOME` or defaults to `~/.codex`.
- It injects configured `OPENAI_API_KEY` and `OPENAI_BASE_URL` only into Codex CLI child process.
- It accepts and forwards every CLI argument unchanged.
- It is cross-platform Python. Do not source shell environment files or put credentials in command arguments.
- Use `uv run --with openai` to provide CLI dependency without mutating active Python environment.
- If proxy, Codex skill, Python, or OpenAI SDK is unavailable, report exact missing dependency. Do not create replacement image clients or modify Codex-owned files.

## Guardrails

- Preserve Codex model fallback confirmations. Do not silently switch to `gpt-image-1.5`.
- Preserve edit invariants and write project-bound outputs into workspace.
- Never expose embedded credentials in output, commands, or generated artifacts.
