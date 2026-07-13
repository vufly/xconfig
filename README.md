# xconfig

Declarative configuration for Windows, Linux, WSL, and macOS.

This repository uses three layers:

- `chezmoi` renders cross-platform dotfiles and machine-specific configuration.
- `mise` installs runtimes and portable developer tools.
- `xpack` reconciles native packages through `apt`, `dnf`, Homebrew, Chocolatey, and Winget.

## Repository Layout

- `chezmoi/`: Chezmoi source directory.
- `chezmoi/.chezmoidata/package-catalog.yaml`: backend-specific package exceptions.
- `chezmoi/.chezmoitemplates/packages.yaml`: package-list composition template.
- `chezmoi/.chezmoitemplates/packages/`: reusable common and platform package lists.
- `chezmoi/scripts/executable_xpack.*.tmpl`: generated package reconcilers.
- `chezmoi/scripts/xpack.d/`: package-specific preparation and lifecycle scripts.
- `init-chezmoi.ps1`: Windows bootstrap.
- `init-chezmoi.sh`: Linux and macOS bootstrap.

## Bootstrap

Clone this repository before running a bootstrap script.

### Windows

Run from an elevated PowerShell session:

```powershell
.\init-chezmoi.ps1
```

The default machine ID is `$env:COMPUTERNAME`. Override it when needed:

```powershell
.\init-chezmoi.ps1 -Machine OHP360
```

The script bootstraps Chocolatey when needed, installs Chezmoi and Mise through Chocolatey, runs `mise self-update`, adds `%USERPROFILE%\AppData\Local\mise\shims` to the user `Path`, writes the Chezmoi config, and applies dotfiles. Chocolatey is the default Windows package backend; Winget remains available for explicit package declarations.

### Linux And macOS

```sh
sh ./init-chezmoi.sh ohp360-wsl
```

The argument is the stable machine ID. Without an argument, hostname is used.

The machine ID is available as `.machine` in Chezmoi templates for optional machine-specific conditions.

On Linux, the script supports `apt-get` and `dnf`, then installs Chezmoi and Mise into `~/.local/bin`. On macOS, it bootstraps Homebrew when needed and installs both tools through Homebrew.

Bootstrap does not install declared native packages. Review them first:

```text
~/scripts/xpack.sh status
~/scripts/xpack.sh sync
```

On Windows, use `& "$HOME/scripts/xpack.ps1" status` in the bootstrap shell. New shell sessions expose the `xpack` function.

## Package Declarations

Native packages are split into flat YAML lists under `chezmoi/.chezmoitemplates/packages/`:

```yaml
# packages/common.yaml
- chezmoi
- git
- mise: { updates: self }
```

`packages.yaml` composes these groups:

- `common.yaml`: baseline CLI packages for every platform.
- `posix-cli.yaml`: shared Linux and macOS CLI packages.
- `common-gui.yaml`: GUI applications for desktop platforms.
- `windows-gui.yaml`, `linux-gui.yaml`, `macos-gui.yaml`: platform GUI additions.
- `windows-cli.yaml`, `linux-cli.yaml`, `macos-cli.yaml`: platform CLI additions.

Linux under WSL receives `common.yaml` and `linux-cli.yaml`; all GUI groups are omitted.

A string entry uses platform defaults:

```yaml
- git
```

An override entry is a single-key map:

```yaml
- firefox: { backend: winget, updates: manual }
```

Default backends are Chocolatey on Windows, Homebrew on macOS, and `apt` or `dnf` on Linux based on the available manager. An explicit `backend` overrides the platform default.

Use normal Chezmoi conditions in `packages.yaml` or package-list templates for platform or machine differences. Package names must be unique in the rendered list.

Update policies:

- `manager`: `xpack upgrade` invokes selected backend.
- `self`: application updates itself; package-manager upgrades are skipped.
- `manual`: upgrades are intentionally skipped.

## Package Catalog

Logical package name is backend package ID by default. The catalog records known backend mappings and lifecycle metadata; a missing backend mapping falls back to the logical name:

```yaml
packageCatalog:
  git:
    winget: Git.Git

  powershell:
    chocolatey: powershell-core

  firefox:
    winget: Mozilla.Firefox
    brew: { id: firefox, kind: cask }
```

Resolution examples:

```text
git + apt      -> apt package git
git + chocolatey -> Chocolatey package git
git + winget   -> Winget package Git.Git
firefox + brew -> Homebrew cask firefox
```

Advanced backend entries can prepare third-party repositories:

```yaml
packageCatalog:
  vscode:
    apt:
      id: code
      prepare: xpack.d/prepare-vscode-apt.sh
```

Preparation scripts must be idempotent. They run before install and upgrade. Generic backend logic still detects, installs, upgrades, and removes the package.

Chocolatey catalog entries with `kind: prerelease` add `--pre` during install and upgrade.

For a fully custom package lifecycle, select the `script` backend:

```yaml
packageCatalog:
  special-app:
    script:
      path: xpack.d/manage-special-app.sh
```

Custom lifecycle scripts receive one action:

```text
manage-special-app.sh check
manage-special-app.sh install
manage-special-app.sh upgrade
manage-special-app.sh uninstall
```

`check` exits `0` when installed and `10` when missing. Other exit codes indicate failure.

## Package Commands

```text
xpack status
xpack sync
xpack upgrade
xpack prune
xpack doctor
```

- `status`: reports present, missing, and invalid package entries.
- `sync`: installs missing packages without upgrading existing ones.
- `upgrade`: upgrades entries with `updates: manager`.
- `prune`: asks before uninstalling entries removed from the machine declaration.
- `doctor`: validates package managers and custom scripts.

Use `xpack prune --yes` only when non-interactive removal is intended.

Package ownership state is local:

- Unix: `${XDG_STATE_HOME:-~/.local/state}/xconfig/packages.psv`
- Windows: `%LOCALAPPDATA%\xconfig\packages.json`

Only packages successfully installed by `xpack` enter ownership state. Pre-existing packages are reported and left unmanaged. Removed and backend-changed owned entries remain in state until explicit pruning, so `prune` never considers unrelated packages installed outside this repository.

## Mise

Mise configuration lives in `chezmoi/.chezmoitemplates/mise-config.toml`. Chezmoi renders it to the platform-specific Mise config and upgrades tools when that declaration changes.

Use Mise for runtimes and portable CLI tools. Use `xpack` for system dependencies, native applications, and GUI packages.

## Day-To-Day Workflow

```text
chezmoi diff
chezmoi apply
xpack status
xpack sync
xpack upgrade
```

Package operations remain explicit because `apt`, `dnf`, Chocolatey, and some application installers may require elevation.
