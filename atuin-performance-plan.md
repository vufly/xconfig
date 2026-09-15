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
