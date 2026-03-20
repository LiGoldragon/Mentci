{
  description = "Mentci VersionOne — Samskara + Lojix Workspace";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    crane.url = "github:ipetkov/crane";
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Claude Code
    claude-code.url = "github:sadjow/claude-code-nix";

    # Component sources
    samskara-lojix-contract-src = { url = "github:LiGoldragon/samskara-lojix-contract"; flake = false; };
    criome-cozo-src = { url = "github:LiGoldragon/criome-cozo"; flake = false; };
    # samskara-src = { url = "github:LiGoldragon/samskara"; flake = false; };  # private repo
    # lojix-src = { url = "github:LiGoldragon/lojix"; flake = false; };  # empty repo
    samskara-codegen-src = { url = "github:LiGoldragon/samskara-codegen"; flake = false; };
    annas-archive-src = { url = "github:LiGoldragon/annas-archive"; flake = false; };
    # mentci-v0-src = { url = "github:Mentci-AI/dev"; flake = false; };  # private/deleted
  };

  outputs = inputs@{ self, nixpkgs, flake-utils, crane, fenix, claude-code, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        rustToolchain = fenix.packages.${system}.latest.toolchain;
        craneLib = (crane.mkLib pkgs).overrideToolchain rustToolchain;

        # Build component binaries from flake inputs
        annas-archive = let
          src = pkgs.lib.cleanSourceWith {
            src = inputs.annas-archive-src;
            filter = path: type:
              (craneLib.filterCargoSources path type);
          };
          commonArgs = {
            inherit src;
            pname = "annas-archive";
          };
          cargoArtifacts = craneLib.buildDepsOnly commonArgs;
        in craneLib.buildPackage (commonArgs // {
          inherit cargoArtifacts;
        });

        # MCP wrapper — on PATH via devShell, no store paths in config
        # TODO: add samskara-mcp once the repo is public
        annas-archive-mcp = pkgs.writeShellScriptBin "annas-archive-mcp" ''
          exec env \
            ANNAS_ARCHIVE_API_KEY="$(gopass show -o annas-archive.gl/secret-key)" \
            RUST_LOG="''${RUST_LOG:-info}" \
            annas-archive
        '';

        mcpConfig = builtins.toJSON {
          mcpServers = {
            annas-archive = {
              command = "annas-archive-mcp";
            };
          };
        };

      in
      {
        devShells.default = pkgs.mkShell {
          name = "mentci-v1";
          packages = [
            rustToolchain
            pkgs.rust-analyzer
            pkgs.jujutsu
            pkgs.sqlite
            pkgs.capnproto
            pkgs.gopass
            claude-code.packages.${system}.default
            annas-archive
            annas-archive-mcp
          ];
          env = {
            RUST_SRC_PATH = "${pkgs.rustPlatform.rustLibSrc}";
          };
          shellHook = ''
            export MENTCI_V1_ROOT="$(pwd)"

            # Generate .mcp.json — commands resolve via PATH, no store paths
            echo '${mcpConfig}' > .mcp.json

            echo "mentci-v1: workspace active (claude + samskara + annas-archive)"
          '';
        };
      }
    );
}
