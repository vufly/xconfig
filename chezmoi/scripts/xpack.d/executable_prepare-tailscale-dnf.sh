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
version_major=${VERSION_ID:-}
version_major=${version_major%%.*}

case "${ID:-}" in
  fedora|rocky|almalinux|nobara|openmandriva|sangoma|risios|cloudlinux|alinux|fedora-asahi-remix|ultramarine)
    repository_path=fedora
    ;;
  centos)
    repository_path="centos/$version_major"
    ;;
  rhel|miraclelinux)
    repository_path="rhel/$version_major"
    ;;
  ol)
    repository_path="oracle/$version_major"
    ;;
  *)
    printf 'Tailscale DNF repository is unsupported on %s.\n' "${ID:-unknown}" >&2
    exit 1
    ;;
esac

case "$repository_path" in
  */)
    printf 'Cannot identify distribution version for Tailscale repository.\n' >&2
    exit 1
    ;;
esac

temp_repo=$(mktemp)
trap 'rm -f "$temp_repo"' EXIT HUP INT TERM
curl -fsSL "https://pkgs.tailscale.com/stable/$repository_path/tailscale.repo" -o "$temp_repo"

run_root install -d -m 0755 /etc/yum.repos.d
run_root install -m 0644 "$temp_repo" /etc/yum.repos.d/tailscale.repo
