{
  description = "Kani (bounded model checking of Rust) built from its release tag, with its pinned nightly, CBMC and Kissat";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, rust-overlay, ... }:
  let
    systems = [ "x86_64-linux" "aarch64-linux" ];
    forAllSystems = f: nixpkgs.lib.genAttrs systems (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ rust-overlay.overlays.default ];
        };
      in f { inherit pkgs system; }
    );
  in {
    packages = forAllSystems ({ pkgs, ... }:
      let
        release = import ./release.nix;
        # The nightly Kani's rust-toolchain.toml pins: kani-compiler links rustc's own crates (rustc-dev), and its
        # sysroots are built from the standard library's source (rust-src).
        toolchain = pkgs.rust-bin.nightly.${release.nightly}.minimal.override {
          extensions = [ "rustc-dev" "llvm-tools" "rust-src" "rustfmt" ];
        };
        kissat = pkgs.callPackage ./pkgs/kissat.nix { inherit release; };
        cbmc =
          assert pkgs.cbmc.version == release.cbmc;
          pkgs.cbmc;
        kani = pkgs.callPackage ./pkgs/kani.nix { inherit release toolchain kissat cbmc; };
      in {
        inherit toolchain kissat cbmc kani;
        default = kani;
      });

    checks = forAllSystems ({ pkgs, system }:
      pkgs.callPackage ./tests { kani = self.packages.${system}.kani; });

    formatter = forAllSystems ({ pkgs, ... }: pkgs.alejandra);
  };
}
