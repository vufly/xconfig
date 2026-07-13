#!/bin/sh

set -eu

run_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}

temp_key=$(mktemp)
trap 'rm -f "$temp_key"' EXIT HUP INT TERM

curl -fsSL https://packages.microsoft.com/keys/microsoft.asc -o "$temp_key"
run_root install -D -m 0644 "$temp_key" /usr/share/keyrings/microsoft.asc
printf '%s\n' 'deb [arch=amd64,arm64,armhf signed-by=/usr/share/keyrings/microsoft.asc] https://packages.microsoft.com/repos/code stable main' |
  run_root tee /etc/apt/sources.list.d/vscode.list >/dev/null
