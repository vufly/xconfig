#!/bin/sh

set -eu

run_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    printf 'sudo is required to configure the Tailscale repository.\n' >&2
    return 1
  fi
}

if [ ! -r /etc/os-release ]; then
  printf 'Cannot identify Linux distribution.\n' >&2
  exit 1
fi
if ! command -v curl >/dev/null 2>&1; then
  printf 'Required command not found: curl\n' >&2
  exit 1
fi

. /etc/os-release

case "${ID:-}" in
  ubuntu|pop|neon|tuxedo|elementary|zorin)
    repository_os=ubuntu
    repository_version=${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}
    ;;
  linuxmint)
    if [ -n "${UBUNTU_CODENAME:-}" ]; then
      repository_os=ubuntu
      repository_version=$UBUNTU_CODENAME
    elif [ -n "${DEBIAN_CODENAME:-}" ]; then
      repository_os=debian
      repository_version=$DEBIAN_CODENAME
    else
      printf 'Cannot identify Linux Mint base distribution.\n' >&2
      exit 1
    fi
    ;;
  debian|raspbian)
    repository_os=$ID
    repository_version=${VERSION_CODENAME:-}
    ;;
  *)
    printf 'Tailscale APT repository is unsupported on %s.\n' "${ID:-unknown}" >&2
    exit 1
    ;;
esac

if [ -z "$repository_version" ]; then
  printf 'Cannot identify distribution codename for Tailscale repository.\n' >&2
  exit 1
fi

repository_base="https://pkgs.tailscale.com/stable/$repository_os/$repository_version"
temp_dir=$(mktemp -d)
trap 'rm -rf "$temp_dir"' EXIT HUP INT TERM

if ! curl -fsSL "$repository_base.noarmor.gpg" -o "$temp_dir/tailscale.gpg"; then
  printf 'Tailscale does not provide keyring metadata for %s %s.\n' "$repository_os" "$repository_version" >&2
  exit 1
fi
curl -fsSL "$repository_base.tailscale-keyring.list" -o "$temp_dir/tailscale.list"

run_root install -d -m 0755 /usr/share/keyrings /etc/apt/sources.list.d
run_root install -m 0644 "$temp_dir/tailscale.gpg" /usr/share/keyrings/tailscale-archive-keyring.gpg
run_root install -m 0644 "$temp_dir/tailscale.list" /etc/apt/sources.list.d/tailscale.list
