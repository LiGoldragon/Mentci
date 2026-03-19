# Sema Rust Patterns

These are the structural patterns of Rust in Mentci v1. They are not
conventions to follow — they are the architecture itself. A deviation
indicates a category error, not a style disagreement.

---

## Sema, Criome, Mentci

**Sema** is the symbolic machine language. Fully logical, machine-readable,
self-describing. Data IS the database — every object carries its own semantic
context. Correctness IS security — trust attaches to meaning, not transport.
Sema rarely changes; when it does, it is by expert consensus through the Criome.

Sema v1's binary encoding is Cap'n Proto — the birth canal, not the permanent
form. The first Sema is specified by the capnp output of its own relational
specification (generated from samskara via samskara-codegen). Then Sema rebuilds
its next version using itself, and logs v1 in Kronos (Saturn's ledger —
`archive_reader_version`). Once Sema can describe itself in its own format,
Cap'n Proto becomes historical — archived, readable, but no longer the live
encoding.

**Criome** is the cryptographic biome — the totality of all relationships
running on Sema. Components, contracts, quorums, alliances, truces, obstacles.
The Criome is not a fixed architecture; it is a shifting, living graph of
ownership and trust. Most of it is not owned by any single psyche. It is the
emergent structure of all contracts composed. The Criome can become a source
of authority for Sema itself — by expert agreement to update the format.

**CriomOS** is the Linux-based operating system runtime that hosts the Criome.
Nix-built, reproducible, hermetic. The substrate.

**Mentci** is one psyche-cluster's local tool for participating in the Criome.
It renders Sema for its human. Mentci is a participant *inside* the Criome,
not above it. Mentci and the Criome run on the same Sema — they are the same
fabric viewed from two perspectives: local psyche vs global biome.

```
Sema (the universal format — constant, authoritative)
  │
  └── Criome (the totality — all relationships running on Sema)
        │
        ├── Mentci (one psyche's local participant)
        │     samskara — pure datalog agent, reasons about the world model
        │     lojix    — transpiler, translates between human DSL and Sema
        │
        ├── other psyche-clusters...
        │
        └── quorum contracts governing shared boundaries

CriomOS (the runtime substrate — Nix-built, Linux-hosted)
```

Rust implements the Criome components and Mentci. Sema defines what they
compute. CriomOS provides the ground they stand on. The human is the reason
they exist. The psyche is sovereign.

---

## Ontological Foundation

### The Subdivision Chain: 2 → 3 → 5 → 7 → 12

Every problem can be decomposed by asking how many distinctions it requires.
The chain provides the natural stopping points:

| N | Question | Mentci manifestation |
|---|----------|---------------------|
| **2** | A or B? | Sol/Luna polarity. Owner/borrower. Key/value. Computers know this intrinsically. |
| **3** | What was, is, will be? | Sol/Luna/Saturn — the planetary tri-state. The minimal structure for time. Every system decomposes into foundation / change / crystallization. |
| **5** | What are its qualities? | The 5 dignities (eternal/proven/seen/uncertain/delusion). The 5 Platonic solids. The golden ratio prime: φ = (1+√5)/2. |
| **7** | What are the actors? | The 7 classical planets. The exceptional prime — the only one that does not divide 360. Like the octonions breaking associativity, 7 introduces irreducible complexity. |
| **12** | What are the categories? | Z/12Z — the zodiac. Its subgroup lattice generates all aspects (opposition=2, trine=3, square=4, sextile=6). The meeting point of binary and ternary structure. |

Without 5, the circle cannot close: 360 = 72 × **5**. The number 72 (= 2³×3²)
gives you all the structure that 2 and 3 can produce. But 5 completes the circle.
It is the prime of self-similar proportion — the pentagon's diagonals create the
golden ratio, and the Criome grows by self-similar cell division.

Beyond 12: **36** (decanates), **72** (quintiles, φ(72)=24), **360** (|A₆|,
the simple group whose 24 divisors encode the full chain). Derivations, not
primitives.

