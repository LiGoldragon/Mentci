{ pkgs, inputs, system, flake, ... }:

# Step B — query (| Node @name |) against the sema state
# produced by step A. References the prior step via
# `flake.checks.${system}.scenario-assert-node`, which carries
# `state.redb` forward in the Nix dependency graph.

let
  step = flake.lib.scenario {
    inherit pkgs;
    criome    = inputs.criome.packages.${system}.default;
    nexus     = inputs.nexus.packages.${system}.default;
    nexus-cli = inputs.nexus-cli.packages.${system}.default;
  };
in
step {
  name       = "scenario-query-nodes";
  input      = ''(| Node @name |)'';
  priorState = flake.checks.${system}.scenario-assert-node;
}
