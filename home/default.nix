{ config, pkgs, ... }:

{
  # Install some core packages to get you started
  home.packages = with pkgs; [
    git
    zsh
    tmux
    neovim
    wget
    curl
    # Add more packages here
  ];

  # This is the version of Home Manager you are targeting.
  # This helps manage breaking changes.
  home.stateVersion = "22.11";
}