### The Contract Pattern

The fundamental design pattern of the Criome:

```
When a distinct logic plane emerges:
  1. It becomes its own component (repo, CozoDB instance, actor)
  2. It communicates with other components through a contract
  3. The contract contains ONLY shared relation schemas
  4. No other coupling — no shared state, no function calls, no imports
```

**This architecturally enforces async/actor/agent design.** There is no
function call between components — only datalog relations crossing the
contract boundary.

A contract is a **two-pointed arrow** between two components. It points into
both domains. Neither side owns the arrow — it exists between them as its own
entity with its own owner and its own position in the Criome.

The contract owner controls the membrane. Many critical contracts are owned by
**quorum contracts** — threshold agreements where N-of-M parties must sign to
modify the schema. This is where the cryptographic part of the Criome becomes
concrete: multi-signature, content-addressed, enforced by Sema's correctness
guarantees. Phase + dignity + multi-agent commits provide the machinery:
a relation moves from luna to sol only when the quorum threshold is met.

The pattern is recursive. If a component grows a new internal logic plane,
that plane splits out. If two contracts need to coordinate, their coordination
is itself a contract. The Criome is contracts all the way up — an arbitrarily
complex graph where every edge is itself a node that can have edges.

**Build-time dependencies** are a separate category. `samskara-codegen` is
consumed at compile time, not at runtime — it produces artifacts (capnp
schemas, Rust types) that are baked into the binary. Build-time deps do not
need runtime contracts.

Current instantiation:
```
criome-cozo (leaf — shared CozoDB wrapper)
     ↑
samskara-lojix-contract (owned entity — the two-pointed arrow)
     ↑              ↑
samskara          lojix
     ↑
samskara-codegen (build-time — produces Sema v1 artifacts)
```

### The Kronos Guarantee

Saturn (Kronos) swallowed his children whole. They were not destroyed — they
were archived. Zeus forced Kronos to disgorge them, and they emerged intact.

This is the VCS invariant: **Saturn preserves perfectly.** Every
`world_snapshot` is a complete, recoverable state. `restore_to_commit`
(pratiṣṭhā) is the Kronos disgorge. What enters the archive can be recovered
without loss.

The genesis bootstrap follows the same myth: Sema v1 is born, then archived
in `archive_reader_version`. Every subsequent Sema version is logged in
Kronos. The full lineage of the format itself is recoverable — from capnp
birth canal to native self-description.

---

## Source of Truth

Samskara (saṃskāra: impression, mental formation) is the pure datalog agent
backed by CozoDB. It is the single source of truth for all type definitions,
ownership topology, and actor protocols within Mentci.

