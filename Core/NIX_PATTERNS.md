# Nix Patterns

How to write Nix for the Criome. Nix is the build system and
environment layer — it produces artifacts and shells, never application
logic.

---

## Naming

Naming in Nix follows the same semantic-layer principle as Rust
(see [SEPARATION.md](SEPARATION.md)), adapted to Nix's idioms.

- `camelCase` — functions, derivation builders, relations, flow
- `kebab-case` — package names, flake output attributes
- `PascalCase` — never used in Nix (reserved for Rust types)

A suffix that restates the type is invalid:

```nix
# WRONG
packages.x86_64-linux.userPackage = ...;

# RIGHT — context makes the role clear
packages.x86_64-linux.user = ...;
```

---

## Attrsets Exist; Flows Occur

Attrsets are nouns — they exist independently of evaluation. Functions
are verbs — they occur during evaluation. A name describing a flow
cannot name a static entity.

```nix
# WRONG — module named after an action
home.modules.enableAutomaticBackups = { ... };

# RIGHT — module named after a noun, actions as options
home.modules.backups = {
  enable = true;
  automatic = true;
};
```

---

## Group Related Functions

Avoid single-function utility files. Group related functions into an
attrset namespace.

```nix
# WRONG — scattered files
# lib/parse-message.nix
# lib/validate-message.nix
# lib/serialize-message.nix

# RIGHT — one namespace
# lib/message.nix
{
  fromJSON = input: ...;
  isValid = msg: ...;
  toJSON = msg: ...;
}
```

---

## Standard Library Domain Rule

Any behavior in the semantic domain of an existing `lib` function must
use that function. Never reimplement `lib.recursiveUpdate`,
`lib.mapAttrs`, `lib.filterAttrs`, or other standard operations.

```nix
# WRONG — reimplementing deep merge
let merged = a // b // { nested = a.nested // b.nested; };

# RIGHT — using lib
lib.recursiveUpdate a b
```

---

## Direction Encodes Action

Same as Rust: `from*` implies construction, `to*` implies emission.
Verbs like `read`, `write`, `load`, `save` are forbidden when direction
conveys meaning.

```nix
# WRONG
{ readFromTOML = path: ...; }

# RIGHT
{ fromTOML = path: ...; }
```

---

## Construction Resolves to the Defining Attrset

Construction logic lives with the attrset it produces.

```nix
# WRONG — parser separated from the thing it parses
# parse.nix
{ parseConfig = input: lib.importTOML input; }

# RIGHT — constructor lives with the definition
# config.nix
{
  # ... config options
  fromTOML = input: lib.importTOML input;
}
```

---

## Single Attrset In, Single Attrset Out

All values crossing module or file boundaries are attrsets. Primitives
are for internal logic only. Functions accept one attrset argument.

```nix
# WRONG — positional arguments
lib.calculatePrice = basePrice: taxRate: basePrice * (1 + taxRate);

# RIGHT — self-documenting attrset
lib.calculatePrice = { basePrice, taxRate }: basePrice * (1 + taxRate);
```

---

## Flake Structure

Every Rust crate in the ecosystem has a flake with this structure:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    crane.url = "github:ipetkov/crane";
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Component sources use -src suffix, flake = false
    criome-cozo-src = { url = "github:LiGoldragon/criome-cozo"; flake = false; };
  };

  outputs = { ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        rustToolchain = fenix.packages.${system}.latest.toolchain;
        craneLib = (crane.mkLib pkgs).overrideToolchain rustToolchain;
      in {
        packages.default = craneLib.buildPackage { ... };
        devShells.default = craneLib.devShell { ... };
      }
    );
}
```

**Conventions:**
- `crane` for Rust builds, `fenix` for the toolchain — always
- `nixpkgs-unstable` — always (pinned via flake.lock)
- `-src` suffix for component source inputs, `flake = false`
- Path dependencies: `postUnpack` copies to sibling directories
- Custom source filters for `.cozo` files where needed
- Dev shell includes `rust-analyzer` at minimum

---

## No Store Paths

Nix store paths (`/nix/store/...`) never appear in generated config,
committed files, or user-facing output. Binaries are resolved via PATH.
The dev shell puts packages on PATH; config files reference command
names.

```nix
# WRONG — store path leaked into generated config
mcpConfig = builtins.toJSON {
  command = "${annas-archive}/bin/annas-archive";
};

# RIGHT — wrapper on PATH, config uses the command name
annas-archive-mcp = pkgs.writeShellScriptBin "annas-archive-mcp" ''
  exec annas-archive
'';

devShells.default = pkgs.mkShell {
  packages = [ annas-archive annas-archive-mcp ];
};

mcpConfig = builtins.toJSON {
  command = "annas-archive-mcp";
};
```

Store paths are an implementation detail of Nix's content-addressed
store. They are not stable identifiers — they change when inputs
change. Code and config reference names; Nix resolves names to paths.

---

## Credential Injection

Secrets (API keys, private keys) are injected at runtime via wrapper
scripts. They never appear in the Nix store, committed config, or
generated output.

```nix
pkgs.writeShellScriptBin "service-mcp" ''
  exec env \
    API_KEY="$(gopass show -o path/to/secret)" \
    service-binary
'';
```

The wrapper is on PATH via devShell. The MCP config references the
wrapper by name. The secret is fetched at process launch and exists
only in the child's environment — invisible to the Nix store, the
MCP client, and any logging harness.

---

## Documentation Protocol

Same as Rust: impersonal, timeless, precise. Document non-boilerplate
behavior. Comments explain *why*, not *what*.

```nix
/*
  Timeout is 901s — upstream has a 900s timeout but under load
  takes up to 1s extra to close. Prevents intermittent race.
*/
networking.timeout = 901;
```
