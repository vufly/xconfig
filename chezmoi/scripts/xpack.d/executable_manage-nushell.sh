#!/bin/sh

set -eu

action=${1:-}
apt_key=/etc/apt/keyrings/xconfig-nushell.gpg
apt_source=/etc/apt/sources.list.d/xconfig-nushell.list
dnf_source=/etc/yum.repos.d/xconfig-nushell.repo
temp_key=
temp_keyring=
temp_repo=
apt_key_created=0
apt_source_created=0
dnf_source_created=0
rollback_repository=0

run_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    printf 'sudo is required to manage Nushell.\n' >&2
    return 1
  fi
}

remove_created_repository() {
  if [ "$apt_source_created" -eq 1 ]; then
    run_root rm -f "$apt_source" >/dev/null 2>&1 || true
    apt_source_created=0
  fi
  if [ "$apt_key_created" -eq 1 ]; then
    run_root rm -f "$apt_key" >/dev/null 2>&1 || true
    apt_key_created=0
  fi
  if [ "$dnf_source_created" -eq 1 ]; then
    run_root rm -f "$dnf_source" >/dev/null 2>&1 || true
    dnf_source_created=0
  fi
}

cleanup() {
  [ -z "$temp_key" ] || rm -f "$temp_key" || true
  [ -z "$temp_keyring" ] || rm -f "$temp_keyring" || true
  [ -z "$temp_repo" ] || rm -f "$temp_repo" || true
  [ "$rollback_repository" -eq 0 ] || remove_created_repository
}

trap cleanup EXIT HUP INT TERM

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'Required command not found: %s\n' "$1" >&2
    return 1
  fi
}

setup_apt_repository() {
  require_command curl
  require_command gpg
  [ -e "$apt_key" ] || apt_key_created=1
  [ -e "$apt_source" ] || apt_source_created=1
  temp_key=$(mktemp)
  temp_keyring=$(mktemp)
  temp_repo=$(mktemp)
  curl -fsSL https://apt.fury.io/nushell/gpg.key -o "$temp_key"
  gpg --batch --yes --dearmor --output "$temp_keyring" "$temp_key"
  run_root install -d -m 0755 /etc/apt/keyrings
  run_root install -m 0644 "$temp_keyring" "$apt_key"
  printf '%s\n' 'deb [signed-by=/etc/apt/keyrings/xconfig-nushell.gpg] https://apt.fury.io/nushell/ /' >"$temp_repo"
  run_root install -m 0644 "$temp_repo" "$apt_source"
}

setup_dnf_repository() {
  [ -e "$dnf_source" ] || dnf_source_created=1
  temp_repo=$(mktemp)
  cat >"$temp_repo" <<'EOF'
[xconfig-nushell]
name=Gemfury Nushell Repo
baseurl=https://yum.fury.io/nushell/
enabled=1
gpgcheck=0
gpgkey=https://yum.fury.io/nushell/gpg.key
EOF
  run_root install -m 0644 "$temp_repo" "$dnf_source"
}

if command -v apt-get >/dev/null 2>&1; then
  manager=apt
elif command -v dnf >/dev/null 2>&1; then
  manager=dnf
else
  printf 'Nushell installation requires apt-get or dnf.\n' >&2
  exit 2
fi

case "$manager:$action" in
  apt:check)
    require_command dpkg-query || exit 2
    if ! package_inventory=$(dpkg-query -W -f='${binary:Package}|${Status}\n' 2>/dev/null); then
      printf 'Could not query installed APT packages.\n' >&2
      exit 1
    fi
    if printf '%s\n' "$package_inventory" | grep -F -x -q 'nushell|install ok installed'; then
      exit 0
    fi
    exit 10
    ;;
  apt:install)
    rollback_repository=1
    setup_apt_repository
    run_root apt-get update
    run_root apt-get install -y nushell
    rollback_repository=0
    ;;
  apt:upgrade)
    rollback_repository=1
    setup_apt_repository
    run_root apt-get update
    run_root apt-get install --only-upgrade -y nushell
    rollback_repository=0
    remove_created_repository
    ;;
  apt:uninstall)
    run_root apt-get remove -y nushell
    run_root rm -f "$apt_source" "$apt_key"
    ;;
  dnf:check)
    require_command rpm || exit 2
    if ! package_inventory=$(rpm -qa --qf '%{NAME}\n' 2>/dev/null); then
      printf 'Could not query installed RPM packages.\n' >&2
      exit 1
    fi
    if printf '%s\n' "$package_inventory" | grep -F -x -q nushell; then
      exit 0
    fi
    exit 10
    ;;
  dnf:install)
    rollback_repository=1
    setup_dnf_repository
    run_root dnf install -y nushell
    rollback_repository=0
    ;;
  dnf:upgrade)
    rollback_repository=1
    setup_dnf_repository
    run_root dnf upgrade -y nushell
    rollback_repository=0
    remove_created_repository
    ;;
  dnf:uninstall)
    run_root dnf remove -y nushell
    run_root rm -f "$dnf_source"
    ;;
  *)
    printf 'Usage: %s check|install|upgrade|uninstall\n' "$0" >&2
    exit 2
    ;;
esac
