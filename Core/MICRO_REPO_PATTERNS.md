<!-- SUPERSEDED: This document is now a read-only projection of samskara
     relations. The authoritative source is the `rule` relation in samskara's
     world.db. To query: ?[id, body, rationale] := *rule{id, body, rationale,
     microtheory: "micro-repo"} -->

# Micro-Repo Patterns

Every concern lives in its own repository. Contracts between components
are also their own repos. This workspace aggregates them via Nix flake
inputs.

---

## When to Create a New Repo

A new repo when a **distinct logic plane** emerges and requires
**async coupling** with the rest of the system.

| Signal | Example | Action |
|--------|---------|--------|
| New runtime process | annas-archive MCP server | New repo |
| New CozoDB instance | samskara's world, lojix's eval | New repo |
| Shared boundary between two components | samskara ↔ lojix | Contract repo |
| Build-time artifact generator | samskara-codegen | New repo |
| Shared library with no runtime state | criome-cozo | New repo |
| Module within a component | samskara/vcs | Stay as module |
| Temporary exploration | Drafts/ | Stay as file |

**When NOT to split:** A module that shares the same CozoDB instance,
the same async runtime, and the same ownership boundary as its parent
stays as a module. It splits only when it develops its own logic plane
distinct from the parent's reasoning.

---

## Build-Time vs Runtime Dependencies

**Build-time** dependencies produce artifacts baked into the binary
(Cap'n Proto schemas, generated Rust types). They arrive via
`[build-dependencies]` in Cargo.toml and flake inputs. They do not
need runtime contracts.

**Runtime** dependencies communicate through contract relations. Each
side owns its own CozoDB instance. No shared state, no function calls,
no imports across the boundary — only datalog relations.

---

## Contract Repos

A contract is a **two-pointed arrow** between two components. It exists
as its own repo, owned by neither side.

```
criome-cozo (leaf — shared wrapper)
     ↑
samskara-lojix-contract (the arrow)
     ↑              ↑
samskara          lojix
```

The contract repo contains **only** shared relation schemas. No logic,
no types, no functions beyond schema initialization.

---

## Flake Input Conventions

Component sources are declared as flake inputs with a `-src` suffix
and `flake = false`:

```nix
inputs = {
  criome-cozo-src = { url = "github:LiGoldragon/criome-cozo"; flake = false; };
  samskara-src = { url = "github:LiGoldragon/samskara"; flake = false; };
};
```

Path dependencies in Cargo.toml use relative sibling paths (`../crate`).
For Nix builds, `postUnpack` copies flake inputs to the expected sibling
positions:

```nix
postUnpack = ''
  depDir=$(dirname $sourceRoot)
  cp -rL ${criome-cozo-src} $depDir/criome-cozo
'';
```

---

## Naming

Repository names are `kebab-case`. Crate names match the repo name.
Contract repos are named `{component-a}-{component-b}-contract`.
