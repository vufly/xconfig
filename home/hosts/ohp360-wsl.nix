{ config, pkgs, ... }:

{
  home.username = "vudinhn";
  home.homeDirectory = "/home/vudinhn";

  home.sessionPath = [
    "$HOME/.local/bin"
  ];

  home.packages = with pkgs; [
    codex
  ];
}
