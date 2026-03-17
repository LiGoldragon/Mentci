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

    # Component sources (public repos only — private/empty repos are
    # commented out to avoid blocking flake lock resolution)
    samskara-lojix-contract-src = { url = "github:LiGoldragon/samskara-lojix-contract"; flake = false; };
    criome-cozo-src = { url = "github:LiGoldragon/criome-cozo"; flake = false; };
    # samskara-src: private repo — requires auth token, uncomment when available
    # samskara-src = { url = "github:LiGoldragon/samskara"; flake = false; };
    # lojix-src: empty repo — uncomment once it has initial content
    # lojix-src = { url = "github:LiGoldragon/lojix"; flake = false; };
  };

  outputs = inputs@{ self, nixpkgs, flake-utils, crane, fenix, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        rustToolchain = fenix.packages.${system}.latest.toolchain;
        craneLib = (crane.mkLib pkgs).overrideToolchain rustToolchain;
      in
      let
        # All devshell packages in one list — shared between mkShell and the image
        devPackages = with pkgs; [
          # Rust
          rustToolchain
          rust-analyzer
          cargo-nextest

          # VCS
          jujutsu

          # Native build deps (cozo-ce storage-sqlite, openssl-sys, etc.)
          pkg-config
          cmake
          gnumake
          sqlite
          openssl

          # GitHub
          gh

          # Nix tooling
          nil         # Nix LSP
          nixpkgs-fmt # Nix formatter
        ];
      in
      {
        devShells.default = pkgs.mkShell {
          name = "mentci-v1";
          packages = devPackages;

          env = {
            RUST_SRC_PATH = "${pkgs.rustPlatform.rustLibSrc}";
          };

          shellHook = ''
            export MENTCI_V1_ROOT="$(pwd)"
            echo "mentci-v1: VersionOne workspace active"
            echo "  rust : $(rustc --version)"
            echo "  jj   : $(jj --version)"
          '';
        };

        # Pre-built container image for Claude Web sessions.
        # Build:  nix build .#devshell-image
        # Load:   On session start, pull from GHCR + extract rootfs + chroot
        packages.devshell-image = pkgs.dockerTools.buildLayeredImage {
          name = "ghcr.io/ligoldragon/mentci-devshell";
          tag = "latest";

          contents = with pkgs; [
            # Base OS utilities needed inside the container
            bashInteractive
            coreutils
            gnugrep
            gnused
            findutils
            gawk
            gnutar
            gzip
            which
            less
            cacert  # TLS root certs

            # Git (backend for jj)
            git
          ] ++ devPackages;

          config = {
            Env = [
              "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
              "RUST_SRC_PATH=${pkgs.rustPlatform.rustLibSrc}"
              "MENTCI_V1_ROOT=/workspace"
            ];
            WorkingDir = "/workspace";
          };
        };
      }
    );
}
