{
  description = "TUI code review helper";

  inputs = {
    nixops.url = "github:nhost/nhost";
    nixpkgs.follows = "nixops/nixpkgs";
    flake-utils.follows = "nixops/flake-utils";
    nix-filter.follows = "nixops/nix-filter";
    nix2container.follows = "nixops/nix2container";
  };

  outputs = { self, nixops, nixpkgs, flake-utils, nix-filter, nix2container }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [ nixops.overlays.default ];
        pkgs = import nixpkgs {
          inherit system overlays;
        };

        src = nix-filter.lib.filter {
          root = ./.;
          include = with nix-filter.lib;[
            (nix-filter.lib.matchExt "go")
            ./go.mod
            ./go.sum
            ./.golangci.yaml
            isDirectory
            (inDirectory "vendor")
          ];
        };

        nix-src = nix-filter.lib.filter {
          root = ./.;
          include = [
            (nix-filter.lib.matchExt "nix")
          ];
        };

        checkDeps = with pkgs; [
          mockgen
          git
        ];

        nativeBuildInputs = with pkgs; [
          go
        ];

        buildInputs = [ ];

        nix2containerPkgs = nix2container.packages.${system};
        nixops-lib = nixops.lib { inherit pkgs nix2containerPkgs; };

        name = "lazyreview";
        description = "TUI code review helper";
        version = "0.0.0-dev";
        submodule = ".";

        tags = [ ];

        ldflags = [
          "-X main.Version=${version}"
        ];

      in
      {
        checks = {
          nixpkgs-fmt = nixops-lib.nix.check { src = nix-src; };

          lazyreview = nixops-lib.go.check {
            inherit src submodule ldflags tags buildInputs nativeBuildInputs checkDeps;
          };
        };

        devShells = flake-utils.lib.flattenTree {
          default = nixops-lib.go.devShell {
            buildInputs = [
            ] ++ checkDeps ++ buildInputs ++ nativeBuildInputs;
          };

          cliff = pkgs.mkShell {
            buildInputs = with pkgs; [
              git-cliff
            ];
          };
        };

        packages = flake-utils.lib.flattenTree rec {
          lazyreview = nixops-lib.go.package {
            inherit name submodule description src version ldflags buildInputs nativeBuildInputs;
          };

          default = lazyreview;
        };
      }
    );
}
