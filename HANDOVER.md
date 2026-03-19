# Mentci — Harness Handover

This document is a dirty-worktree signal for the next Claude session.
It summarizes the current state of the Mentci v1 multi-repo ecosystem
and what needs to happen next.

## What Mentci Is

Mentci is a two-agent system where all intelligence flows through datalog.
Two agents — Samskara and Lojix — never interact directly. They communicate
exclusively through shared CozoDB relation schemas. Each agent owns its own
database. There is no RPC, no message bus, no shared state beyond the
contract surface.

**Samskara** is the pure datalog agent. It reasons only in relations. It has
no concept of files, code, or an operating system. Its ontological categories
come from astrological category theory (Solar/Lunar polarity, the
2→3→7→12→36→72→360 subdivision chain).

**Lojix** is the transpiling agent. It reads a Rust-capabilities-matching
datalog DSL (marked `live = true`), transpiles it to executable code
(TypeScript in phase 1, Rust in phase 2), executes it, and translates
results back into datalog before Samskara ever sees them.

## Repo Map

All repos live as siblings in `~/git/`. This repo (`Mentci`) is the
workspace root — it provides the Nix flake dev shell and architecture docs,
but contains no application code.

```
~/git/
├── Mentci/                        ← THIS REPO (workspace, flake, docs)
├── criome-cozo/                   ← CozoDB wrapper crate (leaf dependency)
│   github: LiGoldragon/criome-cozo
│   branch: main
│
├── samskara-lojix-contract/       ← Shared relation schemas between agents
│   github: LiGoldragon/samskara-lojix-contract
│   branch: main
│   depends on: criome-cozo (path)
│
├── samskara/                      ← Pure datalog agent
│   github: LiGoldragon/samskara
│   branch: v1
│   depends on: criome-cozo, samskara-lojix-contract (path)
│   tests: 5 (CommitType inference + roundtrip)
│
└── lojix/                         ← DSL transpiler
    github: sajban/lojix (redirects to Criome/lojix)
    branch: v1
    depends on: criome-cozo, samskara-lojix-contract (path)
    tests: 0 (transpile logic is stub)
```

## Dependency Graph

```
criome-cozo (leaf — no external path deps)
    ↑
samskara-lojix-contract (contract schemas + init)
    ↑
samskara ←──────── (both depend on contract + cozo)
lojix   ←────────
```

## How Builds Work

**Local dev**: All Cargo.toml files use `path = "../<dep>"`. Repos must be
siblings in `~/git/` for this to work.

**Nix flake builds**: Each repo's `flake.nix` fetches dependency repos as
`flake = false` inputs from GitHub. A `postUnpack` hook places them as
sibling directories so cargo's path deps resolve inside the nix sandbox.
Source filters include `.cozo` files (needed by `include_str!`).

```sh
# Test any repo through nix:
cd ~/git/criome-cozo && nix flake check
cd ~/git/samskara-lojix-contract && nix flake check
cd ~/git/samskara && nix flake check
cd ~/git/lojix && nix flake check
```

All four repos pass `nix flake check` as of this handover.

## VCS

**Jujutsu (jj) is mandatory.** Git is backend-only storage. Never use git
commands directly except for `git remote` operations.

```sh
jj status                    # see changes
jj describe -m "message"     # set commit description
jj new                       # start new change
jj bookmark set <name> -r @  # point bookmark at current change
jj git push --bookmark <name> # push to remote
```

## Current State

### What exists and works:
- `criome-cozo`: CozoDB wrapper (`open_memory`, `open_sqlite`, `run_script`,
  `load_file`, `is_live`). Uses `cozo-ce v0.7.13-alpha.3` with
  `storage-sqlite`. Pins `rayon = "=1.10.0"` for compatibility.
- `samskara-lojix-contract`: Three contract relations (`transpiler_version`,
  `eval_request`, `eval_result`). CozoScript generation. `init()` function
  that creates relations in a given CozoDB.
- `samskara`: CLI that opens CozoDB, loads contract + internal relations
  (intent, policy, evidence, decision, agent_role, commit, etc.).
  **jj-mirror** module: `CommitType` enum (12 variants), commit/diff
  fetching from jj, storage in CozoDB relations.
- `lojix`: CLI that opens CozoDB, loads contract + internal relations
  (lojix_source, transpile_log, type_def, trait_def). Registers transpiler
  version. Has `TranspileContext` with stubs for `query_live_source()`,
  `transpile_to_typescript()`, `write_eval_result()`.

### What doesn't exist yet:
- Actual transpile logic in Lojix (currently stubs)
- Any DSL source relations to transpile
- Inter-agent communication flow (contract relations are defined but
  no agent reads from / writes to the other's outputs yet)
- Integration tests that exercise the full Samskara → contract → Lojix loop
- The Mentci workspace flake does not build/test components — it only
  provides a dev shell. Individual repos own their own builds.

## Key Technical Details

- **CozoDB API**: `run_script()` returns `serde_json::Value`. Params must be
  `BTreeMap<String, DataValue>`. CozoScript `:create` statements must be
  executed one at a time (use `split_cozo_statements()` to split on blank lines).
- **include_str!**: All three downstream repos use `include_str!("../AI-init.cozo")`
  to embed their init scripts at compile time.
- **Rust edition 2024** across all crates.
- **Criome patterns**: Single object in/out, logic-data separation,
  actor-first concurrency (see `Core/RUST_PATTERNS.md`).

## Principles (non-negotiable)

1. Samskara NEVER sees files, code, or the OS — only relations
2. Each agent owns its own CozoDB — no shared database access
3. Communication is ONLY through contract relations
4. Jujutsu for VCS, Nix for builds, Rust for code — no exceptions
5. Micro-repo style: each concern is its own repo, contracts too
6. The `live` boolean on DSL relations determines what Lojix executes
