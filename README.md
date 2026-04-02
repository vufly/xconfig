# xconfig

Personal configuration repo for a mixed Windows and WSL/Linux setup.

This repository uses two layers:

- `home-manager` manages packages and shell-level configuration for Linux and WSL through Nix flakes.
- `chezmoi` manages cross-platform dotfiles, templates, and machine-local files, with a bootstrap path for Windows.

## Repository Layout

- `flake.nix`: Nix flake entrypoint and Home Manager outputs.
- `home/`: shared, platform-specific, and host-specific Home Manager modules.
- `chezmoi/`: dotfiles and templates applied through `chezmoi`.
- `init-chezmoi.ps1`: Windows bootstrap script for configuring `chezmoi`.
- `others/`: editor highlight/theme snippets and extra config fragments.

## What Lives Where

Use `home-manager` for:

- packages installed through Nix
- shell environment and session path
- host-specific Linux or WSL configuration

Use `chezmoi` for:

- dotfiles that should be materialized into `$HOME`
- templated config files such as `.wezterm.lua`, `.zshrc`, and `.wslconfig`
- files that vary by machine, OS, or secret state

If a setting belongs in declarative package management, keep it in `home/`. If it is a rendered file in the home directory, keep it in `chezmoi/`.

## Current Hosts

The flake currently specifies one Home Manager target:

- `vudinhn@ohp360-wsl`

That host uses:

- `home/default.nix`
- `home/linux.nix`
- `home/hosts/ohp360-wsl.nix`

## Prerequisites

### Linux / WSL

- `nix`
- `home-manager`

### Windows

- PowerShell
- Chocolatey
- `chezmoi` (the bootstrap script will install it through Chocolatey if missing)

## Setup

### Home Manager on Linux / WSL

Clone the repo and apply the configured Home Manager profile:

```bash
nix run .#hm -- switch --flake .#username@hostname
```

If you already have `home-manager` installed separately, this also works:

```bash
home-manager switch --flake .#username@hostname
```

## Chezmoi on Windows

From PowerShell, run:

```powershell
.\init-chezmoi.ps1
```

The script currently:

- requires Chocolatey to already be installed
- installs `chezmoi` if it is missing
- writes `~/.config/chezmoi/chezmoi.yaml`
- sets `sourceDir` to `~/xconfig/chezmoi`
- runs `chezmoi apply`

This means the repo is expected to live at `~/xconfig` on Windows. If you clone it elsewhere, update `init-chezmoi.ps1` or `chezmoi.yaml` before applying.

## Day-to-Day Commands

### Rebuild Home Manager

```bash
nix run .#hm -- switch --flake .#username@hostname
```

### Re-apply Chezmoi Dotfiles

```powershell
chezmoi apply
```

### Preview Chezmoi Changes

```powershell
chezmoi diff
```

## Notes

- `home/linux.nix` currently sets the Linux user to `vudinhn` with home directory `/home/vudinhn`.
- `home/default.nix` is currently empty and acts as a shared module placeholder.
- `others/` contains supplemental editor highlight files and is not automatically applied by the flake or bootstrap script.

## Future Improvements

- Add additional host entries under `home/hosts/` for new machines.
- Make `init-chezmoi.ps1` derive the repo path dynamically instead of assuming `~/xconfig`.
- Document any secrets workflow if `private_*` chezmoi files become part of the expected setup.
