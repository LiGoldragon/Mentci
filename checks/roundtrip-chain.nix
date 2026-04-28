{ pkgs, system, flake, ... }:

# Terminal assertion derivation for the four-phase
# parse → handle → render round-trip chain. Asserts the
# user-visible text outputs from both the assert and query
# halves match what reports/100 §5 specifies as the M0 demo
# contract.
#
# The dependency graph leading here forces the whole chain
# to build:
#
#   roundtrip-assert-parse  →  roundtrip-assert-handle  →  roundtrip-assert-render  ┐
#                                       │                                            │
#                                       └─ state.redb chains forward ─┐              │
#                                                                     ▼              │
#   roundtrip-query-parse   →  roundtrip-query-handle   →  roundtrip-query-render   ┤
#                                                                                   │
#                                                                                   ▼
#                                                                          roundtrip-chain
#
# This is the binary-stability-across-process-boundaries
# regression gate: each daemon transformation runs in its own
# pure-build sandbox; rkyv frames are written to disk and
# read back by a fresh process; sema's redb file persists
# across separate `criome-handle-frame` invocations.

let
  assertRender = flake.checks.${system}.roundtrip-assert-render;
  queryRender  = flake.checks.${system}.roundtrip-query-render;
in
pkgs.runCommand "roundtrip-chain" { } ''
  set -euo pipefail

  if ! grep -qE '^\(Ok\)$' ${assertRender}/output.txt; then
    echo "FAIL roundtrip-assert-render:"
    echo "  expected: (Ok)"
    echo "  got:      $(cat ${assertRender}/output.txt)"
    exit 1
  fi

  if ! grep -qE '^\[\(Node "User"\)\]$' ${queryRender}/output.txt; then
    echo "FAIL roundtrip-query-render:"
    echo "  expected: [(Node \"User\")]"
    echo "  got:      $(cat ${queryRender}/output.txt)"
    exit 1
  fi

  echo "roundtrip chain passed: text → Frame → reply Frame → text across separate one-shot binary invocations with state.redb forwarded between handle phases"
  touch $out
''