Rust code is *derived* from samskara relations — either generated at build
time (via samskara-codegen → Cap'n Proto → Rust types) or hand-written to
match the relational schema.

The specification lives in stored relations. The code implements the
specification. When they disagree, the relations are authoritative.

Sema defines the symbolic objects. Samskara stores and reasons about them.
Cap'n Proto encodes them for transport (v1). Rust executes them.

---

## Primary Patterns

### 1. Schema Is Samskara

Every transmissible type corresponds to a stored relation. The relation schema
(`::columns`) defines the type's fields, key structure, and column types. Rust
structs are projections of these relations.

Enum types are PascalCase relations with a single String key column (e.g.,
`Phase`, `Dignity`, `CommitType`). The relation rows ARE the enum variants.

Wire encodings and storage formats are transport concerns. They do not define
the domain — samskara does. Schema is Sema; encoding is incidental.

### 2. Object–Verb–Subject

Every samskara relation is an OVS triple. The verb encodes ownership semantics.

**Ownership verbs** (how a type holds its referents):

| Verb | Relation pattern | Rust output |
|------|-----------------|-------------|
| **has** (own) | `GameRoom has players: Player` | `players: Vec<Player>` — owned field |
| **has** (val) | `Thought has title: String` | `title: String` — copy/value field |
| **spawns** | `GameRoom spawns RoundActor` | child actor handle |

**Protocol verbs** (how actors communicate):

| Verb | Relation pattern | Rust output |
|------|-----------------|-------------|
| **accepts** | `GameRoom accepts Join` | `enum GameRoomMessage { Join { ... } }` |
| **carries** (move) | `Join carries player: Player` | field in enum variant, moved |
| **contracts** | `samskara contracts lojix via thought` | no direct Rust coupling — async relations only |

**Behavior verbs** (how objects act):

| Verb | Relation pattern | Rust output |
|------|-----------------|-------------|
| **does** (read) | `Player does name() → String` | `fn name(&self) -> &str` |
| **does** (write) | `Player does set_score()` | `fn set_score(&mut self, ...)` |
| **does** (consume) | `Round does finish() → Summary` | `fn finish(self) -> Summary` |

The verb determines the Rust ownership pattern. No lifetimes to reason about —
the datalog relation specifies the ownership mode. The `contracts` verb
produces no Rust coupling by design — it is the two-pointed arrow between
separate CozoDB instances.

### 3. Single Object In/Out

Every method accepts at most one explicit object argument and returns exactly
one object. When multiple inputs or outputs are required, define a new object.
All values crossing component boundaries are Sema objects; primitives are
internal only.

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

### 4. Everything Is an Object

Reusable behavior belongs to named types or traits. Free functions exist only
as orchestration shells in `main.rs`.

Test helpers are methods on a test fixture struct. Utility functions that
operate on data belong to the struct that owns that data.

### 5. Single Owner

Every object has exactly one owner. This is the actor model meeting Rust's
borrow checker — the same principle at two levels:

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

The lifecycle of every fact follows the three celestial bodies that define
the visible cosmos:

| Phase | Glyph | Speed | Role | In world hash |
|-------|-------|-------|------|---------------|
| `sol` | ☉ | 1°/day | Manifest — committed truth | **Yes** |
| `luna` | ☽ | 13°/day | Becoming — staged, proposed | No |
| `saturnus` | ♄ | 0.03°/day | Archived — in the ledger | No |

Luna moves fastest — the staging area churns. Sol moves steadily — the
manifest world changes once per commit. Saturn barely moves — the archive
is near-permanent.

**Commit** (saṅkalpa) is the Luna→Sol conjunction: staged facts become
manifest. **Supersede** is the Sol→Saturn transit: old truth passes the
boundary. **Restore** (pratiṣṭhā) is Saturn's disgorge: archived state
returns to Sol's light.

### Dignity — the epistemological hierarchy (gaurava)

The trust level of a fact, independent of its lifecycle position. Drawn
from the Vedic epistemological tradition:

| Dignity | Saṃskṛta | Rank | Meaning |
|---------|----------|------|---------|
| `eternal` | nitya | 0 | Immutable, always-true, foundational invariant |
| `proven` | siddha | 1 | Accomplished, verified through trusted source |
| `seen` | dṛṣṭa | 2 | Witnessed, observed — default for new assertions |
| `uncertain` | sandeha | 3 | Doubt, unverified claim |
| `delusion` | bhrama | 4 | Error, mistaking rope for snake |

Phase and dignity are orthogonal. An `eternal`-dignity fact can be archived
(Śiva dissolves even the highest truths when the age turns). A
`delusion`-dignity fact can be manifest (it is the current state of knowledge,
even if unreliable).

The Saṃskṛta equivalents are stored as data in the `samskrta` relation —
queryable relations of their own, not embedded in description strings.

---

## The Actor Pattern

All multi-step transformations, long-running orchestrations, and concurrent
executions are implemented as supervised actors. The actor is the Rust
manifestation of the learning cycle — the same four-phase pattern that
governs the cardinal signs and position derivatives.

### The Actor as Learning Cycle

An actor processes messages through four phases that mirror the cardinal
signs and their measure formulae (*Science & Astrology*, pp. 9-11):

| Phase | Cardinal sign | Measure | Actor operation |
|-------|--------------|---------|-----------------|
| 1. Stimulus arrives | **Aries** (blind action) | Acceleration L/T² | Message dispatched to handler |
| 2. State reacts | **Cancer** (reaction) | Velocity L/T | Internal state changes in response |
| 3. World observed | **Libra** (observation) | Position L | Relations queried, result read |
| 4. Control applied | **Capricorn** (control) | Control L/T³ | World committed, output emitted |

This is integration — the natural order. The actor starts with impulse
(message), accumulates change (state mutation), observes the result
(query), and applies control (commit). The learning cycle repeats with
each message, and the actor refines its behavior through accumulated state.

### OVS Verbs as Mutable / Cardinal / Fixed

The OVS verb system (Section: Object-Verb-Subject) maps onto the three
modalities. Each modality governs a different aspect of the actor:

| Modality | Role | OVS verbs | What it governs |
|----------|------|-----------|-----------------|
| **Mutable** (stimulus/relationship) | What triggers | `accepts`, `carries`, `contracts` | Message types, contract relations |
| **Cardinal** (action) | What happens | `does` (read/write/consume) | Handler methods, transformations |
| **Fixed** (state/result) | What persists | `has` (own/val), `spawns` | Owned state, child actors |

The mutable column is the actor's interface — what it receives. The cardinal
column is its behavior — what it does. The fixed column is its substance —
what it is. Together they form a complete description:

```
Mutable (stimulus)  →  Cardinal (action)  →  Fixed (state)
  accepts Join      →  does handle_join   →  has players: Vec<Player>
  accepts Query     →  does query_world   →  has db: CriomeDb
  contracts lojix   →  (no direct Rust)   →  (async relations only)
```

### The Twelve Measures in an Actor

The full twelve-measure table maps onto the actor lifecycle. Each element
(fire/water/air/earth) represents a different quality of actor operation:

| Element | Mutable (why) | Cardinal (how) | Fixed (what) |
|---------|--------------|----------------|--------------|
| **Fire** (spontaneous) | Hunch/intuition triggers action | Blind acceleration — message handler fires | Force — pure being, the actor exists |
| **Water** (emotional/change) | Belief/inertia — accumulated state | Velocity/change — state mutates | Momentum/transformation — state persists |
| **Air** (conceptual) | Knowledge/power — query patterns | Observation — reading the world | Significance/moment — leverage of position |
| **Earth** (practical) | Energy/work — concrete facts | Control — commit, emit, decide | Establishment — durable output |

The fire row is the actor's existence. The water row is its internal state.
The air row is its reasoning. The earth row is its effects on the world.

### Structural Properties

1. **Typed Messages**: Communication between actors occurs via typed message
   enums defined as Sema Objects, mirroring `accepts`/`carries` relations.
2. **Supervision Trees**: Any actor spawning a sub-task supervises its
   lifecycle (the Russian Doll model — fractal recursion of responsibility).
3. **State Sovereignty**: An actor's internal state is private, modifiable
   only via its message handlers. The actor IS the single owner.
4. **MCP as Actor Interface**: MCP tools are the external interface to
   samskara's actor. Each tool maps to a message the actor handles.
5. **Quorum Governance**: Critical contracts between components are governed
   by quorum contracts — N-of-M threshold agreements enforced cryptographically
   through Sema's content-addressing. A contract relation moves from luna to
   sol only when the quorum threshold of agents with sufficient dignity have
   each committed an approval. The VCS machinery (phase + dignity + multi-agent
   commits) provides this without a separate governance system.
6. **Contract as Membrane**: Inter-component communication is exclusively
   through contract relations. The contract is its own entity with its own
   owner. The two-pointed arrow between separate CozoDB instances.

---

## Naming and Ontology

- `PascalCase` denotes objects (types, traits, enum relations).
- `snake_case` denotes flow (methods, fields, data relations).
- A PascalCase relation name in CozoDB → enum type in Rust.
- A snake_case relation name in CozoDB → struct type in Rust (PascalCase'd).
- Avoid suffixes that restate objecthood (`Object`, `Type`, `Entity`).

The capitalization convention mirrors the filesystem durability tiers:
`ALL_CAPS` = supreme law (never edited by agents), `PascalCase` = stable
contract (edited only by mandate), `lowercase` = mutable implementation.

## Trait-Domain Rule

Any behavior in the semantic domain of an existing trait must be expressed as
a trait implementation. Inherent methods are not used to bypass trait domains.

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

Cap'n Proto is Sema v1's binary encoding — the birth canal. It is generated
deterministically from samskara relations at build time via `samskara-codegen`.
The generated types provide zero-copy Reader/Builder access.

The genesis bootstrap: Sema v1 is specified by the capnp output of its own
relational specification. Then Sema uses itself to define its next version.
Each version is archived in `archive_reader_version` — Kronos logs the full
lineage. Once Sema can describe itself natively, Cap'n Proto becomes
historical: archived, readable, no longer the live encoding.

The storage pipeline for world snapshots:
```
samskara rows → JSON → zstd → base64 → CozoDB String column      (v1)
samskara rows → Cap'n Proto packed → zstd → base64 → CozoDB       (v2)
samskara rows → native Sema → zstd → base64 → CozoDB              (future)
```

All versions coexist via `reader_version` in `archive_reader_version`. Content
addressing uses BLAKE3 throughout. Correctness is security — the hash IS the
identity.

---

## Init Envelope Purity

Runtime launch and initialization configuration arrives as one structured
init message object (Cap'n Proto in v1). Environment variables are
process-layer plumbing (PATH, HOME, locale), not domain-state inputs.

Cap'n Proto schema files live within their respective component's directory
(e.g., `samskara/schema/`), not in a centralized schema directory. Each
component owns its own schema — the contract pattern applied to build
artifacts.

Domain state must be passed via structured data, not ad-hoc environment
variables. Data files are auditable, reproducible, and schema-validated.
When a structured data channel exists, routing state through env vars is
a category error.

---

## Repository Self-Containment

During Nix evaluation, each repository is a self-contained world. Code must
never reach into a parent repository, sibling checkout, undeclared local path,
or ad-hoc absolute filesystem path to obtain package/module code.

If reusable code is needed, it lives inside the active repository or arrives
through a declared flake input. Deep modules do not escape repo boundaries
with `../` traversal — shared derivations are exposed from the repo root and
passed down structurally.

This is the contract pattern applied to the build system: repositories
communicate through declared interfaces (flake inputs), not filesystem
adjacency.

---

## Code-First Governance

Repeatable behavior is implemented in code, not instruction text. If a
behavior can be enforced by a script, guard, or generated artifact, it
belongs there — not in an expanding prompt payload.

Repeated manual directives (same class of correction appearing multiple
times) must be converted into executable checks. Documentation states
intent and contracts; code enforces operational mechanics.

---

## The Three Subsystems

Every significant system decomposes into three — the trinity pattern derived
from the 2→3 transition:

| Subsystem | Role | Planetary analogy |
|-----------|------|-------------------|
| **Foundation** (schema, relations, seed data) | What exists | ☉ Sol — the manifest |
| **VCS** (snapshot, delta, commit, restore) | What changes | ☽ Luna — the becoming |
| **Codegen** (samskara-codegen, capnp, types) | What endures | ♄ Saturn — the crystallized |

As each subsystem matures, it may split out into its own component with its
own contracts — following the cell division pattern. The VCS layer currently
lives inside samskara as a module. When it develops its own logic plane
distinct from samskara's datalog reasoning, it becomes its own component with
a contract.

---

## Documentation Protocol

Documentation is impersonal, timeless, and precise. Document only
non-boilerplate behavior. Comments are mandatory only when the "why" cannot
be structural. Self-documenting code is preferred over comments.
