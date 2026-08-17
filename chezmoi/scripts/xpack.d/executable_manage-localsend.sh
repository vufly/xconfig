#!/bin/sh

set -eu

action=${1:-}
app_id=org.localsend.localsend_app
flathub_url=https://flathub.org/repo/flathub.flatpakrepo

run_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    printf 'sudo is required to manage LocalSend.\n' >&2
    return 1
  fi
}

check_installed() {
  if ! command -v flatpak >/dev/null 2>&1; then
    return 10
  fi
  if ! inventory=$(flatpak list --system --app --columns=application 2>/dev/null); then
    printf 'Could not query system Flatpak applications.\n' >&2
    return 1
  fi
  if printf '%s\n' "$inventory" | grep -F -x -q "$app_id"; then
    return 0
  fi
  return 10
}

ensure_flatpak() {
  if command -v flatpak >/dev/null 2>&1; then
    return 0
  fi
  if command -v apt-get >/dev/null 2>&1; then
    run_root apt-get update
    run_root apt-get install -y flatpak
  elif command -v dnf >/dev/null 2>&1; then
    run_root dnf install -y flatpak
  else
    printf 'LocalSend installation requires apt-get or dnf.\n' >&2
    return 1
  fi
}

case "$action" in
  check)
    if check_installed; then
      exit 0
    else
      exit $?
    fi
    ;;
  install)
    ensure_flatpak
    run_root flatpak remote-add --system --if-not-exists flathub "$flathub_url"
    run_root flatpak install --system -y flathub "$app_id"
    ;;
  upgrade)
    if ! command -v flatpak >/dev/null 2>&1; then
      printf 'Flatpak is required to upgrade LocalSend.\n' >&2
      exit 1
    fi
    run_root flatpak update --system -y "$app_id"
    ;;
  uninstall)
    if ! command -v flatpak >/dev/null 2>&1; then
      exit 0
    fi
    if check_installed; then
      run_root flatpak uninstall --system -y "$app_id"
    else
      result=$?
      [ "$result" -eq 10 ] && exit 0
      exit "$result"
    fi
    ;;
  *)
    printf 'Usage: %s check|install|upgrade|uninstall\n' "$0" >&2
    exit 2
    ;;
esac
