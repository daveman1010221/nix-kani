# Kani from its release tag, as `cargo build-dev --release` builds it (Kani's tools/build-kani): kani-driver and
# kani-compiler with the nightly the release pins, then Kani's three sysroots, each built by kani-compiler
# with `-Z build-std`. The standard library's own dependencies are vendored beside Kani's, so that build-std runs
# offline. The output is laid out as a release bundle (`build-kani bundle`): kani-driver finds kani-compiler, the
# library and the sysroots beside it, and cargo in `toolchain/`; CBMC, its goto tools and Kissat are in `bin/`.
{
  lib,
  stdenv,
  fetchFromGitHub,
  makeRustPlatform,
  makeWrapper,
  runCommand,
  cbmc,
  release,
  toolchain,
  kissat,
}:
let
  rustPlatform = makeRustPlatform {
    cargo = toolchain;
    rustc = toolchain;
  };
  # As rustup names the pinned nightly.
  toolchainName = "nightly-${release.nightly}-${stdenv.hostPlatform.rust.rustcTarget}";
  # kani-compiler's build script puts `$RUSTUP_HOME/toolchains/$RUSTUP_TOOLCHAIN/lib` on its rpath, for rustc's own
  # libraries: a rustup home of one toolchain, the pinned one, so that the path it bakes in is in the store.
  rustupHome = runCommand "kani-rustup-home" { } ''
    mkdir -p $out/toolchains
    ln -s ${toolchain} $out/toolchains/${toolchainName}
  '';
  src = fetchFromGitHub {
    owner = "model-checking";
    repo = "kani";
    rev = release.rev;
    hash = release.hash;
  };
  charon = fetchFromGitHub {
    owner = "AeneasVerif";
    repo = "charon";
    rev = release.charon.rev;
    hash = release.charon.hash;
  };
  kaniDeps = rustPlatform.importCargoLock {
    lockFile = "${src}/Cargo.lock";
    outputHashes = {
      "tracing-tree-0.4.0" = "sha256-YjkXsOn/aLEYxvys9TFZjTyUMPxk3WsI6bbJsbwSiKY=";
    };
  };
  # What `-Z build-std` builds the standard library with: the crates of the toolchain's own library/Cargo.lock.
  stdDeps = rustPlatform.importCargoLock {
    lockFile = "${toolchain}/lib/rustlib/src/rust/library/Cargo.lock";
  };
  # One vendor directory for both, Kani's source replacement (its git dependency included) kept. Named as importCargoLock
  # names its own, which is the name cargoSetupHook looks for.
  cargoDeps = runCommand "cargo-vendor-dir" { } ''
    mkdir -p $out
    cp -rs --no-preserve=mode ${kaniDeps}/. $out/
    for crate in ${stdDeps}/*; do
      name=$(basename "$crate")
      [ -e "$out/$name" ] || ln -s "$crate" "$out/$name"
    done
  '';
in
stdenv.mkDerivation {
  pname = "kani";
  inherit (release) version;
  inherit src cargoDeps;

  postUnpack = ''
    rmdir $sourceRoot/charon
    cp -r ${charon} $sourceRoot/charon
    chmod -R u+w $sourceRoot/charon
  '';

  nativeBuildInputs = [
    rustPlatform.cargoSetupHook
    toolchain
    makeWrapper
  ];

  buildPhase = ''
    runHook preBuild
    export HOME=$TMPDIR
    export CARGO_NET_OFFLINE=true
    # kani-compiler links rustc's own libraries: at build time, it runs from here to build the sysroots.
    export LD_LIBRARY_PATH=${toolchain}/lib
    # What rustup would set: Kani's build stamps the toolchain's name into what it builds.
    export RUSTUP_TOOLCHAIN=${toolchainName} RUSTUP_HOME=${rustupHome}
    cargo build-dev --release
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/library
    cp target/kani/bin/kani-driver target/kani/bin/kani-compiler $out/bin/
    cp -r library/kani library/kani_macros library/std $out/library/
    cp -r target/kani/lib target/kani/playback target/kani/no_core $out/
    ln -s ${toolchain} $out/toolchain
    echo -n ${toolchainName} > $out/rust-toolchain-version
    for tool in cbmc goto-instrument goto-cc goto-analyzer; do
      ln -s ${cbmc}/bin/$tool $out/bin/$tool
    done
    ln -s ${kissat}/bin/kissat $out/bin/kissat
    # `kani` and `cargo kani` are kani-driver, told which by the name it is run as, with its own bin first on the path
    # (Kani's src/lib.rs, `exec`): there is no rustup and no ~/.kani to find. CBMC's goto-cc preprocesses Kani's C
    # library with the C compiler it finds on the path.
    for name in kani cargo-kani; do
      makeWrapper $out/bin/kani-driver $out/bin/$name \
        --argv0 $name \
        --prefix PATH : $out/bin:${toolchain}/bin:${stdenv.cc}/bin
    done
    runHook postInstall
  '';

  passthru = {
    inherit toolchain cbmc kissat;
  };

  meta = {
    description = "Kani: bounded model checking of Rust, with CBMC, at release ${release.version}";
    homepage = "https://github.com/model-checking/kani";
    license = with lib.licenses; [
      asl20
      mit
    ];
    mainProgram = "cargo-kani";
    platforms = lib.platforms.linux;
  };
}
