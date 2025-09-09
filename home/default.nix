{ config, pkgs, lib, ... }:

{
  home.packages = with pkgs; [
    git
    zsh
    tmux
    neovim
    wget
    curl
    fzf
    zoxide
    chezmoi
  ];

  programs.git = {
    enable = true;
    userName = "Nguyen Dinh Vu";
    userEmail = "nguyendinhvu@msn.com";
  };

  programs.zsh = {
    enable = true;
  };

  # programs.neovim = {
  #   enable = true;
  # };

  # Chezmoi integration
  # programs.chezmoi = {
  #   enable = true;
  #   initFlags = [ "--source" "${config.home.homeDirectory}/.local/share/chezmoi" ];
  # };

  home.stateVersion = "22.11";
}
