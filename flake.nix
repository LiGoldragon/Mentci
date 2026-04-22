{
  description = "Simple flake with a devshell";

  # Add all your dependencies here
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs?ref=nixos-unstable";
    blueprint.url = "github:numtide/blueprint";
    blueprint.inputs.nixpkgs.follows = "nixpkgs";
    mentci-tools.url = "github:LiGoldragon/mentci-tools";
    mentci-tools.inputs.nixpkgs.follows = "nixpkgs";
    mentci-tools.inputs.blueprint.follows = "blueprint";
  };

  # Load the blueprint
  outputs = inputs: inputs.blueprint { inherit inputs; };
}
