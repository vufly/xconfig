#!/bin/sh

set -eu

machine=${1:-$(hostname)}
repo_root=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
source_dir=$repo_root/chezmoi

case "$machine" in
  *[!A-Za-z0-9._-]*)
    printf 'Machine ID may contain only letters, numbers, dot, underscore, and hyphen.\n' >&2
    exit 1
    ;;
esac

run_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}

case "$(uname -s)" in
  Darwin)
    if ! command -v brew >/dev/null 2>&1; then
      brew_installer=$(mktemp)
      trap 'rm -f "$brew_installer"' EXIT HUP INT TERM
      curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o "$brew_installer"
      NONINTERACTIVE=1 /bin/bash "$brew_installer"
      rm -f "$brew_installer"
      trap - EXIT HUP INT TERM
      if [ -x /opt/homebrew/bin/brew ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
      elif [ -x /usr/local/bin/brew ]; then
        eval "$(/usr/local/bin/brew shellenv)"
      fi
    fi
    brew install chezmoi mise
    ;;
  Linux)
    if command -v apt-get >/dev/null 2>&1; then
      run_root apt-get update
      run_root apt-get install -y ca-certificates curl git
    elif command -v dnf >/dev/null 2>&1; then
      run_root dnf install -y ca-certificates curl git
    else
      printf 'Supported Linux package manager not found; expected apt-get or dnf.\n' >&2
      exit 1
    fi

    mkdir -p "$HOME/.local/bin"
    if ! command -v chezmoi >/dev/null 2>&1; then
      chezmoi_installer=$(mktemp)
      trap 'rm -f "$chezmoi_installer"' EXIT HUP INT TERM
      curl -fsSL https://get.chezmoi.io -o "$chezmoi_installer"
      sh "$chezmoi_installer" -b "$HOME/.local/bin"
      rm -f "$chezmoi_installer"
      trap - EXIT HUP INT TERM
    fi
    if ! command -v mise >/dev/null 2>&1; then
      mise_installer=$(mktemp)
      trap 'rm -f "$mise_installer"' EXIT HUP INT TERM
      curl -fsSL https://mise.run -o "$mise_installer"
      sh "$mise_installer"
      rm -f "$mise_installer"
      trap - EXIT HUP INT TERM
    fi
    export PATH="$HOME/.local/bin:$PATH"
    ;;
  *)
    printf 'Unsupported operating system: %s\n' "$(uname -s)" >&2
    exit 1
    ;;
esac

if ! command -v chezmoi >/dev/null 2>&1; then
  printf 'chezmoi installation succeeded but executable is not in PATH.\n' >&2
  exit 1
fi
if ! command -v mise >/dev/null 2>&1; then
  printf 'mise installation succeeded but executable is not in PATH.\n' >&2
  exit 1
fi

override_data=$(printf '{"machine":"%s"}' "$machine")
if ! chezmoi --source "$source_dir" execute-template --override-data "$override_data" '{{ includeTemplate ".chezmoitemplates/xpack-records" . }}' >/dev/null; then
  printf "Package declaration failed to render for machine '%s'.\n" "$machine" >&2
  exit 1
fi

config_dir=$HOME/.config/chezmoi
config_file=$config_dir/chezmoi.yaml
mkdir -p "$config_dir"

yaml_source=$(printf '%s' "$source_dir" | sed "s/'/''/g")
yaml_machine=$(printf '%s' "$machine" | sed "s/'/''/g")
cat >"$config_file" <<EOF
sourceDir: '$yaml_source'
data:
  machine: '$yaml_machine'
EOF

printf 'Applying chezmoi configuration for machine %s...\n' "$machine"
chezmoi apply
printf "Configuration applied. Run '%s/scripts/xpack.sh status', then '%s/scripts/xpack.sh sync'.\n" "$HOME" "$HOME"
