{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = [
    pkgs.bluespec
  ];

  shellHook = ''
    export BLUESPECDIR=${pkgs.bluespec}/lib
    '';
}
