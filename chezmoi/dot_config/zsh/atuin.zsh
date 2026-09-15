# Avoid Atuin's explicit prompt re-expansion after selection.
# ZLE still refreshes its invalidated display; this removes one extra Git scan.
# Match exactly one standalone call; leave unfamiliar upstream versions intact.
() {
  emulate -L zsh
  (( $+functions[_atuin_search] )) || return 0

  local original=$'\tzle reset-prompt\n'
  local replacement=$'\tzle .redisplay\n'
  local body=$functions[_atuin_search]$'\n'
  [[ $body == *"$original"* ]] || return 0

  local remaining=${body/"$original"/}
  [[ $remaining != *"$original"* ]] || return 0
  body=${body/"$original"/"$replacement"}
  functions[_atuin_search]=${body%$'\n'}
}
