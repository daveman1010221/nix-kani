# That the built Kani proves what holds and refuses what does not: one harness whose assertion holds for every input,
# and one whose assertion some input breaks.
{ runCommand, kani }:
{
  proves = runCommand "kani-proves" { nativeBuildInputs = [ kani ]; } ''
    export HOME=$TMPDIR
    kani ${./holds.rs}
    touch $out
  '';
  refuses = runCommand "kani-refuses" { nativeBuildInputs = [ kani ]; } ''
    export HOME=$TMPDIR
    if kani ${./fails.rs}; then
      echo "kani accepted an assertion that does not hold" >&2
      exit 1
    fi
    touch $out
  '';
}
