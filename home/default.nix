{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    git
    zsh
    tmux
    neovim
    wget
    curl
    fzf
    chezmoi
  ];

  programs.git = {
    enable = true;
    userName = "Nguyen Dinh Vu";
    userEmail = "nguyendinhvu@msn.com";
  };

  programs.zsh = {
    enable = true;
    oh-my-zsh.enable = true;
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;
  };

  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
  };

  home.stateVersion = "22.11";
}
