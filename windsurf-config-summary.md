# Windsurf Config Summary

- One script: `others/generate-opencode-provider-config.mjs`.
- Fetches model ids from `http://localhost:50731/v1/models`.
- Fetches limits and base names from `https://models.dev/api.json`.
- Writes `chezmoi/dot_config/opencode/opencode.json` and `zed_config.json`.
- Replaces only `provider.windsurf` inside opencode config.
- Zed output uses `language_models.openai_compatible.Windsurf`.
- Naming rule: prefer local `/v1/models` `name`; otherwise use matched `models.dev` base name plus suffixes from local id: `None`, `Low`, `Medium`, `High`, `XHigh`, `Fast`, `Priority`, `Minimal`, `Max`, `Thinking`, `1M`.
- `-1m` forces `context: 1000000`.
- Removed standalone `others/generate-zed-windsurf-config.mjs` after merging.
- Verified: `claude-sonnet-4.6-1m` -> `Claude Sonnet 4.6 1M`.
- Verified: `claude-opus-4-7-medium-thinking` -> `Claude-Opus-4.7 Medium Thinking`.
- Verified: `gpt-5-4-none-priority` -> `GPT-5.4 None Priority`.
- Current unresolved limits: `swe-1.5`, `swe-1.5-fast`, `swe-1.5-thinking`, `swe-1.6`, `swe-1.6-fast`.
