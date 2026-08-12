{
  description = "iinacord";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
  let
    systems = [
      "aarch64-darwin"
      "x86_64-darwin"
    ];

    forAllSystems = f:
      nixpkgs.lib.genAttrs systems (system:
        f (import nixpkgs { inherit system; }));
  in {
    formatter = forAllSystems (pkgs:
      (import ./nix/formatter.nix {
        inherit pkgs;
      }).formatter
    );

    devShells = forAllSystems (pkgs: {
      default = pkgs.mkShell {
        packages = with pkgs; [
          swift
          swift-format
          fd
        ];
      };
    });
  };
}