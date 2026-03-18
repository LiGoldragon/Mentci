# Sema Object Style — Rust

This document defines the mandatory Sema object rules for Rust in Mentci v1.
The rules are structural. Violations indicate category error, not style.

---

## The Stack

```
Human (the psyche — sovereign, local, never broadcast)
  ↕
Mentci (renders Sema into something humans can work with)
  samskara — pure datalog agent, reasons about the world model
  lojix    — transpiler, translates between human DSL and Sema
  ↕
Criome (the cryptographic biome — components communicating via Sema)
  contract relations are the only inter-component surface
  every component owns its CozoDB instance — no shared state
  ↕
Sema (the symbolic machine language — fully logical, machine-readable)
  self-describing symbolic objects — data IS the database
  correctness IS security — trust attaches to meaning, not transport
  Cap'n Proto v1 is the binary encoding
  ↕
CriomOS (the runtime substrate — Nix-built, Linux-hosted)
```

Rust implements the Criome and Mentci layers. Sema defines what they compute.
CriomOS provides the ground they stand on. The human is the reason they exist.

---

## Ontological Foundation

### The Subdivision Chain: 2 → 3 → 5 → 7 → 12

Every problem can be decomposed by asking how many distinctions it requires.
The chain provides the natural stopping points:

| N | Question it answers | Mentci manifestation |
|---|---------------------|---------------------|
| **2** | Is it A or B? | Sol/Luna polarity. Owner/borrower. Key/value. True/false. Computers know this intrinsically. |
| **3** | What was, is, will be? | Sol/Luna/Saturn — the planetary tri-state. The minimal structure for time. Every system decomposes into foundation/change/crystallization. |
| **5** | What are its qualities? | The 5 dignities (eternal/proven/seen/uncertain/delusion). The 5 Platonic solids. The prime that completes the circle: 360 = 72 × **5**. Without 5, the circle cannot close. |
| **7** | What are the actors? | The 7 classical planets. The exceptional prime — the only one in the chain that does not divide 360. Like the octonions breaking associativity, 7 introduces irreducible complexity. |
| **12** | What are the categories? | Z/12Z — the zodiac. Its subgroup lattice generates all aspects (opposition=2, trine=3, square=4, sextile=6). The meeting point of binary and ternary structure. |

Beyond 12: **36** (decanates), **72** (quintiles, φ(72)=24 links to the Leech
lattice), **360** (|A₆|, the simple group whose 24 divisors encode the full
chain). These are derivations, not primitives.

### The Vesica Piscis — The Contract-Repo Pattern

Two circles, each centered on the other's circumference, produce the vesica
piscis: the almond-shaped intersection. Categorically, this is the **pullback** —
the maximal shared subobject that maps into both domains.

This is the fundamental design pattern of the Criome:

```
When a distinct logic plane emerges:
  1. It becomes its own component (circle, repo, CozoDB instance)
  2. Its communication with other components is a contract repo (vesica piscis)
  3. The contract contains ONLY shared relation schemas
  4. No other coupling exists — no shared state, no function calls, no imports
```

**This enforces async/actor/agent architecture by construction.** There is no
function call between components — only datalog relations crossing the contract
boundary. Tight coupling is structurally impossible.

The pattern is recursive: if a component grows a new internal logic plane, that
plane splits out. The system grows by cell division, not accretion. The contract
repo is the cell membrane — specific molecules (relation schemas) cross it,
everything else stays inside.

Current instantiation:
```
criome-cozo (leaf — shared CozoDB wrapper)
     ↑
samskara-lojix-contract (vesica piscis)
     ↑              ↑
samskara          lojix
     ↑
samskara-codegen (build-time codegen, not runtime contract)
```

### The Kronos Guarantee

Saturn (Kronos) swallowed his children whole. They were not destroyed — they were
archived. Zeus forced Kronos to disgorge them, and they emerged intact.

This is the VCS invariant: **Saturn preserves perfectly.** Every `world_snapshot`
is a complete, recoverable state. `restore_to_commit` (pratiṣṭhā) is the Kronos
disgorge. What enters the archive can be recovered without loss.

---

## Source of Truth

