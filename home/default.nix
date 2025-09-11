{ config, pkgs, lib, ... }:

{
  home.packages = with pkgs; [
    # zsh
    git
    tmux
    neovim
    wget
    curl
    fzf
    zoxide
    eza
    gnupg
    openssh
    chezmoi
    nodejs_22
    pnpm
  ];

  programs.git.enable = false;
  programs.zsh.enable = false;
  programs.neovim.enable = false;

  # Chezmoi integration
  # programs.chezmoi = {
  #   enable = true;
  #   initFlags = [ "--source" "${config.home.homeDirectory}/.local/share/chezmoi" ];
  # };

  home.stateVersion = "22.11";
}
