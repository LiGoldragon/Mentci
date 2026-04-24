{ pkgs, inputs, system }:
let
  # Sibling repos under ~/git/ to expose as symlinks in ./repos/.
  # This list IS the canonical workspace manifest for agents.
  # Entries align with docs/workspace-manifest.md.
  # Direnv / nix develop entry creates the links.
  linkedRepos = [
    "tools-documentation"
    "criome"          # spec repo — runtime pillar
    "nota"            # spec repo — data grammar
    "nota-serde-core" # shared lexer + ser/de kernel
    "nota-serde"      # nota's public API
    "nexus"           # spec repo — messaging grammar
    "nexus-serde"     # nexus's public API
    "nexus-schema"    # record-kind vocabulary
    "sema"            # records DB (redb-backed)
    "nexusd"          # messenger daemon
    "nexus-cli"       # text client
    "rsc"             # records → Rust source projector
    "lojix"           # TRANSITIONAL — currently Li's deploy CLI (report 030)
    # --- CANON-MISSING (repos don't exist yet; uncomment when scaffolded) ---
    # "criomed"       # sema's engine daemon
    # "criome-msg"    # nexusd↔criomed contract
    # "lojix-msg"     # criomed↔lojixd contract (report 030 Phase B)
    # "lojixd"        # lojix daemon (report 030 Phase C)
    # "lojix-store"   # content-addressed filesystem
  ];

  linkSiblingRepos = ''
    mkdir -p repos
    ${pkgs.lib.concatMapStringsSep "\n" (name: ''
      if [ -d "$HOME/git/${name}" ]; then
        ln -sfn "$HOME/git/${name}" "repos/${name}"
      else
        echo "warn: $HOME/git/${name} not found; skipping symlink" >&2
      fi
    '') linkedRepos}
  '';
in
pkgs.mkShell {
  packages = [
    inputs.mentci-tools.packages.${system}.beads
    inputs.mentci-tools.packages.${system}.dolt
  ];

  env = { };

  shellHook = ''
    ${linkSiblingRepos}
  '';
}
