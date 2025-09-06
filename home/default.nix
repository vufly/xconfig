{ config, pkgs, ... }:

{
  # Set your username and home directory
  home.username = "vudinhn";
  home.homeDirectory = "/home/vudinhn";
  # Install some core packages to get you started
  home.packages = with pkgs; [
    home-manager
    git
    zsh
    tmux
    neovim
    wget
    curl
    fzf
  ];

  # Set your shell to zsh (or bash, fish, etc.)
  programs.zsh.enable = true;

  programs.git = {
    enable = true;
    userName = "Nguyen Dinh Vu";
    userEmail = "nguyendinhvu@msn.com";
  };

  # This is the version of Home Manager you are targeting.
  # This helps manage breaking changes.
  home.stateVersion = "22.11";
}