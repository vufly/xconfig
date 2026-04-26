#!/bin/sh

set -eu

case "$(uname -s)" in
  CYGWIN*|MINGW*|MSYS*)
    exit 0
    ;;
esac

if [ "$#" -ne 1 ]; then
  printf 'Usage: %s dark|light\n' "$0" >&2
  exit 1
fi

bat_config_file="${XDG_CONFIG_HOME:-$HOME/.config}/bat/config"
helix_config_file="${XDG_CONFIG_HOME:-$HOME/.config}/helix/config.toml"
git_config_file="$HOME/.gitconfig"
mkdir -p "$(dirname "$bat_config_file")"
mkdir -p "$(dirname "$helix_config_file")"

case "$1" in
  dark)
    bat_theme_name="bearded-theme-monokai-stone"
    delta_mode_key="dark"
    delta_theme_name="bearded-theme-monokai-stone"
    ;;
  light)
    bat_theme_name="bearded-theme-milkshake-vanilla"
    delta_mode_key="light"
    delta_theme_name="bearded-theme-milkshake-vanilla"
    ;;
  *)
    printf 'Usage: %s dark|light\n' "$0" >&2
    exit 1
    ;;
esac

temp_file="$(mktemp)"
trap 'rm -f "$temp_file"' EXIT

if [ -f "$bat_config_file" ]; then
  found_theme=0
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      --theme=*)
        printf '%s\n' "--theme=\"$bat_theme_name\"" >> "$temp_file"
        found_theme=1
        ;;
      *)
        printf '%s\n' "$line" >> "$temp_file"
        ;;
    esac
  done < "$bat_config_file"

  if [ "$found_theme" -eq 0 ]; then
    printf '%s\n' "--theme=\"$bat_theme_name\"" >> "$temp_file"
  fi
else
  printf '%s\n' "--theme=\"$bat_theme_name\"" > "$temp_file"
fi

mv "$temp_file" "$bat_config_file"

helix_temp_file="$(mktemp)"
trap 'rm -f "$temp_file" "$helix_temp_file"' EXIT

if [ -f "$helix_config_file" ]; then
  found_theme=0
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      theme\ =*)
        printf '%s\n' "theme = \"$bat_theme_name\"" >> "$helix_temp_file"
        found_theme=1
        ;;
      *)
        printf '%s\n' "$line" >> "$helix_temp_file"
        ;;
    esac
  done < "$helix_config_file"

  if [ "$found_theme" -eq 0 ]; then
    if [ -s "$helix_temp_file" ]; then
      printf '\n' >> "$helix_temp_file"
    fi
    printf '%s\n' '# --- THEME ---' >> "$helix_temp_file"
    printf '%s\n' '# This line is updated manually by ~/scripts/set-theme.sh.' >> "$helix_temp_file"
    printf '%s\n' "theme = \"$bat_theme_name\"" >> "$helix_temp_file"
  fi
else
  printf '%s\n' '# --- THEME ---' > "$helix_temp_file"
  printf '%s\n' '# This line is updated manually by ~/scripts/set-theme.sh.' >> "$helix_temp_file"
  printf '%s\n' "theme = \"$bat_theme_name\"" >> "$helix_temp_file"
fi

mv "$helix_temp_file" "$helix_config_file"

git_temp_file="$(mktemp)"
trap 'rm -f "$temp_file" "$helix_temp_file" "$git_temp_file"' EXIT

if [ -f "$git_config_file" ]; then
  in_delta=0
  found_delta=0
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      "[delta]")
        found_delta=1
        in_delta=1
        printf '%s\n' "$line" >> "$git_temp_file"
        printf '%s\n' '  # These values are updated manually by ~/scripts/set-theme.sh.' >> "$git_temp_file"
        printf '%s\n' "  $delta_mode_key = true" >> "$git_temp_file"
        printf '%s\n' "  syntax-theme = \"$delta_theme_name\"" >> "$git_temp_file"
        continue
        ;;
      \[*\])
        in_delta=0
        ;;
    esac

    if [ "$in_delta" -eq 1 ]; then
      trimmed_line=${line#"${line%%[![:space:]]*}"}
      case "$trimmed_line" in
        dark\ =*|dark=*|light\ =*|light=*|syntax-theme\ =*|syntax-theme=*|'# These values are updated manually by ~/scripts/set-theme.sh.')
          continue
          ;;
      esac
    fi

    printf '%s\n' "$line" >> "$git_temp_file"
  done < "$git_config_file"

  if [ "$found_delta" -eq 0 ]; then
    if [ -s "$git_temp_file" ]; then
      printf '\n' >> "$git_temp_file"
    fi
    printf '%s\n' '[delta]' >> "$git_temp_file"
    printf '%s\n' '  # These values are updated manually by ~/scripts/set-theme.sh.' >> "$git_temp_file"
    printf '%s\n' "  $delta_mode_key = true" >> "$git_temp_file"
    printf '%s\n' "  syntax-theme = \"$delta_theme_name\"" >> "$git_temp_file"
  fi
else
  printf '%s\n' '[delta]' > "$git_temp_file"
  printf '%s\n' '  # These values are updated manually by ~/scripts/set-theme.sh.' >> "$git_temp_file"
  printf '%s\n' "  $delta_mode_key = true" >> "$git_temp_file"
  printf '%s\n' "  syntax-theme = \"$delta_theme_name\"" >> "$git_temp_file"
fi

mv "$git_temp_file" "$git_config_file"
