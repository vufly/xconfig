{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # Package manager for language runtimes and developer tools
    mise

    # Base tools still managed by Home Manager
    chezmoi
    curl
    git
    gnupg
    openssh
    wget
    unzip
  ];

  # Managed directly via chezmoi and local config files.
  programs.git.enable = false;
  programs.zsh.enable = false;
  programs.neovim.enable = false;

  home.stateVersion = "25.11";
}
