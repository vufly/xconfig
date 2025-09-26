{ config, pkgs, lib, ... }:

{
  home.packages = with pkgs; [
    mise           # Fron-end to your dev environment
    # -------------------------------
    # Shell & Core Environment Tools
    # -------------------------------
    zoxide          # smarter cd command
    fzf             # fuzzy finder
    eza             # modern replacement for ls
    bat             # cat with syntax highlighting
    fd              # fast alternative to find
    ripgrep         # fast grep alternative
    scooter         # find-and-replace TUI
    yazi            # terminal file manager

    # -------------------------------
    # Shell & Networking Utilities
    # -------------------------------
    wget            # HTTP(S) download
    curl            # URL transfers
    gnupg           # encryption & signing
    openssh         # ssh client & tools
    bitwarden-cli   # password manager CLI

    # -------------------------------
    # Editors & Terminal Tools
    # -------------------------------
    neovim          # text editor
    tmux            # terminal multiplexer

    # -------------------------------
    # Source Control
    # -------------------------------
    git             # version control
    tig             # text-mode interface for git
    lazygit         # terminal UI for git
    delta           # git diff viewer

    # -------------------------------
    # Dotfiles & Config Management
    # -------------------------------
    chezmoi         # dotfiles manager
  ];

  # Disable program modules you manage manually (via chezmoi or configs)
  programs.git.enable = false;
  programs.zsh.enable = false;
  programs.neovim.enable = false;

  # Example: Chezmoi integration (if you want to enable later)
  # programs.chezmoi = {
  #   enable = true;
  #   initFlags = [ "--source" "${config.home.homeDirectory}/.local/share/chezmoi" ];
  # };

  home.stateVersion = "22.11";
}
