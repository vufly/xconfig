# Reduce Atuin selection-to-prompt latency

## Status

Atuin's Up Arrow binding is disabled in Zsh, Nushell, and PowerShell while Ctrl+R is retained. A guarded Zsh redraw adaptation is implemented in `chezmoi/dot_config/zsh/atuin.zsh`, sourced after Atuin initialization. Broader prompt caching remains deferred.

## Findings

- Installed Atuin at investigation time: `18.22.0`. The live config matches `chezmoi/.chezmoitemplates/atuin-config.toml`.
- Zsh initializes Atuin in `chezmoi/.chezmoitemplates/.zshrc`. Nushell and PowerShell use their corresponding shared templates.
- `enter_accept = false` returns the selected command for editing.
- The reported delay occurs when returning to the prompt, mainly inside Git repositories.
- Atuin's installed Zsh `_atuin_search` widget calls `zle reset-prompt` after search returns.
- `chezmoi/dot_config/zsh/prompt.zsh` sets `PROMPT` to a command substitution. Every reset reruns the full Cailoxo renderer, including `git status`, ahead/behind counts, stash listing, and numerous Git metadata queries.
- Read-only timing, with background fetch disabled for measurement: **147–158 ms** per render in xconfig, **48–52 ms** in home. This confirms avoidable redraw cost but does not reproduce the reported seconds-long pause.
- Installed zsh-autosuggestions already enables asynchronous suggestions. Adding an async flag alone offers no demonstrated improvement.

## Investigation

Measure selection-to-editable-buffer latency in an affected repository. Compare the normal prompt with a temporary static prompt in an isolated diagnostic shell. Separate Atuin exit time, prompt rendering, and Zsh widget/highlighting overhead. Report timings without printing command-history contents.

## Candidate A: Adjust the Atuin return widget

After `atuin init zsh`, adapt only the `_atuin_search` function's prompt-redraw operation. Replace `zle reset-prompt` with `zle .redisplay`, which redisplays the edit buffer without explicitly requesting prompt re-expansion. ZLE still refreshes its invalidated display, so this does not eliminate every prompt render.

- Preserve Atuin's search, exit-status handling, bracketed-paste restoration, buffer assignment, and execution behavior.
- Do not override `zle` globally or remove repainting altogether.
- Keep the adaptation in managed shell integration rather than editing the installed Atuin package.
- If modifying the generated function body, guard against changes in upstream function shape. Atuin is installed with the `latest` version policy.
- Validate inline-picker cleanup, multiline prompts, cancellation, selection, and terminal resizing before adopting this approach.
- This candidate is Zsh-specific. Nushell and PowerShell have different shell integration mechanisms.

### Trial results

Pseudo-terminal tests used the installed Atuin picker, the current multiline Cailoxo prompt, and the xconfig working directory. Background Git fetch was disabled to isolate redraw cost. The diagnostic shell did not load other Zsh plugins, and selected commands were not executed.

- Original widget: **295 ms**, two full prompt renders on return.
- Adapted widget: **142 ms**, one full prompt render on return.
- Cancellation: **164 ms**, with the original editable buffer preserved.
- Resize during search: **448 ms**, with the editable buffer preserved; resize still triggered additional prompt renders.

These are individual local trial measurements, not a guarantee for other repositories or a visual verification in WezTerm. They show that the narrow override removes a redundant render. Further reduction requires investigating the remaining render or implementing Candidate B.

## Candidate B: Cache prompt rendering

If measurements confirm prompt redraw is the bottleneck and a broader prompt fix is preferred:

- Add a small managed Zsh prompt adapter, loaded immediately after the generated Cailoxo prompt in `chezmoi/.chezmoitemplates/.zshrc`.
- Render the full prompt once during the normal pre-command-line refresh (`precmd`), then reuse the rendered value on Atuin's `reset-prompt`.
- Refresh the cache after commands, when terminal dimensions change, and when an asynchronous Git update requires fresh display data.
- Preserve exit-status coloring, transient prompt behavior, links, and Git information.
- Keep the adapter in a separate `.zsh` file because the Cailoxo file is generated and explicitly warns against hand edits.

