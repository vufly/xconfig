{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, home-manager }:
    let
      # Supported systems
      supportedSystems = [ "x86_64-linux" "aarch64-darwin" "x86_64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in {
      homeConfigurations = {
        "vudinhn@OHP360" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages."x86_64-linux";
          modules = [
            ./home/default.nix
            ./home/linux.nix
            ./home/hosts/OHP360.nix
          ];
        };

        # Example: If you add a MacBook later
        # "vu@MacBook" = home-manager.lib.homeManagerConfiguration {
        #   pkgs = nixpkgs.legacyPackages."aarch64-darwin";
        #   modules = [
        #     ./home/default.nix
        #     ./home/darwin.nix
        #     ./home/hosts/MacBook.nix
        #   ];
        # };
      };
    };
}