Samskara (saṃskāra: impression, mental formation) is the pure datalog agent
backed by CozoDB. It is the single source of truth for all type definitions,
ownership topology, and actor protocols within Mentci.

Rust code is *derived* from samskara relations — either generated at build time
(via samskara-codegen → Cap'n Proto → Rust types) or hand-written to match the
relational schema.

The specification lives in stored relations. The code implements the specification.
When they disagree, the relations are authoritative.

Sema defines the symbolic objects. Samskara stores and reasons about them.
Cap'n Proto encodes them for transport. Rust executes them.

---

## Primary Rules

### 1. Schema Is Samskara

Every transmissible type corresponds to a stored relation. The relation schema
(`::columns`) defines the type's fields, key structure, and column types. Rust
structs are projections of these relations.

Enum types are PascalCase relations with a single String key column (e.g.,
`Phase`, `Dignity`, `CommitType`). The relation rows ARE the enum variants.

Wire encodings (Cap'n Proto) and storage formats (zstd, base64) are transport
concerns. They do not define the domain — samskara does. Schema is Sema;
encoding is incidental.

### 2. Object–Verb–Subject

Every samskara relation is an OVS triple. The verb encodes ownership semantics:

| Verb | Relation pattern | Rust output |
|------|-----------------|-------------|
| **has** (own) | `GameRoom has players: Player` | `players: Vec<Player>` — owned field |
| **has** (val) | `Thought has title: String` | `title: String` — copy/value field |
| **accepts** | `GameRoom accepts Join` | `enum GameRoomMessage { Join { ... } }` |
| **carries** (move) | `Join carries player: Player` | field in enum variant, moved |
| **does** (read) | `Player does name() → String` | `fn name(&self) -> &str` |
| **does** (write) | `Player does set_score()` | `fn set_score(&mut self, ...)` |
| **does** (consume) | `Round does finish() → Summary` | `fn finish(self) -> Summary` |
| **spawns** | `GameRoom spawns RoundActor` | child actor handle |

The verb determines the Rust ownership pattern. No lifetimes to reason about —
the datalog relation specifies the ownership mode.

### 3. Single Object In/Out

Every method accepts at most one explicit object argument and returns exactly one
object. When multiple inputs or outputs are required, define a new object.
All values crossing component boundaries are Sema objects; primitives are internal
only.

```rust
impl CommitResult {
    pub fn from_input(input: CommitInput) -> Result<Self, VcsError> {
        // ...
    }
}
```

### 4. Everything Is an Object

Reusable behavior belongs to named types or traits. Free functions exist only as
orchestration shells in `main.rs`.

Test helpers are methods on a test fixture struct. Utility functions that operate
on data belong to the struct that owns that data.

### 5. Single Owner

Every object has exactly one owner. This is the actor model meeting Rust's borrow
checker — the same principle at two levels:

- **Relational level**: The `phase` column encodes lifecycle. Only `sol`-phase
  rows participate in the world hash. Ownership transfers (luna→sol→saturnus)
  are explicit commit operations (saṅkalpa).

- **Rust level**: Move semantics. No `Arc<Mutex<T>>` for domain state. Actors
  own their state exclusively and communicate via typed messages.

### 6. Logic-Data Separation

Implementation files must not contain hardcoded paths, regexes, or numeric
constants. All such data must be:

- Stored in samskara relations (queryable, versionable)
- Loaded from `.cozo` schema/seed files
- Passed via typed message structs

Enum relations replace hardcoded string constants. Instead of
`if status == "approved"`, the valid values live in a `Status` relation.

---

## Phase and Dignity

All versioned relations carry `phase: String` and `dignity: String` columns.

### Phase — the planetary tri-state (avasthā)

The lifecycle of every fact follows the three celestial bodies that define the
visible cosmos:

| Phase | Glyph | Speed | Role | In world hash |
|-------|-------|-------|------|---------------|
| `sol` | ☉ | 1°/day | Manifest — committed truth | **Yes** |
| `luna` | ☽ | 13°/day | Becoming — staged, proposed | No |
| `saturnus` | ♄ | 0.03°/day | Archived — in the ledger | No |

Luna moves fastest — the staging area churns. Sol moves steadily — the manifest
world changes once per commit. Saturn barely moves — the archive is near-permanent.

**Commit** (saṅkalpa) is the Luna→Sol conjunction: staged facts become manifest.
**Supersede** is the Sol→Saturn transit: old truth passes the boundary.
**Restore** (pratiṣṭhā) is Saturn's disgorge: archived state returns to Sol's light.

### Dignity — the epistemological hierarchy (gaurava)

The trust level of a fact, independent of its lifecycle position. Drawn from the
Vedic epistemological tradition:

| Dignity | Saṃskṛta | Rank | Meaning |
|---------|----------|------|---------|
| `eternal` | nitya | 0 | Immutable, always-true, foundational invariant |
| `proven` | siddha | 1 | Accomplished, verified through trusted source |
| `seen` | dṛṣṭa | 2 | Witnessed, observed — default for new assertions |
| `uncertain` | sandeha | 3 | Doubt, unverified claim |
| `delusion` | bhrama | 4 | Error, mistaking rope for snake |

Phase and dignity are orthogonal. An `eternal`-dignity fact can be archived
(Śiva dissolves even the highest truths when the age turns). A `delusion`-dignity
fact can be manifest (it is the current state of knowledge, even if unreliable).

The Saṃskṛta equivalents are stored as data in the `samskrta` relation —
queryable relations of their own, not embedded in description strings.

---

## Actor-First Concurrency

All multi-step transformations, long-running orchestrations, and concurrent
executions are implemented as supervised actors.

1. **Typed Messages**: Communication between actors occurs via typed message
   enums defined as Sema Objects, mirroring `accepts`/`carries` relations.
2. **Supervision Trees**: Any actor spawning a sub-task supervises its lifecycle
   (the Russian Doll model — fractal recursion of responsibility).
3. **State Sovereignty**: An actor's internal state is private, modifiable only
   via its message handlers. The actor IS the single owner.
4. **MCP as Actor Interface**: MCP tools are the external interface to samskara's
   actor. Each tool maps to a message the actor handles.
5. **Contract as Membrane**: Inter-component communication is exclusively through
   contract relations. This is the vesica piscis pattern at runtime.

---

## Naming and Ontology

- `PascalCase` denotes objects (types, traits, enum relations).
- `snake_case` denotes flow (methods, fields, data relations).
- A PascalCase relation name in CozoDB → enum type in Rust.
- A snake_case relation name in CozoDB → struct type in Rust (PascalCase'd).
- Avoid suffixes that restate objecthood (`Object`, `Type`, `Entity`, `Model`).

The capitalization convention mirrors the filesystem durability tiers:
`ALL_CAPS` = supreme law (never edited by agents), `PascalCase` = stable contract
(edited only by mandate), `lowercase` = mutable implementation (freely editable).

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

---

## Transport and Storage

Cap'n Proto is Sema's binary encoding — the wire format for symbolic objects.
It is generated deterministically from samskara relations at build time via
`samskara-codegen`. The generated types provide zero-copy Reader/Builder access.

The storage pipeline for world snapshots:
```
samskara rows → JSON → zstd → base64 → CozoDB String column
```

Phase 2 upgrades to:
```
samskara rows → Cap'n Proto packed → zstd → base64 → CozoDB String column
```

Both coexist via `reader_version` in `archive_reader_version`. Content addressing
uses BLAKE3 throughout. Correctness is security — the hash IS the identity.

---

## The Three Subsystems

Every significant system in Mentci decomposes into three — the trinity pattern
derived from the 2→3 transition:

| Subsystem | Role | Planetary analogy |
|-----------|------|-------------------|
| **Foundation** (schema, relations, seed data) | What exists | ☉ Sol — the manifest |
| **VCS** (snapshot, delta, commit, restore) | What changes | ☽ Luna — the becoming |
| **Codegen** (samskara-codegen, capnp, types) | What endures | ♄ Saturn — the crystallized |

---

## Documentation Protocol

Documentation is impersonal, timeless, and precise. Document only non-boilerplate
behavior. Comments are mandatory only when the "why" cannot be structural.
Self-documenting code is preferred over comments.
