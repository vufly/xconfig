{ config, pkgs, ... }:

{
  home.username = "dinhvu";
  home.homeDirectory = "/Users/dinhvu";

  # macOS-specific packages
  home.packages = with pkgs; [
    htop
  ];
}
