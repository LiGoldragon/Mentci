{ pkgs, system, flake, ... }:

# Terminal assertion derivation — depends on both step A and
# step B via `flake.checks.${system}.X` and grep-asserts the
# canonical text replies. Failures pinpoint the specific
# step's `response.txt` so debugging starts at the isolated
# boundary.

let
  assertNode = flake.checks.${system}.scenario-assert-node;
  queryNodes = flake.checks.${system}.scenario-query-nodes;
in
pkgs.runCommand "scenario-chain" { } ''
  set -euo pipefail

  if ! grep -qE '^\(Ok\)$' ${assertNode}/response.txt; then
    echo "FAIL scenario-assert-node:"
    echo "  expected: (Ok)"
    echo "  got:      $(cat ${assertNode}/response.txt)"
    exit 1
  fi

  if ! grep -qE '^\[\(Node "User"\)\]$' ${queryNodes}/response.txt; then
    echo "FAIL scenario-query-nodes:"
    echo "  expected: [(Node \"User\")]"
    echo "  got:      $(cat ${queryNodes}/response.txt)"
    exit 1
  fi

  echo "scenario chain passed: assert + query round-trip with sema state preserved across derivation boundaries"
  touch $out
''
