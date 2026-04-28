{ ... }:

# Workspace-level helpers exposed as `flake.lib`. Each entry
# is a system-agnostic function — callers (typically files
# under `checks/`) supply the system-specific `pkgs` and
# package paths.
{
  # Step builder for the chained-derivation scenario suite —
  # see [`scenario.nix`](./scenario.nix) for the full doc.
  # Used by `checks/scenario-*.nix` to spawn one
  # daemon-shuttle step in its own pure-build sandbox and
  # capture both `response.txt` and `state.redb` so the next
  # step in the chain can consume them as a derivation input.
  scenario = import ./scenario.nix;
}
