# Kissat at the version Kani pins (its kani-dependencies): nixpkgs' recipe, at that version's source.
{ kissat, fetchFromGitHub, release }:
kissat.overrideAttrs (old: {
  version = release.kissat.version;
  src = fetchFromGitHub {
    owner = "arminbiere";
    repo = "kissat";
    rev = "rel-${release.kissat.version}";
    hash = release.kissat.hash;
  };
})
