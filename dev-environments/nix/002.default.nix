# https://github.com/NixOS/nix/blob/master/default.nix
# used in 001.base.nix
# import ./docker.nix { inherit pkgs; tag = pkgs.nix.version; }
(import
  (
    let lock = builtins.fromJSON (builtins.readFile ./flake.lock); in
    fetchTarball {
      url = "https://github.com/edolstra/flake-compat/archive/${lock.nodes.flake-compat.locked.rev}.tar.gz";
      sha256 = lock.nodes.flake-compat.locked.narHash;
    }
  )
  { src = ./.; }
).defaultNix
