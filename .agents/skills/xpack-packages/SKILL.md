---
name: xpack-packages
description: Add or update native packages managed by xpack, including package declarations, backend catalog mappings, Winget scope, update policy, repository preparation scripts, and custom package lifecycle scripts. Use when requests mention xpack packages, package-catalog.yaml, Winget, Chocolatey, APT, DNF, Homebrew, or files under chezmoi/.chezmoitemplates/packages and chezmoi/scripts/xpack.d.
---

# Xpack Packages

Use this skill for native system packages managed by xpack. Do not use it for runtimes or portable developer tools that belong in Mise.

Make requested package changes end to end. Preserve unrelated worktree changes. Do not install, upgrade, or remove real packages unless the user explicitly requests that operation.

## Source Files

- `chezmoi/.chezmoitemplates/packages.yaml` composes package groups by platform and WSL status.
- `chezmoi/.chezmoitemplates/packages/*.yaml` declares logical package names.
- `chezmoi/.chezmoidata/package-catalog.yaml` maps logical names to backend-specific package metadata.
- `chezmoi/.chezmoitemplates/xpack-records` validates declarations and produces records consumed by xpack.
- `chezmoi/scripts/executable_xpack.ps1.tmpl` implements Windows reconciliation.
- `chezmoi/scripts/executable_xpack.sh.tmpl` implements Linux and macOS reconciliation.
- `chezmoi/scripts/xpack.d/` contains package-specific preparation and lifecycle scripts.

Do not edit generated user files under `~/scripts`. Change Chezmoi source files instead.

## Choose Package Group

Place each logical package in the narrowest group matching requested platforms:

| Group | Platforms |
| --- | --- |
| `common.yaml` | Windows, Linux, WSL, macOS CLI baseline |
| `posix-cli.yaml` | Linux, WSL, and macOS CLI |
| `common-gui.yaml` | Windows, Linux desktop, and macOS; excluded from WSL |
| `windows-cli.yaml` | Windows CLI only |
| `windows-gui.yaml` | Windows GUI only |
| `linux-cli.yaml` | Linux and WSL CLI only |
| `linux-gui.yaml` | Linux desktop GUI only |
| `macos-cli.yaml` | macOS CLI only |
| `macos-gui.yaml` | macOS GUI only |

A logical package name may appear only once in any rendered platform list. Check composed groups before adding it. Do not place a package in a shared group unless every included platform has a valid package path.

## Add Or Update Package

1. Identify logical lowercase package name, requested platforms, CLI or GUI role, backend package IDs, update policy, and any required installation scope.
2. Search existing declarations, catalog entries, and `xpack.d` scripts before editing. Update existing definitions instead of adding parallel definitions.
3. Verify backend package IDs from authoritative package-manager metadata or vendor installation documentation. Do not guess IDs. Report any ID that could not be verified.
4. Add or update declaration in the narrowest package group.
5. Add catalog mappings only where logical name is not correct backend ID or backend needs metadata.
6. Add an idempotent preparation script or full lifecycle script only when generic backend handling is insufficient.
7. Validate affected platform rendering and script syntax without changing installed packages.

## Declaration Syntax

A plain string uses platform default backend and `updates: manager`:

```yaml
- git
```

An option entry is a single-key map:

```yaml
- mise: { updates: self }
- firefox: { backend: winget, updates: manual }
- nushell: { backend: winget, scope: machine }
```

Supported declaration options:

- `backend`: `apt`, `dnf`, `brew`, `chocolatey`, `winget`, or `script`.
- `updates`: `manager`, `self`, or `manual`.
- `scope`: `user` or `machine`; valid only when resolved driver is Winget.

Default backends:

- Windows: Chocolatey.
- macOS: Homebrew.
- Linux: APT when `apt-get` exists, otherwise DNF.

Prefer platform defaults. Use declaration-level `backend` only when that package intentionally differs from platform default.

## Catalog Mappings

Logical package name is backend package ID when no mapping exists. Keep catalog entries alphabetized by logical name and preserve existing formatting style.

Simple mapping:

```yaml
packageCatalog:
  git:
    winget: Git.Git
```

Mapping with metadata:

