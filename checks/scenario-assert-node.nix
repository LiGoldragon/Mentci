{ pkgs, inputs, system, flake, ... }:

# Step A — assert (Node "User") into a fresh sema database.
# Captures the (Ok) reply text and the resulting sema state.

let
  step = flake.lib.scenario {
    inherit pkgs;
    criome    = inputs.criome.packages.${system}.default;
    nexus     = inputs.nexus.packages.${system}.default;
    nexus-cli = inputs.nexus-cli.packages.${system}.default;
  };
in
step {
  name  = "scenario-assert-node";
  input = ''(Node "User")'';
}
