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

          lazyreview-arm64-darwin = (nixops-lib.go.package {
            inherit name submodule description src version ldflags buildInputs nativeBuildInputs;
          }).overrideAttrs (old: old // {
            env = {
              GOOS = "darwin";
              GOARCH = "arm64";
              CGO_ENABLED = "0";
            };
          });

          lazyreview-amd64-darwin = (nixops-lib.go.package {
            inherit name submodule description src version ldflags buildInputs nativeBuildInputs;
          }).overrideAttrs (old: old // {
            env = {
              GOOS = "darwin";
              GOARCH = "amd64";
              CGO_ENABLED = "0";
            };
          });

          lazyreview-arm64-linux = (nixops-lib.go.package {
            inherit name submodule description src version ldflags buildInputs nativeBuildInputs;
          }).overrideAttrs (old: old // {
            env = {
              GOOS = "linux";
              GOARCH = "arm64";
              CGO_ENABLED = "0";
            };
          });

          lazyreview-amd64-linux = (nixops-lib.go.package {
            inherit name submodule description src version ldflags buildInputs nativeBuildInputs;
          }).overrideAttrs (old: old // {
            env = {
              GOOS = "linux";
              GOARCH = "amd64";
              CGO_ENABLED = "0";
            };
          });

          lazyreview-multiplatform = pkgs.runCommand "cli-multiplatform-${version}"
            {
              meta = {
                description = "Multi-platform ${description} binaries";
              };
            } ''
            mkdir -p $out/{darwin,linux}/{arm64,amd64}

            cp ${lazyreview-arm64-darwin}/bin/${name} $out/darwin/arm64/${name}
            cp ${lazyreview-amd64-darwin}/bin/${name} $out/darwin/amd64/${name}
            cp ${lazyreview-arm64-linux}/bin/${name} $out/linux/arm64/${name}
            cp ${lazyreview-amd64-linux}/bin/${name} $out/linux/amd64/${name}
          '';

          default = lazyreview;
        };
      }
    );
}