If static-prompt timing does not explain the delay, use the measured slow stage to select a targeted fix before changing configuration.

## Validation

- Check changed Zsh files with `zsh -n`; inspect the rendered Chezmoi diff.
- Apply only the relevant managed targets.
- Compare repeated selection-to-editable-buffer timings in the same affected repository. Aim for under 100 ms on warm returns; report measured results.
- Verify Ctrl+R search, native Up Arrow history, selection/editing, cancellation, normal command completion, directory changes, resize, Git refresh, and transient prompt behavior.
- Run scoped Chezmoi verification and `git diff --check`.

## Expected result

Atuin selection returns without repeating repository scans solely to repaint the prompt. Normal prompt refresh after commands remains responsible for current Git state.

## Nushell and PowerShell evaluation

The Zsh adaptation was accepted after an interactive user trial and committed as `b16d642`. This evaluation does not add redraw overrides for the other shells.

### Nushell 0.115.1

Atuin's generated integration uses an `executehostcommand` keybinding to run search and then `commandline edit` to restore the selected command. It contains no explicit prompt-reset call to replace. Nushell's REPL evaluates its prompt again when it resumes after the host command.

Pseudo-terminal trials in xconfig used the installed Atuin picker and the current Cailoxo prompt, with background fetch suppressed and unrelated hooks excluded:

| Prompt | Three selection-return measurements | Prompt evaluations per return |
| --- | --- | --- |
| Static | 10.3, 25.9, 26.0 ms | 1 |
| Cailoxo | 113.9, 98.4, 109.1 ms | 1 |

Measurements end when prompt generation completes, rather than after physical terminal painting. Selected commands remained editable and were not executed. The roughly 80–100 ms additional cost is consistent with Cailoxo's synchronous Git queries. The duplicate-render optimization from Zsh does not directly apply.

Recommendation: try Cailoxo's existing `gstat` backend first, following the implementation order below. Consider caching or asynchronous updates only after measuring that backend. Avoid replacing the generated Atuin keybinding solely to remove a reset call that is not present.

An additional cancellation check found that both Escape and Ctrl+C returned an empty buffer in the isolated harness, despite a verified ten-character input before opening search. This occurred without any Nushell adaptation. It needs separate confirmation in a normal Nushell session before diagnosing or changing cancellation behavior.

### PowerShell

PowerShell was not installed in the evaluation environment, so these findings come from the installed Atuin binary's generated PowerShell integration, the managed PowerShell profile, and PSReadLine documentation. No PowerShell runtime latency or Windows terminal behavior was measured.

Atuin's `Invoke-AtuinSearch` performs two relevant operations after search:

1. When `ATUIN_POWERSHELL_PROMPT_OFFSET` is unset, it executes the prompt function to count lines and initializes the offset. This adds a prompt evaluation on the first search.
2. On every return, it calls `[Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt($null, $y)`. This invokes the prompt function and repairs the editor's cursor origin after the inline picker has potentially scrolled the terminal.

The managed profile's prompt wrapper also calls `bwload` and `zoxide add` before invoking Cailoxo. Cailoxo then performs synchronous Git status, ahead/behind, stash, and metadata queries.

Recommendations for a PowerShell trial:

- For the current two-line Cailoxo prompt, pre-setting `ATUIN_POWERSHELL_PROMPT_OFFSET` to `-1` can avoid the first-search line-count evaluation. Keep the value tied to the active prompt layout; it does not remove the redraw cost on later searches.
- For repeated searches, retain `InvokePrompt` and its cursor-position repair, but investigate serving a cached prompt result specifically during Atuin's redraw. Refresh the cache during normal prompt generation and account for Cailoxo's transient prompt and background-fetch behavior.
- Do not simply remove `InvokePrompt` or substitute buffer replacement: neither establishes the correct editor origin after inline scrolling.
- Validate on the actual PowerShell/PSReadLine version in WezTerm, including selection, cancellation, multiline input, resizing, and the first versus subsequent search.

