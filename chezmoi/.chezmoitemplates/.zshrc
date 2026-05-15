# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

if [[ -f "/opt/homebrew/bin/brew" ]] then
  # If you're using macOS, you'll want this enabled
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Set the directory we want to store zinit and plugins
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"

# Download Zinit, if it's not there yet
if [ ! -d "$ZINIT_HOME" ]; then
   mkdir -p "$(dirname $ZINIT_HOME)"
   git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi

# Source/Load zinit
source "${ZINIT_HOME}/zinit.zsh"

# Add in Powerlevel10k
zinit ice depth=1; zinit light romkatv/powerlevel10k

# . ~/.asdf/asdf.sh  # Load asdf in the current shell

# Add in zsh plugins
# zinit light zdharma-continuum/fast-syntax-highlighting
zinit light zsh-users/zsh-syntax-highlighting
zinit light zsh-users/zsh-completions
zinit light zsh-users/zsh-autosuggestions
zinit light Aloxaf/fzf-tab

# Add in snippets
zinit snippet OMZP::git
zinit snippet OMZP::sudo
zinit snippet OMZP::command-not-found

# Bitwarden CLI completion (generate only on install/update)
zinit ice \
    atclone'mkdir -p ~/.zsh/completions; bw completion --shell zsh > ~/.zsh/completions/_bw' \
    atpull'%atclone' \
    nocompile \
    id-as'bitwarden-completion'
zinit load zdharma-continuum/null
fpath=("$HOME/.zsh/completions" $fpath)
# Load completions
autoload -Uz compinit && compinit

zinit cdreplay -q

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Keybindings
bindkey -e
bindkey '^p' history-search-backward
bindkey '^n' history-search-forward
bindkey '^[w' kill-region

# History
HISTSIZE=5000
HISTFILE=~/.zsh_history
SAVEHIST=$HISTSIZE
HISTDUP=erase
setopt appendhistory
setopt sharehistory
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_ignore_dups
setopt hist_find_no_dups

# Completion styling
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza --icons=auto --color=always $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'eza --icons=auto --color=always $realpath'

# Aliases
alias ls='eza'
alias lsi='eza --icons=auto'
alias vim='nvim'
alias c='clear'
#alias tmux="env TERM=screen-256color tmux"
alias t="tmux"
alias ta="t a -t"
alias tls="t ls"
alias tn="t new -t"
alias tk="t kill-session -t"
alias tka='tmux list-sessions -F "#{session_name}" | grep -v "^$" | xargs -I {} tmux kill-session -t {}'
alias trs="tmux source-file ~/.tmux.conf"

alias z="zellij"
alias za="zellij attach --force-run-commands"
alias zls="zellij list-sessions"
alias zn="zellij -s"
alias zk="zellij kill-session"
alias zka="zellij kill-all-sessions"

alias 256="curl -s https://gist.githubusercontent.com/HaleTom/89ffe32783f89f403bba96bd7bcd1263/raw/ | bash"

alias gitzip="git archive HEAD -o ${PWD##*/}.zip"
alias gitsf="git submodule update --init --recursive"
alias gitsp="git submodule foreach --recursive 'git pull origin master'"
alias theme="$HOME/scripts/set-theme.sh"
alias hm="nix run home-manager/master -- switch --flake ~/xconfig#${USER}@$(hostname)"

ilias() {
  local selected alias_name

  if ! (( $+commands[fzf] )); then
    zle -M "fzf not found"
    return 1
  fi

  [[ -n ${WIDGET:-} ]] && zle -I
  selected="$(alias | sort | fzf --height=40% --prompt='alias> ')" || return
  alias_name="${selected%%=*}"

  if [[ -n ${WIDGET:-} ]]; then
    LBUFFER+="${alias_name} "
    zle reset-prompt
  else
    print -z "${alias_name} "
  fi
}
zle -N ilias

BW_SESSION_FILE="${XDG_RUNTIME_DIR:-$HOME/.cache}/bw-session"

bwu() {
  local session
  session="$(bw unlock --raw)" || return
  mkdir -p "${BW_SESSION_FILE%/*}"
  umask 077
  printf '%s' "$session" > "$BW_SESSION_FILE"
  export BW_SESSION="$session"
  tmux set-environment -g BW_SESSION "$session" 2>/dev/null || true
}

bwload() {
  [[ -r "$BW_SESSION_FILE" ]] && export BW_SESSION="$(<"$BW_SESSION_FILE")"
}

precmd_functions+=(bwload)

export WINUSER=$(pushd /mnt/c > /dev/null && cmd.exe /q /c "echo %USERNAME%" | rev | cut -c 2- | rev )
alias fork='load_fork() { /mnt/c/Users/$WINUSER/AppData/Local/Fork/current/Fork.exe $(wslpath -w $@) };load_fork'

gac() {
  if [ -z "$1" ]; then
    echo "Usage: gac <commit message>"
    return 1
  fi
  git add --all
  git commit -m "$(git branch --show-current) $1"
}

gact() {
  # Get the current branch name
  branch_name=$(git branch --show-current)

  # Create a temporary file with the branch name prefilled
  temp_file=$(mktemp)
  echo "$branch_name: " > "$temp_file"

  # Open the editor to edit the commit message
  ${EDITOR:-vim} "$temp_file"

  # Stage all changes and commit using the message from the file
  git add --all
  git commit -F "$temp_file"

  # Clean up the temporary file
  rm "$temp_file"
}

export GPG_TTY=$TTY
export PATH="$HOME/.local/bin:$PATH"
#export PATH="$HOME/.nix-profile/bin:$PATH"
# export ANDROID_HOME=~/Android/Sdk
# export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/tools:$ANDROID_HOME/platform-tools

# pnpm
export PNPM_HOME="/home/${USER}/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME/bin:"*) ;;
  *) export PATH="$PNPM_HOME/bin:$PATH" ;;
esac
# pnpm end

{{- if lookPath "bw" }}
# Claude code
export ANTHROPIC_BASE_URL={{ (bitwardenFields "item" "cliproxy").baseUrl.value }}
export ANTHROPIC_AUTH_TOKEN={{ (bitwardenFields "item" "cliproxy").apiKey.value }}
{{- end }}
export ANTHROPIC_DEFAULT_OPUS_MODEL='gpt-5.5(high)'
export ANTHROPIC_DEFAULT_SONNET_MODEL='gpt-5.4(high)'
export ANTHROPIC_DEFAULT_HAIKU_MODEL='gpt-5.4-mini(medium)'


# Shell integrations
eval "$(mise activate zsh)"
if (( $+commands[vivid] )); then
  export LS_COLORS="$(vivid generate ansi)"
fi
eval "$(fzf --zsh)"
eval "$(zoxide init --cmd cd zsh)"
