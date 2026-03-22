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
    samskara-core-src = { url = "github:LiGoldragon/samskara-core"; flake = false; };
    samskara-src = { url = "github:LiGoldragon/samskara"; flake = false; };
    lojix-src = { url = "github:Criome/lojix"; flake = false; };
    samskara-codegen-src = { url = "github:LiGoldragon/samskara-codegen"; flake = false; };
    criome-store-src = { url = "github:LiGoldragon/criome-store"; flake = false; };
    criome-store-contract-src = { url = "github:LiGoldragon/criome-store-contract"; flake = false; };
    criome-stored-src = { url = "github:LiGoldragon/criome-stored"; flake = false; };
    samskara-reader-src = { url = "github:LiGoldragon/samskara-reader"; flake = false; };
    annas-archive-src = { url = "github:LiGoldragon/annas-archive"; flake = false; };
    claude-chill-src = { url = "github:davidbeesley/claude-chill"; flake = false; };
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

        # Samskara — pure datalog agent
        samskara = let
          cozoFilter = path: _type: builtins.match ".*\\.cozo$" path != null;
          src = pkgs.lib.cleanSourceWith {
            src = inputs.samskara-src;
            filter = path: type:
              (cozoFilter path type) || (craneLib.filterCargoSources path type);
          };
          commonArgs = {
            inherit src;
            pname = "samskara";
            postUnpack = ''
              depDir=$(dirname $sourceRoot)
              cp -rL ${inputs.criome-cozo-src} $depDir/criome-cozo
              cp -rL ${inputs.samskara-core-src} $depDir/samskara-core
              cp -rL ${inputs.samskara-lojix-contract-src} $depDir/samskara-lojix-contract
              cp -rL ${inputs.samskara-codegen-src} $depDir/samskara-codegen
            '';
            nativeBuildInputs = [ pkgs.capnproto ];
          };
          cargoArtifacts = craneLib.buildDepsOnly commonArgs;
        in craneLib.buildPackage (commonArgs // {
          inherit cargoArtifacts;
        });

        # Lojix — DSL transpiler agent
        lojix = let
          cozoFilter = path: _type: builtins.match ".*\\.cozo$" path != null;
          src = pkgs.lib.cleanSourceWith {
            src = inputs.lojix-src;
            filter = path: type:
              (cozoFilter path type) || (craneLib.filterCargoSources path type);
          };
          commonArgs = {
            inherit src;
            pname = "lojix";
            postUnpack = ''
              depDir=$(dirname $sourceRoot)
              cp -rL ${inputs.criome-cozo-src} $depDir/criome-cozo
              cp -rL ${inputs.samskara-core-src} $depDir/samskara-core
              cp -rL ${inputs.samskara-lojix-contract-src} $depDir/samskara-lojix-contract
              cp -rL ${inputs.samskara-codegen-src} $depDir/samskara-codegen
              cp -rL ${inputs.samskara-src} $depDir/samskara
            '';
            nativeBuildInputs = [ pkgs.capnproto ];
          };
          cargoArtifacts = craneLib.buildDepsOnly commonArgs;
        in craneLib.buildPackage (commonArgs // {
          inherit cargoArtifacts;
        });

        # criome-stored — content-addressed store agent
        criome-stored = let
          cozoFilter = path: _type: builtins.match ".*\\.cozo$" path != null;
          src = pkgs.lib.cleanSourceWith {
            src = inputs.criome-stored-src;
            filter = path: type:
              (cozoFilter path type) || (craneLib.filterCargoSources path type);
          };
          commonArgs = {
            inherit src;
            pname = "criome-stored";
            postUnpack = ''
              depDir=$(dirname $sourceRoot)
              cp -rL ${inputs.criome-cozo-src} $depDir/criome-cozo
              cp -rL ${inputs.criome-store-src} $depDir/criome-store
              cp -rL ${inputs.criome-store-contract-src} $depDir/criome-store-contract
              cp -rL ${inputs.samskara-core-src} $depDir/samskara-core
            '';
          };
          cargoArtifacts = craneLib.buildDepsOnly commonArgs;
        in craneLib.buildPackage (commonArgs // {
          inherit cargoArtifacts;
        });

        # Samskara Reader — read-only MCP server for samskara world state
        samskara-reader = let
          src = pkgs.lib.cleanSourceWith {
            src = inputs.samskara-reader-src;
            filter = path: type:
              (craneLib.filterCargoSources path type);
          };
          commonArgs = {
            inherit src;
            pname = "samskara-reader";
            postUnpack = ''
              depDir=$(dirname $sourceRoot)
              cp -rL ${inputs.criome-cozo-src} $depDir/criome-cozo
              cp -rL ${inputs.samskara-core-src} $depDir/samskara-core
            '';
          };
          cargoArtifacts = craneLib.buildDepsOnly commonArgs;
        in craneLib.buildPackage (commonArgs // {
          inherit cargoArtifacts;
        });

        # claude-chill — PTY proxy that eliminates scroll jitter
        claude-chill = let
          src = pkgs.lib.cleanSourceWith {
            src = inputs.claude-chill-src;
            filter = path: type:
              (craneLib.filterCargoSources path type);
          };
          commonArgs = {
            inherit src;
            pname = "claude-chill";
          };
          cargoArtifacts = craneLib.buildDepsOnly commonArgs;
        in craneLib.buildPackage (commonArgs // {
          inherit cargoArtifacts;
        });

        # MCP wrappers — on PATH via devShell, no store paths in config
        samskara-mcp = pkgs.writeShellScriptBin "samskara-mcp" ''
          db="''${SAMSKARA_DB_PATH:-''${MENTCI_V1_ROOT:+$MENTCI_V1_ROOT/../samskara/world.db}}"
          db="''${db:-$HOME/.local/share/samskara/world.db}"
          mkdir -p "$(dirname "$db")"
          exec env \
            RUST_LOG="''${RUST_LOG:-info}" \
            samskara --db-path "$db"
        '';

        criome-stored-mcp = pkgs.writeShellScriptBin "criome-stored-mcp" ''
          exec env \
            RUST_LOG="''${RUST_LOG:-info}" \
            criome-stored
        '';

        samskara-reader-mcp = pkgs.writeShellScriptBin "samskara-reader-mcp" ''
          db="''${SAMSKARA_DB_PATH:-''${MENTCI_V1_ROOT:+$MENTCI_V1_ROOT/../samskara/world.db}}"
          db="''${db:-$HOME/.local/share/samskara/world.db}"
          exec env \
            RUST_LOG="''${RUST_LOG:-info}" \
            samskara-reader --db-path "$db"
        '';

        annas-archive-mcp = pkgs.writeShellScriptBin "annas-archive-mcp" ''
          exec env \
            ANNAS_ARCHIVE_API_KEY="$(gopass show -o annas-archive.gl/secret-key)" \
            RUST_LOG="''${RUST_LOG:-info}" \
            annas-archive
        '';

        mcpConfig = builtins.toJSON {
          mcpServers = {
            samskara = {
              command = "samskara-mcp";
            };
            criome-stored = {
              command = "criome-stored-mcp";
            };
            annas-archive = {
              command = "annas-archive-mcp";
            };
          };
        };

        mcpConfigLite = builtins.toJSON {
          mcpServers = {
            samskara-reader = {
              command = "samskara-reader-mcp";
            };
            annas-archive = {
              command = "annas-archive-mcp";
            };
          };
        };

        commonPackages = [
          rustToolchain
          pkgs.rust-analyzer
          pkgs.jujutsu
          pkgs.sqlite
          pkgs.capnproto
          pkgs.gopass
          claude-code.packages.${system}.default
          claude-chill
          annas-archive
          annas-archive-mcp
          samskara-reader
          samskara-reader-mcp
          criome-stored
          criome-stored-mcp
        ];

      in
      {
        devShells.default = pkgs.mkShell {
          name = "mentci-v1";
          packages = commonPackages ++ [
            samskara
            samskara-mcp
            lojix
          ];
          env = {
            RUST_SRC_PATH = "${pkgs.rustPlatform.rustLibSrc}";
          };
          shellHook = ''
            export MENTCI_V1_ROOT="$(pwd)"
            echo '${mcpConfig}' > .mcp.json
            echo "mentci-v1: workspace active (claude + samskara + annas-archive)"
          '';
        };

        devShells.lite = pkgs.mkShell {
          name = "mentci-lite";
          packages = commonPackages ++ [ lojix ];
          env = {
            RUST_SRC_PATH = "${pkgs.rustPlatform.rustLibSrc}";
          };
          shellHook = ''
            echo '${mcpConfigLite}' > .mcp.json
            echo "mentci-lite: workspace active (claude + annas-archive, no samskara)"
          '';
        };
      }
    );
}