References:

- Nushell REPL: <https://github.com/nushell/nushell/blob/0.115.1/crates/nu-cli/src/repl.rs>
- PSReadLine `InvokePrompt`: <https://learn.microsoft.com/en-us/powershell/module/psreadline/about/about_psreadline_functions#invokeprompt>

## Cailoxo source evaluation and recommended implementation order

Generator source is available at `~/repos/cailoxo`, cloned from `git@github.com:vufly/cailoxo.git`. The evaluated revision is `2315f52` on `main`.

Relevant files:

- `src/generate/nu.rs`: Nushell prompt, optional `gstat` backend, and fetch scheduling.
- `src/generate/pwsh.rs`: PowerShell prompt and Git queries.
- `cailoxo.toml`: Git span settings, including `nu_gstat = false`.
- `plans/FAST_GIT_STATUS.md`: existing proposals for Git status backends and a daemon.

### Plugin availability and measurements

`nu_plugin_gstat` is installed through mise at `~/.local/share/mise/installs/nu-gstat/latest/bin/nu_plugin_gstat`. The earlier isolated `nu -n` check did not load the plugin; absence of the `gstat` command there did not mean the plugin binary was missing.

With the installed plugin explicitly loaded using Nushell's `--plugins` option, three warm trials in xconfig produced:

| Operation | Three measurements |
| --- | --- |
| `gstat --no-tag` | 3.47, 5.43, 3.85 ms |
| Current `cailoxo-git-info` | 76.28, 69.49, 68.04 ms |

Background fetch was suppressed for these measurements. This compares raw plugin status collection with the current Git-info function, not complete prompt rendering or complete backend implementations. Cailoxo's `gstat` backend still performs additional metadata queries. Measure full Atuin return latency after regeneration before claiming an end-to-end improvement.

### 1. Enable the existing Nushell backend

- Set `nu_gstat = true` in the Cailoxo Git span settings.
- Ensure the `gstat` plugin is loaded before the generated Nushell prompt.
- Regenerate through Cailoxo, review the resulting script, and deploy through the existing shared Chezmoi template and platform wrappers.
- Compare full selection-to-editable-buffer latency with the current baseline in the same repositories.
- Verify branch, ahead/behind, stash, staged, modified, untracked, conflict, rename, and deletion indicators, including detached HEAD and non-repository directories.

### 2. Fix Nushell fetch-throttle persistence in Cailoxo

`cailoxo-start-fetch` assigns `CAILOXO_FETCH_LAST_KEY` and `CAILOXO_FETCH_LAST_START_NS` inside a plain Nushell `def`. A scope probe confirmed that environment changes made by a plain `def` do not survive its return. The current implementation therefore does not persist its throttle updates through that function.

- Move scheduling and throttle state into a persistent hook scope, or another mechanism whose state survives prompt evaluation.
- Do not assume that changing only the inner function to `def --env` solves the issue: the calling functions and prompt closure also affect environment propagation.
- Verify repeated redraws within the configured interval do not start repeated fetches, and verify fetching resumes when due and behaves correctly after switching repositories.
- Keep this fix in generator source and regenerate managed outputs.

### 3. Evaluate PowerShell on the actual Windows shell

- First trial an explicit `ATUIN_POWERSHELL_PROMPT_OFFSET = -1` for the current two-line prompt, preserving any intentional user override.
- Measure first and subsequent Atuin returns separately.
- If repeated returns remain slow, investigate Git-data caching in Cailoxo while retaining PSReadLine's `InvokePrompt` cursor repair.
- Preserve refresh after commands, directory changes, background fetch completion, and resize, as well as transient prompts and exit-status display.

Keep the accepted Zsh redraw override. Defer a new daemon or broad prompt caching until the existing Nushell backend and fetch fix have been measured. These steps are planned, not implemented.
