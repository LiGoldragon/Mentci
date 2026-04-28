{ pkgs, inputs, system, flake, ... }:

# Phase 2B — `criome-handle-frame` dispatches the query Frame
# against the sema state produced by phase 2A. The prior
# `state.redb` is copied in as the writable starting point;
# the query reads but doesn't mutate, so $out/state.redb is
# functionally identical to the input — kept anyway so future
# phases can chain off this point.

let
  criome   = inputs.criome.packages.${system}.default;
  prior    = flake.checks.${system}.roundtrip-assert-handle;
  parsed   = flake.checks.${system}.roundtrip-query-parse;
in
pkgs.runCommand "roundtrip-query-handle" { } ''
  set -euo pipefail
  cd $TMPDIR
  install -m 644 ${prior}/state.redb sema.redb

  SEMA_PATH=$PWD/sema.redb \
    ${criome}/bin/criome-handle-frame < ${parsed}/frame.bin > reply.bin

  mkdir -p $out
  cp reply.bin $out/reply.bin
  cp sema.redb $out/state.redb
''
