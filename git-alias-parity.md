# Git Alias Parity

Keep Nushell git aliases aligned with oh-my-zsh git plugin aliases where practical.

## Source Files

- OMZ source: `/home/vudinhn/.local/share/zinit/snippets/OMZP::git/OMZP::git`
- Nushell source: `chezmoi/dot_config/nushell/autoload/git-aliases.nu`

## Compare Workflow

1. Source OMZ in clean zsh and list effective aliases:

```bash
zsh -f -c 'autoload -Uz compinit; compinit -D; source /home/vudinhn/.local/share/zinit/snippets/OMZP::git/OMZP::git >/dev/null 2>&1; alias -L'
```

2. Parse Nushell aliases and exported defs from `git-aliases.nu`.

3. Compare by alias/def name first, then by behavior.

4. Treat these differences as intentional unless asked otherwise:

- Nushell syntax uses command substitution like `(git_main_branch)` instead of zsh `$(git_main_branch)`.
- Nushell functions replace zsh aliases when arguments need quoting or optional behavior.
- Keep existing Nu-only convenience aliases unless they conflict with OMZ names.

## Update Priorities

1. Fix shared-name behavioral conflicts first, especially destructive or high-use commands.
2. Add missing high-use OMZ aliases/functions next.
3. Leave low-value GUI aliases, deprecated aliases, and zsh-specific plumbing out unless needed.
4. Prefer small direct defs over generic helpers.
5. After code changes, validate Nushell parsing and run `graphify update .`.

## Known High-Value Aliases

- Pull/push wrappers: `ggl`, `ggp`, `ggu`, `gpsup`, `gpsupf`
- Branch defaults: `git_main_branch`, `git_develop_branch`, `gcm`, `gcd`, `grbm`, `grbd`, `gswm`, `gswd`
- Recovery flow: `gmc`, `greva`, `grevc`, `grf`
- Fetch/push safety: `gfa`, `gpf`
- Stash/log compatibility: `gsts`, `gwch`, `gl`

## Validation

Run:

```bash
nu --commands 'source /home/vudinhn/xconfig/chezmoi/dot_config/nushell/autoload/git-aliases.nu'
graphify update .
```

If `nu` is unavailable, verify with the next interactive Nushell startup before applying with chezmoi.
