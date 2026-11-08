# nix-kani

[Kani](https://github.com/model-checking/kani) (bounded model checking of Rust, by CBMC) built from its release tag with
Nix, with the nightly, CBMC and Kissat the release pins, so that a bounded check is run by the same checker everywhere.

## What it builds

| | |
|---|---|
| Kani | `0.68.0`, from its tag (`release.nix`) |
| Rust | `nightly-2026-08-21` with `rustc-dev` and `rust-src`, from its `rust-toolchain.toml` (by `oxalica/rust-overlay`) |
| CBMC | `6.11.0`, from its `kani-dependencies` (nixpkgs' package, asserted to be that version) |
| Kissat | `4.0.1`, from its `kani-dependencies` (nixpkgs' recipe at that version's source) |

Kani is built as `cargo build-dev --release` builds it (`tools/build-kani`): `kani-driver` and `kani-compiler` with the
pinned nightly, then Kani's three sysroots (verification, playback, no-core), each built by `kani-compiler` with `-Z
build-std`. The standard library's own dependencies, from the toolchain's `library/Cargo.lock`, are vendored beside
Kani's, so the whole build runs offline. Three things upstream's build takes from a developer's machine are given
instead:
- Charon's manifest: it is in Kani's `Cargo.lock`, though its `llbc` feature is off. It is fetched at the submodule's
  commit, not with every submodule.
- The toolchain's name, `RUSTUP_TOOLCHAIN`, which `build-kani` stamps into what it builds.
- A `RUSTUP_HOME` holding the one pinned toolchain, in the store. `kani-compiler`'s build script puts its `lib` on the
  rpath.

The output is laid out as Kani's release bundle (`build-kani bundle`): `bin/` with `kani-driver`, `kani-compiler`, CBMC's
tools and Kissat; `library/`; the sysroots; and `toolchain`, the pinned nightly. `kani-driver` finds all of it beside
itself and runs that toolchain's `cargo`. `bin/kani` and `bin/cargo-kani` are `kani-driver` under those names, with the
release's `bin`, the toolchain and a C compiler (CBMC's `goto-cc` preprocesses with it) on the path. There is no
`kani setup` and no `~/.kani`.

## Use

```sh
nix build .#kani             # the release, at ./result
nix shell .#kani -c kani file.rs
nix shell .#kani -c cargo-kani -p my_crate
nix flake check              # a true assertion is verified; a false one is refused
```

As an input:

```nix
inputs.nix-kani.url = "github:daveman1010221/nix-kani";
# packages.${system}.kani, .toolchain, .cbmc, .kissat
```

Structured results: `cargo-kani -p my_crate -Z unstable-options --export-json results.json` (unstable in 0.68.0, so its
shape is the pinned release's).

## Bumping

Change `release.nix` to the new release:
- its tag's commit and hash (`nix flake prefetch github:model-checking/kani/kani-<version>`);
- the `channel` date of its `rust-toolchain.toml`;
- the CBMC and Kissat versions of its `kani-dependencies` (and Kissat's tag hash);
- the commit of its `charon` submodule (`gh api repos/model-checking/kani/contents/charon?ref=kani-<version>`) and that
  commit's hash.

The `tracing-tree` git dependency's hash in `pkgs/kani.nix` changes when its `Cargo.lock` does. If nixpkgs' CBMC is not
the pinned version, the evaluation says so. Then `nix flake check`.
