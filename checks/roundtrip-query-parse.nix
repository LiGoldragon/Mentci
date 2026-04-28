{ pkgs, inputs, system, ... }:

# Phase 1B — `nexus-parse` parses the query text into a
# length-prefixed signal Frame. Output: $out/frame.bin.

let
  nexus = inputs.nexus.packages.${system}.default;
  input = pkgs.writeText "roundtrip-query-input" ''(| Node @name |)'';
in
pkgs.runCommand "roundtrip-query-parse" { } ''
  ${nexus}/bin/nexus-parse < ${input} > frame.bin
  mkdir -p $out
  cp frame.bin $out/frame.bin
''
