{ config, pkgs, ... }:

{
  # Set your username and home directory
  home.username = "vudinhn";
  home.homeDirectory = "/home/vudinhn";
  # Install some core packages to get you started
  home.packages = with pkgs; [
    git
    zsh
    tmux
    neovim
    wget
    curl
    git-credential-manager
  ];

  # Set your shell to zsh (or bash, fish, etc.)
  programs.zsh.enable = true;

  programs.git = {
    enable = true;
    userName = "Nguyen Dinh Vu";
    userEmail = "nguyendinhvu@msn.com";
    # Tell Git to use the credential manager
    extraConfig = {
      credential = {
        # This tells the Git Credential Manager to use a cache.
        credentialStore = "cache";
        helper = "${pkgs.git-credential-manager}/bin/git-credential-manager";
      };
    };
  };

  # This is the version of Home Manager you are targeting.
  # This helps manage breaking changes.
  home.stateVersion = "22.11";
}