```yaml
packageCatalog:
  firefox:
    brew: { id: firefox, kind: cask }

  vscode:
    apt:
      id: code
      prepare: xpack.d/prepare-vscode-apt.sh
```

Supported backend metadata:

- `id`: backend package identifier.
- `kind`: backend-specific variant, such as Homebrew `cask` or Chocolatey `prerelease`.
- `scope`: Winget `user` or `machine` default.
- `prepare`: script run before generic install and upgrade.
- `driver`: resolved implementation driver, normally `script` for custom lifecycles.
- `path`: custom lifecycle script path.

For a custom lifecycle selected from an APT or DNF declaration, attach script driver metadata to those backend keys:

```yaml
packageCatalog:
  special-app:
    apt: { driver: script, path: xpack.d/manage-special-app.sh }
    dnf: { driver: script, path: xpack.d/manage-special-app.sh }
```

## Preparation Scripts

Use preparation scripts when package manager can handle check, install, upgrade, and uninstall after repository or key setup.

File convention:

```text
chezmoi/scripts/xpack.d/executable_prepare-<package>-<backend>.sh
```

Catalog paths omit Chezmoi's `executable_` attribute prefix:

```yaml
prepare: xpack.d/prepare-<package>-<backend>.sh
```

Preparation scripts must:

- Use POSIX `sh`, normally with `#!/bin/sh` and `set -eu`.
- Be idempotent because they run before every install and manager-driven upgrade.
- Support root execution and `sudo` with clear failure messages.
- Use temporary files and cleanup traps for downloaded keys or repository definitions.
- Avoid changing unrelated repositories or package configuration.

## Lifecycle Scripts

Use a custom lifecycle only when generic package-manager behavior cannot safely manage package installation.

File convention:

```text
chezmoi/scripts/xpack.d/executable_manage-<package>.sh
```

The script receives exactly one action:

```text
check
install
upgrade
uninstall
```

Contract:

- `check` exits `0` when installed.
- `check` exits `10` when missing.
- Other exit codes indicate failure.
- `install`, `upgrade`, and `uninstall` exit `0` only after successful completion.
- Unsupported actions print usage to stderr and exit `2`.
- Repository setup must be idempotent and roll back newly created repository files when installation fails.
- Uninstall removes only repository files owned by that lifecycle when appropriate.
- Detection must query exact package ownership rather than rely only on executable presence.

One lifecycle may support both APT and DNF when manager detection and behavior are explicit.

## Updating Existing Packages

Trace package through declaration, catalog mappings, and scripts before changing it.

- Preserve platform mappings not included in request.
- Keep shared declarations valid for every platform receiving them.
- Changing backend ID, driver, kind, script path, or Winget scope changes xpack ownership identity. Old owned entry remains eligible for explicit pruning.
- Do not edit local ownership state to hide identity changes.
- Do not run `xpack prune` after mapping changes.
- Package versions are not pinned in declarations. Do not encode version updates unless xpack gains an explicit version feature.

## Verification

Render package composition and records for each affected platform:

```sh
chezmoi --source ./chezmoi execute-template \
  '{{ includeTemplate ".chezmoitemplates/packages.yaml" . }}'

chezmoi --source ./chezmoi execute-template \
  '{{ includeTemplate ".chezmoitemplates/xpack-records" . }}'
```

Use `--override-data` platform fixtures when validating non-host platforms. Include Windows, Linux desktop, WSL, or macOS according to changed groups. Confirm:

- package appears exactly once on intended platforms;
- package is absent from unintended platforms;
- logical name resolves to expected backend, driver, ID, kind, update policy, prepare path, script path, and scope;
- WSL excludes GUI declarations.

For changed shell scripts, run POSIX syntax checks:

```sh
sh -n chezmoi/scripts/xpack.d/executable_manage-<package>.sh
sh -n chezmoi/scripts/xpack.d/executable_prepare-<package>-<backend>.sh
```

Render and parse affected generated xpack script when declaration schema or backend behavior changes. For lifecycle scripts, exercise all actions with mocked package-manager commands and temporary paths; do not touch real repositories or installed packages.

Never run these commands without explicit user approval:

```text
xpack sync
xpack upgrade
xpack prune
```

Finish with concise list of changed declarations, mappings, scripts, verification performed, and any platform IDs or real-system behavior not verified.
