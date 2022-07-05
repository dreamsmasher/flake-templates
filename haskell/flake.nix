{
  description = "Example Haskell flake showing overrides and adding stuff to the dev shell";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
  };

  nixConfig.allow-import-from-derivation = true; # cabal2nix uses IFD

  outputs = { self, nixpkgs, utils }:
    let
      ghcVer = "ghc902";
      makeHaskellOverlay = overlay: final: prev: {
        haskell = prev.haskell // {
          packages = prev.haskell.packages // {
            ${ghcVer} = prev.haskell.packages."${ghcVer}".override (oldArgs: {
              overrides =
                prev.lib.composeExtensions (oldArgs.overrides or (_: _: { }))
                  (overlay prev);
            });
          };
        };
      };

      out = system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ self.overlays.default ];
            config.allowBroken = true;
          };

        in
        {
          packages = rec {
            default = sample;
            sample = pkgs.haskell.packages.${ghcVer}.sample;
          };

          checks = {
            inherit (self.packages.${system}) sample;
          };

          # for debugging
          # inherit pkgs;

          devShells.default =
            let haskellPackages = pkgs.haskell.packages.${ghcVer};
            in
            haskellPackages.shellFor {
              packages = p: [ self.packages.${system}.sample ];
              withHoogle = true;
              buildInputs = with haskellPackages; [
                haskell-language-server
                fourmolu
                ghcid
                cabal-install
                fast-tags
                friendly
              ] ++ (with pkgs; [
                sqlite
              ]);
              # Change the prompt to show that you are in a devShell
              # shellHook = "export PS1='\\e[1;34mdev > \\e[0m'";
            };
        };
    in
    utils.lib.eachDefaultSystem out // {
      # this stuff is *not* per-system
      overlays = {
        default = makeHaskellOverlay (prev: hfinal: hprev:
          let hlib = prev.haskell.lib; in
          {
            sample = hprev.callCabal2nix "sample" ./. { };

            # here's how to do hacks to the package set
            # don't run the test suite
            fast-tags = hlib.dontCheck hprev.fast-tags;
            # don't check version bounds
            friendly = hlib.doJailbreak hprev.friendly;
          });
      };
    };
}
