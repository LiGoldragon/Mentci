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

    # Component sources
    samskara-lojix-contract-src = { url = "github:LiGoldragon/samskara-lojix-contract"; flake = false; };
    criome-cozo-src = { url = "github:LiGoldragon/criome-cozo"; flake = false; };
    samskara-src = { url = "github:LiGoldragon/samskara"; flake = false; };
    lojix-src = { url = "github:LiGoldragon/lojix"; flake = false; };
    samskara-codegen-src = { url = "github:LiGoldragon/samskara-codegen"; flake = false; };
    mentci-v0-src = { url = "github:Mentci-AI/dev"; flake = false; };
  };

  outputs = inputs@{ self, nixpkgs, flake-utils, crane, fenix, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        rustToolchain = fenix.packages.${system}.latest.toolchain;
        craneLib = (crane.mkLib pkgs).overrideToolchain rustToolchain;
      in
      {
        devShells.default = pkgs.mkShell {
          name = "mentci-v1";
          packages = with pkgs; [
            rustToolchain
            rust-analyzer
            jujutsu
            sqlite
            capnproto
          ];
          env = {
            RUST_SRC_PATH = "${pkgs.rustPlatform.rustLibSrc}";
          };
          shellHook = ''
            export MENTCI_V1_ROOT="$(pwd)"
            echo "mentci-v1: VersionOne workspace active"
          '';
        };
      }
    );
}
