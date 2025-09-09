{ config, pkgs, ... }:

{
  home.username = "vu";
  home.homeDirectory = "/Users/vu";

  # macOS-specific packages
  home.packages = with pkgs; [
    htop
  ];
}