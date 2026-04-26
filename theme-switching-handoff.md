# Theme Switching Handoff

## Goal

Add a manual theme-switch workflow under `chezmoi/scripts` that updates light/dark theme settings across managed configs for `bat`, `delta`/git, and `helix`, while letting `chezmoi` preserve only the live theme line(s).

## Current State

- Added `chezmoi/scripts/executable_set-theme.sh`.
- Added `alias theme="$HOME/scripts/set-theme.sh"` to `chezmoi/dot_zshrc.tmpl`.
- `set-theme.sh` is silent on success and accepts `dark` or `light`.
- The script rewrites:
  - `~/.config/bat/config`
  - `~/.config/helix/config.toml`
  - `~/.gitconfig`
- Windows deployment of `scripts/set-theme.sh` is ignored in `chezmoi/.chezmoiignore` for now.

## Managed Config Strategy

- Replaced direct `chezmoi` management of some target files with cross-platform `modify_` templates.
- `bat` now uses `chezmoi/dot_config/bat/modify_config`.
- `gitconfig` now uses `chezmoi/modify_dot_gitconfig`.
- `helix` now uses `chezmoi/dot_config/helix/modify_config.toml`.
- This keeps the active theme value from local edits while still managing the rest of each file through `chezmoi`.

## Theme Values

- `bat`
  - dark: `bearded-theme-monokai-stone`
  - light: `bearded-theme-milkshake-vanilla`
- `delta`
  - dark: `dark = true`
  - dark theme: `syntax-theme = "bearded-theme-monokai-stone"`
  - light: `light = true`
  - light theme: `syntax-theme = "bearded-theme-milkshake-vanilla"`
- `helix`
  - dark: `theme = "bearded-theme-monokai-stone"`
  - light: `theme = "bearded-theme-milkshake-vanilla"`

## Key Decisions

- Prefer config-file-based theme switching over env vars so the change applies everywhere without re-sourcing shells.
- Prefer native `chezmoi` `modify_` templates over shell-based `modify_config` scripts for managed files because they are more portable.
- Keep `bat` reference theme lines commented rather than active so the script-controlled `--theme="..."` line remains authoritative.
- Use delta theme slug names instead of display names.
- Do not source `set-theme.sh`; it uses `set -eu`, and sourcing it can affect the current shell.

## Validation Done

- `sh -n chezmoi/scripts/executable_set-theme.sh`
- `zsh -n chezmoi/dot_zshrc.tmpl`
- `chezmoi managed`
- `chezmoi cat` for the relevant files

## Remaining Cross-Platform Work

- Implement a Windows-compatible equivalent for manual theme switching.
- Decide whether the Windows path should be a PowerShell script, a `.cmd` wrapper, or a different `chezmoi`-managed approach.
- Keep the current Linux/macOS behavior unchanged while adding the Windows path.

## Relevant Files

- `chezmoi/scripts/executable_set-theme.sh`
- `chezmoi/.chezmoiignore`
- `chezmoi/dot_zshrc.tmpl`
- `chezmoi/dot_config/bat/modify_config`
- `chezmoi/modify_dot_gitconfig`
- `chezmoi/dot_config/helix/modify_config.toml`
