# O24 Script Specification

This document is the source of truth for O24 script behavior. Implementations in `zsh/`, `nu/`, and `powershell/` must remain equivalent.

## Availability

Chezmoi manages the whole `o24/` tree only when the lowercase hostname starts with `ohp`.

Each supported shell prepends its native script directory to `PATH`:

| Shell | Directory | Command |
| --- | --- | --- |
| Zsh | `~/o24/scripts/zsh` | `zportal` |
| Nushell | `~/o24/scripts/nu` | `zportal` |
| PowerShell | `~/o24/scripts/powershell` | `zportal` |

## `zportal [--task]`

`zportal` replaces only the active Zellij tab with the Portal main layout. `zportal --task` replaces it with the Portal task layout. Neither command creates a tab, modifies other tabs, or retains terminal panes outside the layout.

The command reads `~/o24/zellij/portal_main.kdl` or `~/o24/zellij/portal_task.kdl`. Both include shared `zjstatus` configuration and a `cwd="__ZPORTAL_CWD__"` placeholder. The main tab is named `portal`; the task tab name uses the same cwd placeholder.

The command must run inside a Zellij session. The caller current directory becomes the Portal tab cwd. Relative pane directories resolve from it:

- `watch`: `src`, runs `node RUN.js`
- `proxy`: `src/tools`, runs `bun ui-proxy.bun.js`
- `terminal`: `src`
- remaining pane: caller current directory

`portal_task.kdl` uses the same tab template, watch pane, terminal pane, and remaining pane, but omits `proxy`.

Pseudo-code:

```text
layout_name = "portal_task" when --task flag is present, otherwise "portal_main"
layout_path = "~/o24/zellij/{layout_name}.kdl"
fail if layout_path is unreadable

layout = read(layout_path)
fail if layout does not contain "__ZPORTAL_CWD__"

cwd = current_working_directory()
escaped_cwd = kdl_escape(cwd)
layout_string = replace_all(layout, "__ZPORTAL_CWD__", escaped_cwd)

exec zellij action override-layout \
  --apply-only-to-active-tab \
  --layout-string layout_string
```

`kdl_escape` escapes backslash, double quote, newline, carriage return, and tab for a quoted KDL string.

Do not run `zportal` from automation, agents, or test shells unless replacing that shell's active Zellij tab is intentional.
