{ pkgs, inputs, system }:
pkgs.mkShell {
  packages = [
    inputs.mentci-tools.packages.${system}.beads
    inputs.mentci-tools.packages.${system}.dolt
  ];

  env = { };

  shellHook = ''
  '';
}
