#!/bin/sh

set -eu

run_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}

temp_repo=$(mktemp)
trap 'rm -f "$temp_repo"' EXIT HUP INT TERM

cat >"$temp_repo" <<'EOF'
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF

run_root install -D -m 0644 "$temp_repo" /etc/yum.repos.d/vscode.repo
