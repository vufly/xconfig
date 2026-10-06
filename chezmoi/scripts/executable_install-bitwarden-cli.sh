#!/bin/sh

set -eu

case "$(uname -s)" in
  Linux) platform=linux ;;
  Darwin) platform=macos ;;
  *)
    printf 'Unsupported operating system. This installer supports Linux and macOS.\n' >&2
    exit 1
    ;;
esac

case "$(uname -m)" in
  x86_64|amd64) ;;
  *)
    printf 'Bitwarden native CLI downloads require x64. For ARM, use npm install -g @bitwarden/cli.\n' >&2
    exit 1
    ;;
esac

for command in curl unzip; do
  if ! command -v "$command" >/dev/null 2>&1; then
    printf 'Required command missing: %s\n' "$command" >&2
    exit 1
  fi
done

install_dir="$HOME/bin"
mkdir -p "$install_dir"
temp_dir=$(mktemp -d "$install_dir/.bw-install.XXXXXX")
trap 'rm -rf "$temp_dir"' EXIT
trap 'exit 1' HUP INT TERM

printf 'Downloading latest Bitwarden CLI for %s...\n' "$platform"
curl --fail --location --show-error --retry 3 \
  --output "$temp_dir/bw.zip" \
  "https://bitwarden.com/download/?app=cli&platform=$platform"
unzip -p "$temp_dir/bw.zip" bw > "$temp_dir/bw"
chmod 755 "$temp_dir/bw"
version=$("$temp_dir/bw" --version)
mv -f "$temp_dir/bw" "$install_dir/bw"

printf 'Installed Bitwarden CLI %s to %s/bw\n' "$version" "$install_dir"
case ":$PATH:" in
  *":$install_dir:"*) ;;
  *) printf 'Add to your shell profile: export PATH="$HOME/bin:$PATH"\n' ;;
esac
