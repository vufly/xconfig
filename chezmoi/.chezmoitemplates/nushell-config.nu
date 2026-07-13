# config.nu
#
# Installed by:
# version = "0.112.2"
#
# This file is used to override default Nushell settings, define
# (or import) custom commands, or run any other startup tasks.
# See https://www.nushell.sh/book/configuration.html
#
# Nushell sets "sensible defaults" for most configuration settings,
# so your `config.nu` only needs to override these defaults if desired.
#
# You can open this file in your default editor using:
#     config nu
#
# You can also pretty-print and page through the documentation for configuration
# options using:
#     config nu --doc | nu-highlight | less -R
use std/config [light-theme dark-theme]

$env.config.hooks.display_output = { table --expand --icons }
$env.config.show_banner = false
$env.config.show_hints = true
$env.config.edit_mode = "emacs"
$env.config.history = {
  max_size: 100_000
  sync_on_enter: true
  file_format: sqlite
  isolation: false
  ignore_space_prefixed: true
}
$env.config.completions.case_sensitive = false
$env.config.completions.algorithm = "fuzzy"
$env.config.completions.sort = "smart"
$env.config.completions.use_ls_colors = true

if ((which carapace | length) > 0) {
  let carapace_path = (which carapace | get path.0)
  let carapace_completer = {|spans|
    run-external $carapace_path $spans.0 nushell ...$spans | from json
  }

  $env.config.completions.external = {
    enable: true
    max_results: 100
    completer: $carapace_completer
  }
}

{{- if lookPath "bw" }}
# Claude code
$env.ANTHROPIC_BASE_URL = "{{ if lookPath "bw" }}{{ (bitwardenFields "item" "cliproxy").baseUrl.value }}{{ end }}"
$env.ANTHROPIC_AUTH_TOKEN = "{{ if lookPath "bw" }}{{ (bitwardenFields "item" "cliproxy").apiKey.value }}{{ end }}"
{{- end }}
$env.ANTHROPIC_DEFAULT_OPUS_MODEL = "gpt-5.5(high)"
$env.ANTHROPIC_DEFAULT_SONNET_MODEL = "gpt-5.4(high)"
$env.ANTHROPIC_DEFAULT_HAIKU_MODEL = "gpt-5.4-mini(medium)"

{{- $isWindows := eq .chezmoi.os "windows" }}
{{- if $isWindows }}
let home_dir = ($env.USERPROFILE? | default $nu.default-config-dir)
let runtime_dir = ($env.TEMP? | default ($env.TMP? | default ($home_dir | path join ".cache")))
{{- else }}
let home_dir = ($env.HOME? | default $nu.default-config-dir)
let runtime_dir = ($env.XDG_RUNTIME_DIR? | default ($home_dir | path join ".cache"))
let user_name = ($env.USER? | default "")
{{- end }}

let ls_colors_path = ($home_dir | path join ".config/LS_COLORS")
if ($ls_colors_path | path exists) {
  $env.LS_COLORS = (open --raw $ls_colors_path | str trim)
}

# Aliases
alias vim = nvim
alias c = clear
alias lsi = eza --icons

alias t = tmux
alias ta = tmux a -t
alias tls = tmux ls
alias tn = tmux new -t
alias tk = tmux kill-session -t
def tka [] {
  tmux list-sessions -F "#{session_name}" | lines | where $it != "" | each { |session|
    tmux kill-session -t $session
  }
}
alias trs = tmux source-file ~/.tmux.conf

alias z = zellij
alias za = zellij attach --force-run-commands
alias zls = zellij list-sessions
alias zn = zellij -s
alias zk = zellij kill-session
alias zka = zellij kill-all-sessions

def gitzip [] {
  let name = (pwd | path basename)
  git archive HEAD -o $"($name).zip"
}

alias gitsf = git submodule update --init --recursive
alias gitsp = git submodule foreach --recursive "git pull origin master"

def gac [message?: string] {
  if $message == null {
    print "Usage: gac <commit message>"
    return
  }

  git add --all
  git commit -m $"(git branch --show-current) ($message)"
}

def gact [] {
  let branch_name = (git branch --show-current)
  let temp_file = (mktemp -t gact.XXX)

  try {
    $"($branch_name): " | save --force $temp_file
    run-external ($env.EDITOR? | default "vim") $temp_file
    git add --all
    git commit -F $temp_file
  }

  rm --force $temp_file
}

def --env --wrapped theme [...args: string] {
  let mode = if (($args | length) > 0) { $args.0 } else { "" }

{{- if $isWindows }}
  run-external "powershell" "-NoProfile" "-ExecutionPolicy" "Bypass" "-File" ($home_dir | path join "scripts/set-theme.ps1") ...$args
{{- else }}
  run-external ($home_dir | path join "scripts/set-theme.sh") ...$args
{{- end }}

  if ($env.LAST_EXIT_CODE? | default 0) != 0 { return }

  match $mode {
    "light" => { $env.config.color_config = (light-theme) }
    "dark" => { $env.config.color_config = (dark-theme) }
    _ => {}
  }

}

{{- if not $isWindows }}
def hm [] {
  nix run home-manager/master -- switch --flake $"($home_dir)/xconfig#($user_name)@(hostname)"
}
{{- end }}

def ilias [] {
  let picked = (
    help aliases
    | select name expansion
    | input list --fuzzy --display {|a| $"($a.name) -> ($a.expansion)" } "alias"
  )

  commandline edit --insert $"($picked.name) "
}

$env.BW_SESSION_FILE = ($runtime_dir | path join "bw-session")

def --env bwu [] {
  let session = (bw unlock --raw)
  if $env.LAST_EXIT_CODE != 0 { return }

  mkdir ($env.BW_SESSION_FILE | path dirname)
{{- if $isWindows }}
  $session | save --force --raw $env.BW_SESSION_FILE
{{- else }}
  sh -c 'umask 077; printf %s "$2" > "$1"' sh $env.BW_SESSION_FILE $session
{{- end }}
  $env.BW_SESSION = $session

  try { tmux set-environment -g BW_SESSION $session }
}

def --env bwload [] {
  if ($env.BW_SESSION_FILE | path exists) {
    $env.BW_SESSION = (open --raw $env.BW_SESSION_FILE)
  }
}

$env.config.hooks.pre_prompt = ($env.config.hooks.pre_prompt | append { || bwload })

use ($nu.default-config-dir | path join mise.nu)
# oh-my-posh init nu --config "~/.theme.omp.toml"
source ($nu.default-config-dir | path join prompt.nu)
source ~/.zoxide.nu
