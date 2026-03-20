# Rust Patterns

How to write Rust for the Criome. These are the structural patterns of
the living system — not conventions to follow, but the architecture itself.

---

## The Criome

The Criome is the cryptographic biome — the totality of all relationships
running on Sema. Components, contracts, quorums, alliances, truces,
obstacles. It is not a fixed architecture; it is a shifting, living graph
of ownership and trust. Most of it is not owned by any single psyche. It is
the emergent structure of all contracts composed.

```
Criome (the living biome — all relationships, all components)
  │
  ├── Mentci (one psyche's local participant)
  │     samskara — pure datalog agent, reasons about the world model
  │     lojix    — transpiler, translates between human DSL and Sema
  │
  ├── other psyche-clusters...
  │
  └── quorum contracts governing shared boundaries

Enabled by:
  Sema    — the universal symbolic format (the language the Criome speaks)
  CriomOS — the runtime substrate (Nix-built, Linux-hosted)
```

**Mentci** is one psyche-cluster's local tool for participating in the Criome.
It renders Sema for its human. Mentci is a participant *inside* the Criome,
not above it. The psyche is sovereign.

Rust implements the Criome components. The human is the reason they exist.

---

## Sema — The Enabling Cornerstone

The Criome cannot exist without a universal symbolic language. **Sema** is
that language — fully logical, machine-readable, self-describing. Data IS the
database — every object carries its own semantic context. Correctness IS
security — trust attaches to meaning, not transport.

Sema v1's binary encoding is Cap'n Proto — the birth canal, not the
permanent form. The genesis bootstrap: Sema v1 is specified by the capnp
output of its own relational specification (via samskara-codegen). Then Sema
rebuilds its next version using itself. Each version is logged in Kronos
(`archive_reader_version`). Once Sema can describe itself natively, Cap'n
Proto becomes historical.

Sema rarely changes; when it does, it is by expert consensus through the
Criome — the biome can become a source of authority for its own language.

---

## Contracts — The Fundamental Coupling

The contract is the fundamental design pattern of the Criome. All coupling
between components passes through contracts:

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

The contract owner controls the membrane. Critical contracts are governed by
**quorum contracts** — N-of-M threshold agreements where a relation moves
from luna to sol only when the quorum threshold is met. Phase + dignity +
multi-agent commits provide this machinery without a separate governance
system.

The pattern is recursive. If a component grows a new internal logic plane,
that plane splits out. If two contracts need to coordinate, their
coordination is itself a contract.

**Build-time dependencies** are a separate category. `samskara-codegen` is
consumed at compile time — it produces artifacts (capnp schemas, Rust types)
baked into the binary. Build-time deps do not need runtime contracts.

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

---

## Components — Source of Truth

Every Criome component is backed by a CozoDB instance. **Samskara** is the
pure datalog agent — the single source of truth for all type definitions,
ownership topology, and actor protocols within Mentci.

