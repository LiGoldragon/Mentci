# Sema Object Style — Rust

This document defines the mandatory Sema object rules for Rust in Mentci v1.
The rules are structural. Violations indicate category error, not style.

## Source of Truth

Samskara (the pure datalog agent backed by CozoDB) is the single source of truth
for all type definitions, ownership topology, and actor protocols. Rust code is
*derived* from samskara relations — either generated (via samskara-codegen) or
hand-written to match the relational schema.

The specification lives in stored relations. The code implements the specification.
When they disagree, the relations are authoritative.

## Primary Rules

### 1. Schema Is Samskara

Every transmissible type corresponds to a stored relation. The relation schema
(`::columns`) defines the type's fields, key structure, and column types. Rust
structs are projections of these relations.

Enum types are relations whose name is PascalCase with a single String key column
(e.g., `Phase`, `Dignity`, `CommitType`). The relation rows ARE the enum variants.

Wire encodings (Cap'n Proto) and storage formats (zstd, base64) are transport
concerns. They do not define the domain — samskara does.

### 2. Single Object In/Out

Every method accepts at most one explicit object argument and returns exactly one
object. When multiple inputs or outputs are required, define a new object.

```rust
struct CommitInput {
    db: CriomeDb,
    message: String,
    agent_id: String,
}

struct CommitResult {
    world_hash: String,
    parent_id: String,
    snapshot_taken: bool,
}

impl CommitResult {
    pub fn from_input(input: CommitInput) -> Result<Self, VcsError> {
        // ...
    }
}
```

### 3. Everything Is an Object

Reusable behavior belongs to named types or traits. Free functions exist only as
orchestration shells in `main.rs`.

Test helpers are methods on a test fixture struct. Utility functions that operate
on data belong to the struct that owns that data.

### 4. Single Owner (Actor Model)

Every object has exactly one owner. This is enforced at two levels:

- **Relational level**: The `phase` column encodes lifecycle. Only `sol`-phase
  rows participate in the world hash. Ownership transfers (luna→sol→saturnus)
  are explicit commit operations.

- **Rust level**: Move semantics. No `Arc<Mutex<T>>` for domain state. Actors
  own their state exclusively and communicate via typed messages.

The OVS (Object–Verb–Subject) pattern in samskara relations maps directly to
Rust ownership: `has` with `hold: "own"` → owned field (`T`), `accepts` →
message enum variant, `spawns` → child actor handle.

### 5. Logic-Data Separation

Implementation files must not contain hardcoded paths, regexes, or numeric
constants. All such data must be:

- Stored in samskara relations (queryable, versionable)
- Loaded from `.cozo` schema/seed files
- Passed via typed message structs

Vocabulary relations (PascalCase enums) replace hardcoded string constants.
Instead of `if status == "approved"`, the valid values live in a relation.

### 6. Phase-Aware State

All versioned relations carry `phase: String` and `dignity: String` columns.

**Phase** (lifecycle — the planetary tri-state):

| Phase | Saṃskṛta | Meaning | In world hash |
|-------|----------|---------|---------------|
| `sol` | — | ☉ Manifest — committed truth | Yes |
| `luna` | — | ☽ Becoming — staged, proposed | No |
| `saturnus` | — | ♄ Archived — superseded | No |

**Dignity** (trust level — epistemological hierarchy):

| Dignity | Saṃskṛta | Meaning |
|---------|----------|---------|
| `eternal` | nitya | Immutable, always-true, foundational invariant |
| `proven` | siddha | Accomplished, verified through trusted source |
| `seen` | dṛṣṭa | Witnessed, observed (default for new assertions) |
| `uncertain` | sandeha | Doubt, unverified claim |
| `delusion` | bhrama | Error, mistaking rope for snake |

New assertions default to `phase: "luna"`, `dignity: "seen"`. The `commit_world`
operation promotes luna→sol. Supersession moves sol→saturnus. Restore moves
saturnus→sol.

## Actor-First Concurrency

All multi-step transformations, long-running orchestrations, and concurrent
executions are implemented as supervised actors.

1. **Typed Messages**: Communication between actors occurs via typed message
   enums defined as Sema Objects, mirroring `accepts`/`carries` relations.
2. **Supervision Trees**: Any actor spawning a sub-task supervises its lifecycle.
3. **State Sovereignty**: An actor's internal state is private, modifiable only
   via its message handlers. The actor IS the single owner.
4. **MCP as Actor Interface**: MCP tools are the external interface to samskara's
   actor. Each tool maps to a message the actor handles.

## Naming and Ontology

- `PascalCase` denotes objects (types, traits, enum relations).
- `snake_case` denotes flow (methods, fields, data relations).
- A PascalCase relation name in CozoDB → enum type in Rust.
- A snake_case relation name in CozoDB → struct type in Rust (PascalCase'd).
- Avoid suffixes that restate objecthood (`Object`, `Type`, `Entity`, `Model`).

## Trait-Domain Rule

Any behavior in the semantic domain of an existing trait must be expressed as a
trait implementation. Inherent methods are not used to bypass trait domains.

```rust
use core::str::FromStr;

impl FromStr for Phase {
    type Err = ParsePhaseError;

    fn from_str(input: &str) -> Result<Self, Self::Err> {
        match input {
            "sol" => Ok(Phase::Sol),
            "luna" => Ok(Phase::Luna),
            "saturnus" => Ok(Phase::Saturnus),
            _ => Err(ParsePhaseError(input.to_string())),
        }
    }
}
```

## Direction Encodes Action

Prefer `from_*`, `to_*`, `into_*`. Avoid verbs like `read`, `write`, `load`,
`save` when direction already conveys meaning.

| Pattern | Meaning |
|---------|---------|
| `from_db` | Construct by introspecting CozoDB |
| `from_columns_result` | Construct from `::columns` output |
| `to_capnp_text` | Emit as Cap'n Proto schema text |
| `into_commit` | Consume self to produce a commit |

## Transport and Storage

Cap'n Proto is the binary transport and storage format. It is generated
deterministically from samskara relations at build time via `samskara-codegen`.
The generated types provide zero-copy Reader/Builder access.

The storage pipeline for world snapshots:
```
samskara rows → JSON → zstd → base64 → CozoDB String column
```

Phase 2 upgrades to:
```
samskara rows → Cap'n Proto packed → zstd → base64 → CozoDB String column
```

Both coexist via `reader_version` in `archive_reader_version`. Content addressing
uses BLAKE3 throughout.

## Documentation Protocol

Documentation is impersonal, timeless, and precise. Document only non-boilerplate
behavior. Comments are mandatory only when the "why" cannot be structural.
