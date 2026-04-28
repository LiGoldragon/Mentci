{ pkgs, inputs, system, flake, ... }:

# Phase 3B — `nexus-render` renders the query reply Frame
# into user-visible nexus text. Output: $out/output.txt.

let
  nexus   = inputs.nexus.packages.${system}.default;
  handled = flake.checks.${system}.roundtrip-query-handle;
in
pkgs.runCommand "roundtrip-query-render" { } ''
  ${nexus}/bin/nexus-render < ${handled}/reply.bin > output.txt
  mkdir -p $out
  cp output.txt $out/output.txt
''
