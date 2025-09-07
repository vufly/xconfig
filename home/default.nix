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

  home.stateVersion = "22.11";
}
