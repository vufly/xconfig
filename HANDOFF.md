# xconfig Session Handoff

## Goal

Replace Nix/Home Manager with declarative native package management across Windows, Linux/WSL, and macOS while keeping Chezmoi for configuration and Mise for portable tools.

## Current Architecture

- Chezmoi renders dotfiles and package scripts.
- Mise manages runtimes and portable developer tools.
- `xpack` reconciles native packages through Chocolatey, Winget, `apt`, `dnf`, Homebrew, or custom scripts.
- Package operations are explicit: `status`, `sync`, `upgrade`, `prune`, and `doctor`.
- Package ownership state remains independent from command naming:
  - Windows: `%LOCALAPPDATA%\xconfig\packages.json`
  - Unix: `${XDG_STATE_HOME:-$HOME/.local/state}/xconfig/packages.psv`
- `prune` only removes packages previously installed and recorded by `xpack`.

## Package Declarations

Main composition template:

- `chezmoi/.chezmoitemplates/packages.yaml`

Reusable package groups:

- `chezmoi/.chezmoitemplates/packages/common.yaml`
- `chezmoi/.chezmoitemplates/packages/common-gui.yaml`
- `chezmoi/.chezmoitemplates/packages/windows-cli.yaml`
- `chezmoi/.chezmoitemplates/packages/windows-gui.yaml`
- `chezmoi/.chezmoitemplates/packages/linux-cli.yaml`
- `chezmoi/.chezmoitemplates/packages/linux-gui.yaml`
- `chezmoi/.chezmoitemplates/packages/macos-cli.yaml`
- `chezmoi/.chezmoitemplates/packages/macos-gui.yaml`

Rendered entries use a flat YAML list:

```yaml
- git
- mise: { updates: self }
- firefox: { backend: winget, updates: manual }
```

Platform backend defaults:

- Windows: Chocolatey
- macOS: Homebrew
- Linux: `apt` when `apt-get` exists, otherwise `dnf`

WSL detection checks `.chezmoi.kernel.osrelease` for `microsoft`. WSL receives common CLI and Linux CLI groups, but no GUI groups.

Current groups:

```text
common:
  chezmoi, curl, git, mise (self-update), powershell, wget

common GUI:
  firefox, firefox-dev, gimp, inkscape, kicad, openscad,
  postman, spotify, thunderbird, vlc, vscode, wezterm, zed

Windows CLI:
  7zip, gsudo

Windows GUI:
  powertoys, sharex, sumatrapdf, windhawk

Linux CLI:
  gcc, gnupg, openssh, unzip

Linux GUI:
  TBD

macOS CLI/GUI:
  TBD
```

## Package Catalog

Catalog location:

- `chezmoi/.chezmoidata/package-catalog.yaml`

Catalog includes Chocolatey and Winget mappings for requested Windows applications, Linux package-name exceptions, Homebrew cask mappings for shared GUI applications, and repository preparation scripts for PowerShell and VS Code.

Important aliases:

- `firefox-dev` -> Chocolatey `firefox-dev --pre`
- `powershell` -> Chocolatey `powershell-core` (`pwsh`)
- `gcc` -> Chocolatey `mingw`
- `zed` -> Chocolatey `zed-editor`
- `sumatrapdf` -> Chocolatey `sumatrapdf`

Chocolatey entries with `kind: prerelease` receive `--pre` during install and upgrade.

## xpack Files

- `chezmoi/.chezmoitemplates/xpack-records`
- `chezmoi/scripts/executable_xpack.ps1.tmpl`
- `chezmoi/scripts/executable_xpack.sh.tmpl`
- `chezmoi/scripts/xpack.d/`

Shell integrations expose `xpack` in PowerShell, Nushell, and Zsh.

The previous `xpackages` name was fully renamed. `chezmoi/.chezmoiremove` removes old generated `xpackages` scripts during the next apply. Remaining `xpackages` text is intentionally limited to those migration removal paths.

