{ pkgs, inputs, system, flake, ... }:

# Phase 2A — `criome-handle-frame` dispatches the assert
# Frame against a fresh sema. Output: $out/reply.bin
# (length-prefixed reply Frame) + $out/state.redb (sema after
# the assert, ready to thread into the query chain).

let
  criome = inputs.criome.packages.${system}.default;
  parsed = flake.checks.${system}.roundtrip-assert-parse;
in
pkgs.runCommand "roundtrip-assert-handle" { } ''
  set -euo pipefail
  cd $TMPDIR

  SEMA_PATH=$PWD/sema.redb \
    ${criome}/bin/criome-handle-frame < ${parsed}/frame.bin > reply.bin

  mkdir -p $out
  cp reply.bin $out/reply.bin
  cp sema.redb $out/state.redb
''
