#!/bin/sh

set -eu

case "$(uname -s)" in
  CYGWIN*|MINGW*|MSYS*)
    exit 0
    ;;
esac

source_dir="$HOME/.agents/skills"
target_link="$HOME/.gemini/config/skills"

mkdir -p "$source_dir"
mkdir -p "$(dirname "$target_link")"

if [ -L "$target_link" ]; then
  current_target=$(readlink "$target_link" 2>/dev/null || true)
  if [ "$current_target" = "$source_dir" ]; then
    printf 'Skills symlink is already up to date: %s -> %s\n' "$target_link" "$source_dir"
    exit 0
  fi
  rm "$target_link"
elif [ -d "$target_link" ]; then
  backup_dir="${target_link}.bak.$(date +%s)"
  printf 'Existing directory %s found; moving to %s\n' "$target_link" "$backup_dir"
  mv "$target_link" "$backup_dir"
fi

ln -sfn "$source_dir" "$target_link"
printf 'Linked: %s -> %s\n' "$target_link" "$source_dir"
