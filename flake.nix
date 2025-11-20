{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";

    flake-utils.url = "github:numtide/flake-utils";

    winapps = {
      url = "github:winapps-org/winapps";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      winapps,
    }:
    {
      homeManagerModules = {
        winapps =
          {
            config,
            lib,
            pkgs,
            ...
          }:
          import ./modules/winapps.nix {
            inherit
              config
              lib
              pkgs
              winapps
              ;
          };
        default = self.homeManagerModules.winapps;
      };
    }
    // flake-utils.lib.eachDefaultSystem (
      system:
      let
        winappsPkgs = winapps.packages.${system};
      in
      {
        packages = winappsPkgs // {
          default = winappsPkgs.winapps;
        };
      }
    );
}
