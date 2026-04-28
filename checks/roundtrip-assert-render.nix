{ pkgs, inputs, system, flake, ... }:

# Phase 3A — `nexus-render` renders the reply Frame into
# user-visible nexus text. Output: $out/output.txt.

let
  nexus   = inputs.nexus.packages.${system}.default;
  handled = flake.checks.${system}.roundtrip-assert-handle;
in
pkgs.runCommand "roundtrip-assert-render" { } ''
  ${nexus}/bin/nexus-render < ${handled}/reply.bin > output.txt
  mkdir -p $out
  cp output.txt $out/output.txt
''
