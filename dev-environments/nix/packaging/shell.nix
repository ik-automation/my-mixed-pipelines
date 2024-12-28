# https://github.com/NixOS/nix/blob/master/shell.nix
(import (fetchTarball "https://github.com/edolstra/flake-compat/archive/master.tar.gz") {
  src = ./.;
}).shellNix
