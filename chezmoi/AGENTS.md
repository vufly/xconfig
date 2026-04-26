# AGENTS

## Theme State

Treat dark/light theme as live local state. `chezmoi` manages file body. Theme scripts manage active theme lines in rendered targets.

Entry points:

- Unix: `chezmoi/scripts/executable_set-theme.sh`
- Windows: `chezmoi/scripts/executable_set-theme.ps1`
- Shell alias: `theme` -> `~/scripts/set-theme.sh`
- PowerShell function: `theme` -> `~/scripts/set-theme.ps1`

Do not edit source templates to force dark or light unless changing default/fallback behavior on purpose.

## `modify_` Pattern

Use `modify_` templates when target file has small local state that must survive `chezmoi apply`.

Current theme-managed files:

- `dot_config/bat/modify_config`
- `modify_dot_gitconfig`
- `dot_config/helix/modify_config.toml`
- `AppData/Roaming/helix/modify_config.toml`

Rule:

- script rewrites live target file
- `modify_` template reads current target through `.chezmoi.stdin`
- template re-renders full file while preserving current theme value

If script changes exact theme line shape, update matching `modify_` template too.

Theme line contract:

- `bat`: `--theme="..."`
- `git delta`: `dark = true` or `light = true`, plus `syntax-theme = "..."`
- `helix`: `theme = "..."`

## Thin Wrapper Pattern

Prefer thin wrappers at managed target paths. Put real config bodies in `.chezmoitemplates`.

Why:

- keep target path logic in wrapper
- share one body across Windows and Unix targets
- keep real file extension for editor syntax highlighting

Examples:

- `dot_config/helix/modify_config.toml` -> `.chezmoitemplates/helix-config.toml`
- `AppData/Roaming/helix/modify_config.toml` -> `.chezmoitemplates/helix-config.toml`
- `dot_config/lazygit/config.yml.tmpl` -> `.chezmoitemplates/lazygit.yml`
- `AppData/Local/lazygit/config.yml.tmpl` -> `.chezmoitemplates/lazygit.yml`
- `dot_wezterm.lua.tmpl` -> `.chezmoitemplates/wezterm.lua`

Use this pattern for new managed files when body is large or shared.

## Windows Path Divergence

Do not assume Windows uses same target path as Unix.

Current divergence:

- Helix target is `%AppData%/helix/config.toml` on Windows, not `$HOME/.config/helix/config.toml`
- Lazygit target is `AppData/Local/lazygit/config.yml` on Windows

When Windows and Unix paths diverge:

1. keep shared body in `.chezmoitemplates`
2. add per-target wrapper files
3. gate opposite-platform targets in `.chezmoiignore`
4. update helper scripts to write live path for each platform

## Change Rules

When changing theme-managed config:

1. update live-write script
2. update matching `modify_` template
3. keep wrapper thin
4. keep shared body in `.chezmoitemplates`

If unsure whether value is live local state or declarative config, prefer preserving local state and ask before flattening into static template.
