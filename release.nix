# The Kani release this flake builds, and what it pins: read from the release's own rust-toolchain.toml and
# kani-dependencies, and its charon submodule's commit.
{
  version = "0.68.0";
  rev = "0d2328a93f0e0ff66132d6bfa1a7d884877cf862";
  hash = "sha256-6BT2BGgrkeZ5yoLj6ra01kECqbGVJfbkoch1ns7HXH0=";
  # rust-toolchain.toml: channel = "nightly-2026-08-21".
  nightly = "2026-08-21";
  # kani-dependencies; nixpkgs' CBMC is this version, and the build refuses another.
  cbmc = "6.11.0";
  kissat = {
    version = "4.0.1";
    hash = "sha256-+y9TlSEgnMTtRT9F6OBSle9OqGfljChcHOFJ5lgwjyk=";
  };
  # Not built (its `llbc` feature is off), but in Kani's Cargo.lock, so cargo reads its manifest.
  charon = {
    rev = "b250680abd40ff1aaa07081d0497dc2755ed112e";
    hash = "sha256-J/of5Bdj3fUFud7XPxVZXNtdUx1rMDiqS8fsptQVfQg=";
  };
}
