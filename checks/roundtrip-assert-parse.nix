{ pkgs, inputs, system, ... }:

# Phase 1A — `nexus-parse` parses the assert text into a
# length-prefixed signal Frame. Output: $out/frame.bin.

let
  nexus = inputs.nexus.packages.${system}.default;
  input = pkgs.writeText "roundtrip-assert-input" ''(Node "User")'';
in
pkgs.runCommand "roundtrip-assert-parse" { } ''
  ${nexus}/bin/nexus-parse < ${input} > frame.bin
  mkdir -p $out
  cp frame.bin $out/frame.bin
''
