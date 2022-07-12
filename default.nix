{ pkgs ? import <nixpkgs> { config = { allowUnfree = true; }; }
, gpus ? [ "intel" ]
, enable32bits ? true
}:

pkgs.callPackage ./gfx-wrap.nix {
  inherit gpus enable32bits;
}
