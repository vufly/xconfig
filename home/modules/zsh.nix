{ config, pkgs, ... }:

{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    syntaxHighlighting.enable = true;
    # autosuggestions.enable = true;

    history = {
      size = 5000;
      save = 5000;
      ignoreDups = true;
      share = true;
      path = "${config.xdg.dataHome}/zsh/history";
    };

    shellAliases = {
      ls   = "ls --color";
      vim  = "nvim";
      c    = "clear";
      t    = "tmux";
      ta   = "t a -t";
      tls  = "t ls";
      tn   = "t new -t";
      tk   = "t kill-session -t";
      tka  = "tmux list-sessions -F \"#{session_name}\" | grep -v \"^$\" | xargs -I {} tmux kill-session -t {}";
      trs  = "tmux source-file ~/.tmux.conf";
      "256" = "curl -s https://gist.githubusercontent.com/HaleTom/89ffe32783f89f403bba96bd7bcd1263/raw/ | bash";
      # gitzip = "git archive HEAD -o ${PWD##*/}.zip";
      gitsf  = "git submodule update --init --recursive";
      gitsp  = "git submodule foreach --recursive 'git pull origin master'";
    };

    plugins = [
      { name = "zsh-syntax-highlighting"; src = pkgs.zsh-syntax-highlighting; }
      { name = "zsh-autosuggestions"; src = pkgs.zsh-autosuggestions; }
      { name = "zsh-completions"; src = pkgs.zsh-completions; }
      { name = "fzf-tab"; src = pkgs.zsh-fzf-tab; }
    ];

    initExtraFirst  = ''
  # Powerlevel10k instant prompt
  if [[ -r ''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh ]]; then
    source ''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh
  fi
  [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
'';


    initExtra = ''
      # Keybindings
      bindkey -e
      bindkey '^p' history-search-backward
      bindkey '^n' history-search-forward
      bindkey '^[w' kill-region

      # GPG
      export GPG_TTY=$TTY

      # Android
      export ANDROID_HOME=$HOME/Android/Sdk
      export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/tools:$ANDROID_HOME/platform-tools

      # pnpm
      export PNPM_HOME="$HOME/.local/share/pnpm"
      case ":$PATH:" in
        *":$PNPM_HOME:"*) ;;
        *) export PATH="$PNPM_HOME:$PATH" ;;
      esac

      # fzf + zoxide
      eval "$(fzf --zsh)"
      eval "$(zoxide init --cmd cd zsh)"

      # Functions
      gac() {
        if [ -z "$1" ]; then
          echo "Usage: gac <commit message>"
          return 1
        fi
        git add --all
        git commit -m "$(git branch --show-current): $1"
      }

      gact() {
        branch_name=$(git branch --show-current)
        temp_file=$(mktemp)
        echo "$branch_name: " > "$temp_file"
        ${EDITOR:-vim} "$temp_file"
        git add --all
        git commit -F "$temp_file"
        rm "$temp_file"
      }
    '';
  };

  home.packages = with pkgs; [
    zsh-powerlevel10k
    fzf
    zoxide
  ];
}
