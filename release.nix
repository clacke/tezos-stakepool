{ isTravis ? false
}:

let
  genJobs = nixpkgs: nixos: let
    pkgs = if nixpkgs == null then null else import nixpkgs {};
    os = import nixos {
      configuration = import ./stub-system/configuration.nix (lib.optionalAttrs (pkgs != null) { inherit pkgs; });
    };
  in
    { inherit (os) system; };
  inherit (import pinnedNixpkgs {}) lib;
  pinnedNixpkgs = import ./pins/nixpkgs;
  pinnedNixos = (import pinnedNixpkgs {}).runCommand "nixos" { inherit pinnedNixpkgs; } ''
    mkdir $out
    ln -s $pinnedNixpkgs $out/nixpkgs
    cat >$out/default.nix <<EOF
      { configuration }: import ./nixpkgs/nixos { inherit configuration; }
    EOF
  '';
in
genJobs null pinnedNixos // {
  unstable = genJobs <nixpkgs> <nixpkgs/nixos>;
  oldstable = genJobs <nixos-oldstable> <nixos-oldstable/nixos>;
  stable = genJobs <nixos-stable> <nixos-stable/nixos>;
  nixos-unstable = genJobs <nixos-unstable> <nixos-unstable/nixos>;
  x86_64-darwin = let
    darwin.pkgs = import (import ./pins/nixpkgs) { system = "x86_64-darwin"; };
    tezos-baking-platform = import (import ./pins/tezos-baking-platform) {
      nixpkgs = darwin.pkgs;
    };
    inherit (import <nixpkgs> {}) lib;
  in (lib.listToAttrs (map (name: lib.nameValuePair name tezos-baking-platform.tezos.${name}.kit)
                           (attrNames tezos-baking-platform.tezos))) // {
    inherit (import ./pkgs { inherit (darwin) pkgs; }) backerei;
  };
} // (import <nixpkgs> {}).lib.optionalAttrs isTravis {
  travisOrder = [ "system" ];
}