Rust code is *derived* from samskara relations — either generated at build
time (via samskara-codegen → Cap'n Proto → Rust types) or hand-written to
match the relational schema.

The specification lives in stored relations. The code implements the
specification. When they disagree, the relations are authoritative.

---

## The Subdivision Chain in Rust

The chain 2→3→5→7→12 (see `META_PATTERN.md` §II) governs how Criome
components decompose:

| N | Rust manifestation |
|---|-------------------|
| **2** | Owner/borrower. Key/value. Sol/Luna polarity. Move semantics. |
| **3** | Sol/Luna/Saturnus phase columns. The Three Subsystems pattern. |
| **5** | The 5 dignity levels on every versioned relation. |
| **7** | Actor agents — each with its own CozoDB, its own nature. |
| **12** | The twelve measure formulae mapped onto the actor lifecycle. |

---

## Actors — The Living Components

All multi-step transformations, long-running orchestrations, and concurrent
executions are implemented as supervised actors. The actor is the Rust
manifestation of the learning cycle — the same four-phase pattern that
governs the cardinal signs and position derivatives
(see `META_PATTERN.md` §IV).

### The Actor as Learning Cycle

An actor processes messages through four phases:

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

The OVS verb system maps onto the three modalities. Each modality governs
a different aspect of the actor:

| Modality | Role | OVS verbs | What it governs |
|----------|------|-----------|-----------------|
| **Mutable** (stimulus) | What triggers | `accepts`, `carries`, `contracts` | Message types, contract relations |
| **Cardinal** (action) | What happens | `does` (read/write/consume) | Handler methods, transformations |
| **Fixed** (state) | What persists | `has` (own/val), `spawns` | Owned state, child actors |

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
represents a different quality of actor operation:

| Element | Mutable (why) | Cardinal (how) | Fixed (what) |
|---------|--------------|----------------|--------------|
| **Fire** (spontaneous) | Hunch/intuition triggers action | Blind acceleration — handler fires | Force — the actor exists |
| **Water** (change) | Belief/inertia — accumulated state | Velocity — state mutates | Momentum — state persists |
| **Air** (conceptual) | Knowledge/power — query patterns | Observation — reading the world | Significance — leverage of position |
| **Earth** (practical) | Energy/work — concrete facts | Control — commit, emit, decide | Establishment — durable output |

The fire row is the actor's existence. The water row is its internal state.
The air row is its reasoning. The earth row is its effects on the world.

### Structural Properties

1. **Typed Messages**: Actor communication via typed message enums defined
   as Sema Objects, mirroring `accepts`/`carries` relations.
2. **Supervision Trees**: Any actor spawning a sub-task supervises its
   lifecycle (fractal recursion of responsibility).
3. **State Sovereignty**: An actor's internal state is private, modifiable
   only via its message handlers. The actor IS the single owner.
4. **MCP as Actor Interface**: MCP tools are the external interface to
   samskara's actor. Each tool maps to a message the actor handles.
5. **Contract as Membrane**: Inter-component communication is exclusively
   through contract relations (see Contracts above).

---

## Object–Verb–Subject

Every samskara relation is an OVS triple. The verb encodes ownership
semantics and determines the Rust ownership pattern — no lifetimes to
reason about, because the datalog relation specifies the ownership mode.

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

The `contracts` verb produces no Rust coupling by design — it is the
two-pointed arrow between separate CozoDB instances.

---

## Rust Patterns for Criome Code

### Schema Is Samskara

Every transmissible type corresponds to a stored relation. The relation
schema (`::columns`) defines the type's fields, key structure, and column
types. Rust structs are projections of these relations.

Enum types are PascalCase relations with a single String key column (e.g.,
`Phase`, `Dignity`, `CommitType`). The relation rows ARE the enum variants.

Wire encodings and storage formats are transport concerns. They do not
define the domain — samskara does. Schema is Sema; encoding is incidental.

### Criome Object Rule — Single Object In, Single Object Out

All values that cross object boundaries are Criome objects. Primitive
types are internal representations only. Naked tuples are not return
types.

Every method accepts at most one explicit object argument and returns
exactly one object. When multiple inputs or outputs are required, define
a new object.

```rust
// WRONG — multiple primitives crossing a boundary
fn get_download_url(&self, md5: &str, path_index: Option<u32>,
                    domain_index: Option<u32>) -> Result<DownloadInfo, Error>

// WRONG — naked tuple return
fn parse_results(html: &str) -> Result<(Vec<SearchResult>, bool), Error>

// RIGHT — one object in, one object out
fn download_url(&self, request: DownloadRequest) -> Result<DownloadInfo, Error>

// RIGHT — the type itself knows how to construct from source material
impl SearchResponse {
    pub fn from_html(html: &str, page: u32) -> Result<Self, Error> { ... }
}
```

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

### Objects Exist; Flows Occur

Objects are nouns that exist independently of execution. Flows are verbs
that occur during execution. A name that describes a flow cannot name
an object.

The trinity maps this distinction:

| Category | Planet | Nature | Examples |
|----------|--------|--------|----------|
| **Objects** | ☉ Sol | They exist | types, structs, relations, schemas |
| **Flows** | ☽ Luna | They occur | methods, queries, transformations |
| **Records** | ♄ Saturnus | They persist | snapshots, commits, archives |

```rust
// WRONG — flow encoded as object
struct ShowGreetingFromStdin;

// RIGHT — the object exists; the flow is a method
struct Greeting;
impl Greeting {
    pub fn from_stdin() -> Result<Self, Error> { ... }
}
```

### Everything Is an Object

Reusable behavior belongs to named types or traits. Free functions exist
only as orchestration shells in `main.rs`. Test helpers are methods on a
test fixture struct. Constructors are associated functions (`from_*`,
`new`), never module-level free functions.

```rust
// WRONG — free function constructs a type from outside
pub fn parse_item_details(json: &str, md5: &str) -> Result<ItemDetails, Error>

// RIGHT — the type constructs itself
impl ItemDetails {
    pub fn from_json(json: &str, md5: &str) -> Result<Self, Error> { ... }
}
```

Domain concepts are types, not primitives. A content hash is not a
`String`. A language code is not a `String`. If a value has semantic
identity beyond its representation, it is its own type.

```rust
// WRONG — a hash could be confused with any other string
pub fn details(&self, md5: &str) -> Result<ItemDetails, Error>

// RIGHT — the type encodes what the value IS
pub struct Md5([u8; 16]);
pub fn details(&self, md5: &Md5) -> Result<ItemDetails, Error>
```

### Binary Representation

When a value has a fixed-size binary form, store it as bytes. Hex
strings are a display concern, not a storage concern.

```rust
// WRONG — 32 hex chars pretending to be data
pub struct Md5(String);

// RIGHT — 16 bytes with hex serde
pub struct Md5([u8; 16]);

impl Md5 {
    pub fn to_hex(&self) -> String { ... }
}
```

Serde serializes to hex for JSON/human interchange. Internal code
operates on bytes. This applies to MD5, BLAKE3, SHA-256, and all
content hashes used in the Criome.

### Single Owner

Every object has exactly one owner. This is the actor model meeting Rust's
borrow checker — the same principle at two levels:

- **Relational level**: The `phase` column encodes lifecycle. Only
  `sol`-phase rows participate in the world hash. Ownership transfers
  (luna→sol→saturnus) are explicit commit operations (saṅkalpa).

- **Rust level**: Move semantics. No `Arc<Mutex<T>>` for domain state.
  Actors own their state exclusively and communicate via typed messages.

### Logic-Data Separation

Implementation files must not contain hardcoded paths, regexes, or numeric
constants. All such data must be:

- Stored in samskara relations (queryable, versionable)
- Loaded from `.cozo` schema/seed files
- Passed via typed message structs

Enum relations replace hardcoded string constants. Instead of
`if status == "approved"`, the valid values live in a `Status` relation.

An enum with an `Unknown(String)` fallback variant self-describes its
known set — do not duplicate variant names as a separate string array.
Use `is_known()` or pattern matching instead.

```rust
// WRONG — redundant list duplicating enum variants
const KNOWN_FORMATS: &[&str] = &["pdf", "epub", "mobi"];
if KNOWN_FORMATS.contains(&input) { ... }

// RIGHT — the enum IS the source of truth
let format = FileFormat::from(input);
if format.is_known() { ... }
```

---

## Phase and Dignity in Rust

All versioned relations carry `phase: String` and `dignity: String` columns.
For definitions and values, see `COZO_PATTERNS.md` §Phase and Dignity.

**Phase** governs ownership semantics:

| Phase | World hash | Rust ownership analogy |
|-------|-----------|----------------------|
| `sol` | **Yes** | Owned value — committed, immovable until superseded |
| `luna` | No | Mutable borrow — staged, can be modified before commit |
| `saturnus` | No | Archived — moved to cold storage, recoverable via restore |

**Commit** (saṅkalpa) is Luna→Sol: staged facts become manifest.
**Supersede** is Sol→Saturn: old truth moves to the archive.
**Restore** (pratiṣṭhā) is Saturn→Sol: archived state returns.

Phase and dignity are orthogonal. Both are `String` columns — not enums
in CozoDB, but validated against the `Phase` and `Dignity` enum relations.
In Rust codegen, they become typed enums.

---

## Naming and Ontology

- `PascalCase` denotes objects (types, traits, enum relations).
- `snake_case` denotes flow (methods, fields, data relations).
- A PascalCase relation name in CozoDB → enum type in Rust.
- A snake_case relation name in CozoDB → struct type in Rust (PascalCase'd).
- Avoid suffixes that restate objecthood (`Object`, `Type`, `Entity`).

### Ontology Validation

Terms introduced in Core/ documents must exist in the current project
ontology. Before naming a new rule, principle, or pattern:

1. Check `ARCHITECTURE.md` for active component names
2. Check `META_PATTERN.md` for active conceptual vocabulary
3. If a term appeared in old documents (CriomOS GUIDELINES, sajban)
   but is absent from current Mentci docs, it is not active

The Criome is the universal term — the living biome of all
relationships. Sema is a building block within it, not the framing
term. Rules are "Criome Object Rule", not "Sema Object Rule".

### Capitalization Durability Tiers

Capitalization in paths encodes durability — the resistance of content
to modification. This is structural, not stylistic.

| Tier | Paths/Files | Code | Durability |
|------|-------------|------|------------|
| `ALL_CAPS` | `CLAUDE.md`, `LICENSE`, `CONSTRAINTS/` | — | Immutable law. Never edited. Always prevails. |
| `PascalCase` | `Core/`, `Architecture.md` | types, traits | Stable contract. Changes require mandate. |
| `lowercase` | `src/`, `config.yaml` | methods, fields | Mutable implementation. Freely editable. |

Durability composes from the **maximum tier** in the path. A single
`ALL_CAPS` segment makes the entire path immutable. When tiers conflict,
the highest prevails.

### Trait-Domain Rule

Any behavior in the semantic domain of an existing trait must be expressed
as a trait implementation. Inherent methods are not used to bypass trait
domains.

```rust
use core::str::FromStr;

// Fallible parsing — use FromStr
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

// Infallible parsing with Unknown fallback — use From<&str>
impl From<&str> for FileFormat {
    fn from(s: &str) -> Self {
        match s.trim().to_lowercase().as_str() {
            "pdf" => Self::Pdf,
            "epub" => Self::Epub,
            // ...
            other => Self::Unknown(other.to_string()),
        }
    }
}

// Config to component — use From<Config>
impl From<Config> for Client {
    fn from(config: Config) -> Self { Self::from_config(config) }
}
```

### Direction Encodes Action

Prefer `from_*`, `to_*`, `into_*`. Avoid verbs like `read`, `write`,
`load`, `save`, `parse` when direction already conveys meaning.

| Pattern | Meaning |
|---------|---------|
| `from_db` | Construct by introspecting CozoDB |
| `from_html` | Construct by scraping HTML |
| `from_json` | Construct by deserializing JSON |
| `from_columns_result` | Construct from `::columns` output |
| `to_capnp_text` | Emit as Cap'n Proto schema text |
| `into_commit` | Consume self to produce a commit |

### Construction Resolves to the Receiving Type

All construction and parsing logic resides on the receiving type. The
identity claimed by the method name is always the return type.

```rust
// WRONG — free function claims identity of a type it doesn't own
fn parse_config(input: String) -> Config;

// RIGHT — the type owns its own construction
impl FromStr for Config {
    type Err = Error;
    fn from_str(input: &str) -> Result<Self, Self::Err> { ... }
}

// RIGHT — when ownership transfer is semantic
impl From<String> for Config {
    fn from(input: String) -> Self { ... }
}
```

---

## Error Types

### Scoping

An error type is named `Error`. The crate name provides the namespace —
`annas_archive::Error`, `criome_cozo::Error`, not `AnnaError` or
`CozoError`. Inside the crate, `Error` is unambiguous. The same
scoping principle applies to `Config`, `Client`, and other crate-primary
types — avoid prefixing with the crate name.

### Structured Variants

Error variants carry structured fields, not string bags. The caller
knows what operation they invoked — the error carries what went wrong,
not a narrative retelling of context.

```rust
// WRONG — stringly-typed, loses structure
Http { status: u16, context: String },
Parse { context: String },
AllDomainsFailed { context: String },

// RIGHT — structured, no redundant context
Http { status: u16 },
MissingField { field: &'static str },
DomainsExhausted,
```

`String` fields are reserved for messages from external systems (the
remote's words, not ours):

```rust
/// The remote API returned an error message.
Remote { message: String },
```

### Manual Impls

Error enums implement `Debug`, `Display`, and `std::error::Error`
manually — no `thiserror`. `From<T>` conversions bridge dependency
errors into the crate's `Error`.

```rust
impl From<reqwest::Error> for Error {
    fn from(err: reqwest::Error) -> Self { Error::Network(err) }
}

impl From<serde_json::Error> for Error {
    fn from(err: serde_json::Error) -> Self { Error::Decode(err) }
}
```

---

## Transport and Storage

Cap'n Proto is Sema v1's binary encoding — the birth canal. It is generated
deterministically from samskara relations at build time via
`samskara-codegen`. The generated types provide zero-copy Reader/Builder
access.

The storage pipeline for world snapshots:
```
samskara rows → JSON → zstd → base64 → CozoDB String column      (v1)
samskara rows → Cap'n Proto packed → zstd → base64 → CozoDB       (v2)
samskara rows → native Sema → zstd → base64 → CozoDB              (future)
```

All versions coexist via `reader_version` in `archive_reader_version`.
Content addressing uses BLAKE3 throughout. Correctness is security — the
hash IS the identity.

### The Kronos Guarantee

The VCS invariant: **Saturn preserves perfectly.** Every `world_snapshot`
is a complete, recoverable state. `restore_to_commit` (pratiṣṭhā) recovers
archived state without loss. Every Sema version is logged in
`archive_reader_version` — the full lineage of the format itself is
recoverable.

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
never reach into a parent repository, sibling checkout, undeclared local
path, or ad-hoc absolute filesystem path to obtain package/module code.

If reusable code is needed, it lives inside the active repository or arrives
through a declared flake input. Deep modules do not escape repo boundaries
with `../` traversal — shared derivations are exposed from the repo root
and passed down structurally.

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

Every significant Criome component decomposes into three:

| Subsystem | Role | Planetary analogy |
|-----------|------|-------------------|
| **Foundation** (schema, relations, seed data) | What exists | ☉ Sol — the manifest |
| **Codegen** (samskara-codegen, capnp, types) | What is generated | ☽ Luna — the generative, reflective |
| **VCS** (snapshot, delta, commit, restore) | What is preserved | ♄ Saturn — the ledger, the archive |

As each subsystem matures, it may split out into its own component with its
own contracts — following the cell division pattern. The VCS layer currently
lives inside samskara as a module. When it develops its own logic plane
distinct from samskara's datalog reasoning, it becomes its own component
with a contract.

---

## Documentation Protocol

Documentation is impersonal, timeless, and precise. Document only
non-boilerplate behavior. Comments are mandatory only when the "why" cannot
be structural. Self-documenting code is preferred over comments.
