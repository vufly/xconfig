{ config, pkgs, ... }:

{
  home.username = "vudinhn";
  home.homeDirectory = "/home/vudinhn";

  programs.zsh.shellAliases = {
    nup = "node ~/o24/da/ui-dev-scripts/ui-proxy/ui-proxy.js";
  };
}
