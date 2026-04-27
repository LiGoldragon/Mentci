{ pkgs, inputs, system, ... }:

# Workspace-level aggregator. Depends on every CANON crate's
# `checks.default` plus the end-to-end `integration` check that
# brings up criome-daemon + nexus-daemon and shuttles the demo
# from reports/100 §5 through nexus-cli.
#
# `nix flake check` from mentci runs the entire workspace plus
# the integration test in a single sandboxed parallel pass.

let
  criome    = inputs.criome.packages.${system}.default;
  nexus     = inputs.nexus.packages.${system}.default;
  nexus-cli = inputs.nexus-cli.packages.${system}.default;

  # End-to-end shuttle test. Starts both daemons in the sandbox,
  # pipes the demo text through nexus-cli, asserts the canonical
  # `(Ok)` and `[(Node "User")]` replies come back. Covers the
  # full assert + query path through every CANON crate.
  integration = pkgs.runCommand "mentci-integration" { } ''
    set -euo pipefail

    cd $TMPDIR
    criome_socket=$PWD/criome.sock
    sema_path=$PWD/sema.redb
    nexus_socket=$PWD/nexus.sock

    cleanup() {
      kill ''${nexus_pid:-} ''${criome_pid:-} 2>/dev/null || true
      wait 2>/dev/null || true
    }
    trap cleanup EXIT

    # Start criome.
    CRIOME_SOCKET=$criome_socket SEMA_PATH=$sema_path \
      ${criome}/bin/criome-daemon &
    criome_pid=$!
    for i in $(seq 1 50); do
      [ -S "$criome_socket" ] && break
      sleep 0.1
    done
    [ -S "$criome_socket" ] || { echo "criome-daemon failed to bind"; exit 1; }

    # Start nexus.
    NEXUS_SOCKET=$nexus_socket CRIOME_SOCKET=$criome_socket \
      ${nexus}/bin/nexus-daemon &
    nexus_pid=$!
    for i in $(seq 1 50); do
      [ -S "$nexus_socket" ] && break
      sleep 0.1
    done
    [ -S "$nexus_socket" ] || { echo "nexus-daemon failed to bind"; exit 1; }

    # Assert (Node "User") → (Ok)
    assert_reply=$(echo '(Node "User")' | NEXUS_SOCKET=$nexus_socket ${nexus-cli}/bin/nexus)
    if [ "$assert_reply" != '(Ok)' ]; then
      echo "FAIL: expected '(Ok)', got: $assert_reply"
      exit 1
    fi

    # Query (| Node @name |) → [(Node "User")]
    query_reply=$(echo '(| Node @name |)' | NEXUS_SOCKET=$nexus_socket ${nexus-cli}/bin/nexus)
    if [ "$query_reply" != '[(Node "User")]' ]; then
      echo "FAIL: expected '[(Node \"User\")]', got: $query_reply"
      exit 1
    fi

    # Diagnostic path — unsupported verb returns a typed Diagnostic
    diagnostic_reply=$(echo '~(Node "User")' | NEXUS_SOCKET=$nexus_socket ${nexus-cli}/bin/nexus)
    case "$diagnostic_reply" in
      '(Diagnostic Error "E0099"'*) ;;
      *) echo "FAIL: expected '(Diagnostic Error \"E0099\" ...)', got: $diagnostic_reply"; exit 1 ;;
    esac

    echo "integration test passed: assert + query + diagnostic shuttle through criome-daemon + nexus-daemon + nexus-cli"
    touch $out
  '';
in
pkgs.linkFarm "mentci-workspace-checks" [
  { name = "nota-derive"; path = inputs.nota-derive.checks.${system}.default; }
  { name = "nota-codec";  path = inputs.nota-codec.checks.${system}.default; }
  { name = "signal";      path = inputs.signal.checks.${system}.default; }
  { name = "sema";        path = inputs.sema.checks.${system}.default; }
  { name = "criome";      path = inputs.criome.checks.${system}.default; }
  { name = "nexus";       path = inputs.nexus.checks.${system}.default; }
  { name = "nexus-cli";   path = inputs.nexus-cli.checks.${system}.default; }
  { name = "integration"; path = integration; }
]