## Windows Bootstrap

`init-chezmoi.ps1` now:

1. Requires an elevated PowerShell session and exits with warning otherwise.
2. Bootstraps Chocolatey from the official installer when missing.
3. Installs Chezmoi and Mise through Chocolatey.
4. Runs `mise self-update --yes`.
5. Adds `%USERPROFILE%\AppData\Local\mise\shims` to the user `Path` idempotently.
6. Writes Chezmoi configuration with stable `.machine` data.
7. Applies Chezmoi configuration.

Windows package synchronization is not automatic.

## Linux/macOS Bootstrap

`init-chezmoi.sh` supports:

- Linux with `apt-get` or `dnf`
- macOS with Homebrew bootstrap
- Chezmoi and Mise installation
- Stable machine ID written to Chezmoi data
- Chezmoi apply without automatic `xpack sync`

## Removed Nix Configuration

These files are deleted in the working tree:

- `flake.nix`
- `flake.lock`
- all files under `home/`

`codex-acp` moved to Mise through `github:zed-industries/codex-acp`.

## Verification Completed

- `chezmoi verify` passes.
- `git diff --check` passes; Git emits expected CRLF warnings on Windows.
- Generated PowerShell `xpack.ps1` parses and runs `doctor` and `status`.
- Generated POSIX `xpack.sh` passes `sh -n`.
- Windows, Linux desktop, WSL, and macOS package composition templates were simulated successfully.
- WSL composition excludes GUI packages.
- Chocolatey package IDs were checked against the Chocolatey repository.
- Winget package IDs were checked against the Winget repository.
- Firefox Developer Edition prerelease arguments were tested in memory without installing it.
- Chezmoi migration dry-run confirms `scripts/xpack.ps1` is added and old `scripts/xpackages.ps1` is removed.

No `xpack sync`, package upgrade, package prune, or real Linux package operation was run.

## Linux Risks To Resolve Next

1. Test real Linux rendering and execution. Previous Windows host has WSL enabled but no installed WSL distribution, so Linux runtime testing was deferred.
2. `chezmoi` and `mise` are installed by Linux bootstrap as binaries under `~/.local/bin`. Default `apt`/`dnf` package detection may report them missing because they are not package-manager-owned. They likely need script-backed catalog entries or removal from native `xpack` declarations.
3. Several common GUI applications are not available from default Linux repositories, including Firefox Developer Edition, Postman, Spotify, Zed, and possibly WezTerm. Decide whether to add repository scripts, custom lifecycle scripts, Flatpak support, or move them out of the shared Linux GUI set.
4. Validate Linux package names and preparation scripts on both Debian/Ubuntu and Fedora-family hosts.
5. Validate Homebrew cask mappings on an actual Mac later.

## Continue On Linux

Start with non-mutating checks:

```sh
git status --short
sh -n ./init-chezmoi.sh
chezmoi --source "$PWD/chezmoi" execute-template \
  '{{ includeTemplate ".chezmoitemplates/packages.yaml" . }}'
chezmoi --source "$PWD/chezmoi" execute-template \
  '{{ includeTemplate ".chezmoitemplates/xpack-records" . }}'
chezmoi verify
```

Then bootstrap or apply:

```sh
sh ./init-chezmoi.sh "$(hostname)"
```

Inspect without installing packages:

```sh
~/scripts/xpack.sh doctor
~/scripts/xpack.sh status
```

Only after reviewing missing packages:

```sh
~/scripts/xpack.sh sync
```

New Zsh sessions expose:

```sh
xpack doctor
xpack status
```

## Working Tree

- Changes are uncommitted.
- Many new package-management files are untracked because the entire migration was built in the current working tree.
- Do not restore deleted Nix/Home Manager files.
- Do not rename `xpack` back to `xpackages`; old-name references in `.chezmoiremove` are migration cleanup only.
