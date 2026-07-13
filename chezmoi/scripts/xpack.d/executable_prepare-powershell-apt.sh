#!/bin/sh

set -eu

if [ ! -r /etc/os-release ]; then
  printf 'Cannot identify Linux distribution.\n' >&2
  exit 1
fi

. /etc/os-release

case "$ID" in
  ubuntu|debian) distribution=$ID ;;
  *)
    printf 'PowerShell apt repository is unsupported on %s.\n' "$ID" >&2
    exit 1
    ;;
esac

package_url="https://packages.microsoft.com/config/$distribution/$VERSION_ID/packages-microsoft-prod.deb"
temp_dir=$(mktemp -d)
trap 'rm -rf "$temp_dir"' EXIT HUP INT TERM

curl -fsSL "$package_url" -o "$temp_dir/packages-microsoft-prod.deb"

if [ "$(id -u)" -eq 0 ]; then
  dpkg -i "$temp_dir/packages-microsoft-prod.deb"
else
  sudo dpkg -i "$temp_dir/packages-microsoft-prod.deb"
fi
