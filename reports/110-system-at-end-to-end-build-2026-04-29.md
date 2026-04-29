# 110 — System architecture at the end-to-end build milestone

*Forward-looking snapshot of the workspace at the milestone
when **a user can author a flow graph as records in sema, issue
a `BuildRequest`, and receive a working compiled binary**
referenced from sema by hash. Lifetime: lives until the
described shape is encoded in the canonical docs +
skeleton-as-design code, then deleted. Refreshed 2026-04-29
after the forge / arca / signal-forge restructure.*

---

## 0 · TL;DR

The milestone is **first end-to-end build** — first time the
project's central thesis (records → working actor runtime) is
demonstrated. Concretely:

- `signal::BuildRequest` verb shipped (the new request criome
  accepts/denies and forwards).
- `criome` validates + reads records + forwards them to `forge`
  via a `signal-forge::Build` verb. **criome itself runs
  nothing.**
- `forge` links `prism` and runs the full pipeline internally:
  prism emits `.rs` → workdir assembly → `nix build` → bundle
  into `arca` (the content-addressed store).
- `CompiledBinary` record asserted to sema; reply chain back to
  the client.

The mentci GUI editor (M3–M4 / parallel track) may or may not
be present at this milestone — this report covers the back-end
through-line independently.

---

## 1 · Architectural rules (intent, made explicit)

These are the rules that shape every component below. They are
the *meta-architecture* — the invariants that determine how the
pieces fit together.

1. **criome runs nothing.** criome is the **state-engine**
   around sema. It validates, persists, and communicates. It
   does **not** spawn subprocesses, write files outside sema,
   invoke external tools, or link code-emission libraries.
   Effect-bearing work is dispatched as typed signal verbs to
   other components.

2. **Components per function.** One capability, one crate, one
   repo. Adding a feature defaults to a *new* crate, not a new
   `mod` in an existing one. Each component fits in an LLM
   context window. The workspace is the antithesis of a
   monolith.

3. **Signal is the messaging system.** Every wire in the
   sema-ecosystem is signal-shaped: front-ends → criome **and**
   criome → forge. There is one wire protocol family.

4. **Layered protocols, not parallel ones.** `signal-forge`
   depends on `signal` (Frame envelope, handshake, auth, record
   types) and adds the effect-bearing verbs criome forwards to
   forge. Front-ends depend only on `signal`; builder-internal
   field churn doesn't recompile them. **Audience-scoped
   compile-time isolation.**

5. **Push, never pull.** Producers expose subscription
   primitives; consumers subscribe. No polling fallback ever.
   If a push primitive isn't yet built, real-time features
   *defer* — they don't paper over with a poll loop.

6. **arca is general-purpose.** A content-addressed store for
   any data that doesn't fit in sema's record shape. forge is
   one writer of many; future writers earn the same write
   capability the same way (criome-signed token).

7. **prism is a library, linked by forge.** Not by criome
   (criome runs nothing). prism reads flow-graph records and
   emits Rust source; forge calls into it during the
   build pipeline.

---

## 2 · Component map — the three clusters

```
                      ╔═══════════════════════════╗
                      ║      STATE CLUSTER        ║
                      ║                           ║
                      ║   ┌───────────────────┐   ║
                      ║   │      criome       │   ║
                      ║   │  (state-engine)   │   ║
                      ║   │                   │   ║
                      ║   │  validates ·      │   ║
                      ║   │  forwards ·       │   ║
                      ║   │  persists         │   ║
                      ║   │                   │   ║
                      ║   │  runs nothing     │   ║
                      ║   └────────┬──────────┘   ║
                      ║            │ writes/reads ║
                      ║            ▼              ║
                      ║   ┌───────────────────┐   ║
                      ║   │       sema        │   ║
                      ║   │    (database;    │   ║
                      ║   │      redb)        │   ║
                      ║   └───────────────────┘   ║
                      ╚═══════════╤═══════════════╝
                                  │
                                  │ signal (front-end verbs)
                                  │  +  signal-forge
                                  │  (effect-bearing verbs)
                                  │
              ┌───────────────────┼─────────────────┐
              │                   │                 │
       ╔══════▼═════════╗   ╔═════▼═════════╗   ┌───▼─────────┐
       ║   FRONT-ENDS   ║   ║   EXECUTOR    ║   │  direct     │
       ║   (signal)     ║   ║   CLUSTER     ║   │  signal     │
       ║                ║   ║   (signal +   ║   │  speakers   │
       ║  nexus daemon  ║   ║    signal-    ║   │             │
       ║   (text↔sig)   ║   ║    forge)     ║   │  agents,    │
       ║       ▲        ║   ║               ║   │  scripts,   │
       ║       │ text   ║   ║  ┌─────────┐  ║   │  workspace  │
       ║       ▼        ║   ║  │  forge  │  ║   │  tools      │
       ║  nexus-cli     ║   ║  │ daemon  │  ║   └─────────────┘
       ║                ║   ║  │         │  ║
       ║  GUI repo      ║   ║  │ links   │  ║
       ║   (egui)       ║   ║  │ prism   │  ║       ┌─────────┐
       ║       ▲        ║   ║  │ runs nix│  ║       │ lojix-  │
       ║       │ uses   ║   ║  │ writes  │  ║       │  cli    │
       ║       ▼        ║   ║  │ to arca │  ║       │         │
       ║  mentci-lib    ║   ║  └────┬────┘  ║       │ (legacy │
       ║  (gesture→sig) ║   ║       │ writes║       │ deploy  │
       ║                ║   ║       ▼       ║       │ tool;   │
       ║  + future      ║   ║  ┌─────────┐  ║       │ migrates│
       ║    mobile/alt  ║   ║  │  arca   │  ║       │ to thin │
       ║    UIs         ║   ║  │  (FS,   │  ║       │ signal  │
       ║                ║   ║  │   redb  │  ║       │ client) │
       ║                ║   ║  │   index)│  ║       └─────────┘
       ╚════════════════╝   ║  └─────────┘  ║
                            ╚═══════════════╝

      ┌── wire-type crates ──┐    ┌── library crates ──┐
      │                      │    │                    │
      │      signal          │    │       prism        │
      │  (Frame envelope     │    │  (records → Rust   │
      │   + handshake        │    │   source; linked   │
      │   + auth             │    │   by forge)        │
      │   + records          │    │                    │
      │   + front-end verbs) │    │     mentci-lib     │
      │                      │    │  (gestures → signal│
      │  signal-forge        │    │   envelopes;       │
      │  (layered atop       │    │   linked by GUI    │
      │   signal; carries    │    │   + alt UIs)       │
      │   criome ↔ forge     │    │                    │
      │   verbs)             │    │                    │
      │                      │    │                    │
      │  nota / nota-codec   │    │                    │
      │  / nota-derive       │    └────────────────────┘
      │  (text codec for     │
      │   nexus dialect)     │   ┌── workspace ───────┐
      │                      │   │      mentci        │
      └──────────────────────┘   │   (umbrella —      │
                                 │    dev shell,      │
                                 │    design corpus,  │
                                 │    agent rules)    │
                                 │                    │
                                 │  tools-documenta-  │
                                 │  tion (cross-      │
                                 │  project rules)    │
                                 └────────────────────┘
```

Three runtime clusters speak via typed protocols. The
type-only crates (signal, signal-forge, nota stack) sit
underneath, consumed by multiple participants.

---

## 3 · Component roles

| Component | Role | What it depends on |
|---|---|---|
| **sema** | the database — records' home (redb-backed; content-addressed by blake3) | nothing |
| **criome** | the state-engine — validates, persists, forwards. Runs nothing. | sema, signal, signal-forge |
| **signal** | workspace wire protocol — Frame envelope + handshake + auth + records + front-end verbs (rkyv types only) | nota-codec, rkyv |
| **signal-forge** | layered atop signal — carries the criome ↔ forge wire (Build, Deploy, store-entry operations) | signal |
| **nexus daemon** | text ↔ signal gateway | signal, nota-codec |
| **nexus-cli** | thin text client | (UDS to nexus daemon) |
| **forge daemon** | executor — links prism, runs nix, writes to arca | signal, signal-forge, prism, arca |
| **arca** | content-addressed filesystem + redb index. General-purpose; forge is one writer of many | redb |
| **prism** | library: records → Rust source (linked by forge) | signal (record types) |
| **mentci-lib** | library: gesture → signal envelope, criome connection management (future) | signal |
| **GUI repo** | egui flow-graph editor (future) | mentci-lib, egui |
| **nota / nota-codec / nota-derive** | text codec stack for nexus dialect | rkyv |
| **lojix-cli** | legacy CriomOS deploy tool. Migrates to a thin signal-speaking client of forge over phases B–E | signal (eventual) |
| **mentci** | workspace umbrella — design corpus, agent rules, dev shell | (workspace-only) |
| **tools-documentation** | cross-project rules + tool docs | (no runtime) |

---

## 4 · Wire protocols

### 4.a · signal — the workspace base protocol

Every signal-speaking client (nexus daemon, mentci-lib through
GUI, agents, scripts, lojix-cli once it migrates) sends
`signal::Request` over UDS to criome and receives
`signal::Reply`.

```
signal::Request
│
├─ Handshake(HandshakeRequest)        ── must be first on the connection
│
├── EDIT (mutating sema) ──
├─ Assert(AssertOperation)
├─ Mutate(MutateOperation)
├─ Retract(RetractOperation)
├─ AtomicBatch(AtomicBatch)
│
├── READ ──
├─ Query(QueryOperation)              ── one-shot read
├─ Subscribe(QueryOperation)          ── push-subscription [M2+]
│
├── DRY-RUN ──
├─ Validate(ValidateOperation)        ── would-be outcome without commit
│
└── DISPATCH ──
   └─ BuildRequest(BuildRequestOp)    ── compile a graph [NEW @ M5]


signal::Reply
│
├─ HandshakeAccepted / HandshakeRejected
├─ Outcome(OutcomeMessage)            ── one OutcomeMessage per edit
├─ Outcomes(Vec<OutcomeMessage>)      ── per-position for batches
└─ Records(Records)                   ── typed per-kind result
```

**Perfect specificity.** Each verb's payload is its own typed
enum naming the kinds it operates on. No generic record
wrapper.

### 4.b · signal-forge — layered atop signal for criome↔forge

```
signal-forge::Request
│
├─ Build(BuildSpec)                   ── records → CompiledBinary
│   └─ BuildSpec {
│        target: Slot,                ── Graph slot the user requested
│        graph:  Graph,               ── the actual record (signal types)
│        nodes:  Vec<Node>,
│        edges:  Vec<Edge>,
│        nix_target: Option<String>,
│        ... (TBD)
│     }
│
├─ Deploy(DeploySpec)                 ── nixos-rebuild on target host
│
└─ store-entry operations             ── get / put / delete on arca
                                         (gated by capability token)


signal-forge::Reply
│
├─ BuildOk { store_entry_hash, narhash, wall_ms }
├─ DeployOk { generation, wall_ms }
├─ StoreOk(StoreOutcome)
└─ Failed { code: String, message: String }
```

### 4.c · Why the layering is load-bearing

**Audience-scoped compile-time isolation.** Front-ends depend
only on `signal`. When a forge-internal field changes (adding
`nix_target_platform`, refining `BuildOutcome`, evolving
capability-token shapes), only criome and forge recompile.
nexus daemon, mentci-lib, the GUI repo, future mobile UIs,
agents — none recompile.

A unified single-crate signal would force every front-end to
recompile on every builder-protocol tweak. With the layered
shape, builder-protocol churn is contained.

The Frame envelope, handshake, auth, and capability tokens are
shared (live in `signal`); only the verbs differ.

---

## 5 · Library API surfaces

```
prism (linked by forge daemon)
─────────────────────────────────────────────────────
INPUT:   FlowGraphSnapshot {
           graph: &Graph,
           nodes: &[Node],
           edges: &[Edge],
         }                                — signal types

OUTPUT:  Emission {
           files: Vec<EmittedFile>,       — full set of .rs source
         }

         EmittedFile {
           path: PathBuf,                 — relative to workdir root
           contents: String,
         }

TEMPLATES (one per node-kind, hand-coded in prism):
  Source       ─→ ractor Actor with external-boundary State
  Transformer  ─→ ractor Actor with 1→1 message handler
  Sink         ─→ ractor Actor with consumer State
  Junction     ─→ ractor Actor with multi-port topology
  Supervisor   ─→ ractor Actor whose handle_supervisor_evt does
                   the work (control-plane node)


mentci-lib (future; linked by GUI repo + alt UIs)
─────────────────────────────────────────────────────
INPUT:   user gestures (typed events)
OUTPUT:  signal::Request envelopes
         + criome connection management (UDS, handshake, framing)
         + reply demux: per-gesture diagnostic surface

GESTURE → SIGNAL MAPPING:
  drag-new-box  ─→ Assert(Node)
  drag-wire     ─→ Assert(Edge)
  delete-box    ─→ Retract(...)
  rename-box    ─→ Mutate(Node { slot, new, expected_rev })
  bulk-edit     ─→ AtomicBatch([...])      (composite gestures atomic)


arca (linked by forge for write; readable by anyone)
─────────────────────────────────────────────────────
READER (public — any process can link):
  StoreReader::contains(hash) -> Result<bool>
  StoreReader::resolve(hash)  -> Result<StorePath>
  StoreReader::entries()      -> Result<impl Iterator>

WRITER (in-process only; capability-gated):
  StoreWriter::put_tree(source, narhash) -> Result<StoreEntryHash>
  StoreWriter::delete(hash)              -> Result<()>


signal (no runtime — types only)
─────────────────────────────────────────────────────
Re-exported by: every signal-speaker. Carries Frame + handshake
+ auth + record kinds + front-end verbs. Wire: rkyv 0.8
portable feature set.


signal-forge (no runtime — types only)
─────────────────────────────────────────────────────
Re-exported by: criome (sender), forge (receiver), lojix-cli
(transitional sender of deploy verbs). Carries Build + Deploy
+ store-entry verbs. Depends on signal for envelope/auth.
```

---

## 6 · Flow — Edit (existing M0)

```
USER          NEXUS-CLI      NEXUS DAEMON       CRIOME            SEMA
 │               │                │                │                │
 │ (Assert       │                │                │                │
 │   (Node "X")) │                │                │                │
 │ ── text ─────▶│                │                │                │
 │               │ ── UDS text ──▶│                │                │
 │               │                │ parse text  →  │                │
 │               │                │ signal::       │                │
 │               │                │  Request::     │                │
 │               │                │  Assert(Node…) │                │
 │               │                │ ── UDS rkyv ──▶│                │
 │               │                │                │ validate:      │
 │               │                │                │  schema/refs/  │
 │               │                │                │  perms/inv.    │
 │               │                │                │ ── write ─────▶│
 │               │                │                │ ◀── ack ───────│
 │               │                │ ◀── Reply ─────│                │
 │               │                │   Outcome(Ok)  │                │
 │               │ ◀── UDS text ──│                │                │
 │ ◀── text ─────│                │                │                │
```

mentci-lib clients skip nexus daemon — they speak signal
directly to criome.

---

## 7 · Flow — Query (existing M0)

```
CLIENT          CRIOME             SEMA
 │                │                 │
 │ Query(NodeQuery│                 │
 │   { name: ?* })│                 │
 │ ── UDS rkyv ──▶│                 │
 │                │ scan Node table │
 │                │ filter by name  │
 │                │ ── read ───────▶│
 │                │ ◀── Vec<Node> ──│
 │ ◀── Reply ─────│                 │
 │  Records::Node │                 │
 │   (Vec<Node>)  │                 │
```

---

## 8 · Flow — Build (NEW @ M5 — the milestone flow)

```
USER     NEXUS DAEMON    CRIOME              FORGE (links prism)              SEMA
 │            │             │                   │                               │
 │BuildRequest│             │                   │                               │
 │ @target    │             │                   │                               │
 │── text ───▶│             │                   │                               │
 │            │parse →      │                   │                               │
 │            │signal::     │                   │                               │
 │            │ BuildRequest│                   │                               │
 │            │  {Slot}     │                   │                               │
 │            │── UDS rkyv ▶│                   │                               │
 │            │             │ validate target:  │                               │
 │            │             │  Slot resolves to │                               │
 │            │             │  a Graph?         │                               │
 │            │             │ refs ok?          │                               │
 │            │             │ perms ok?         │                               │
 │            │             │ ◀── read records ─────────────────────────────────│
 │            │             │   Graph + Nodes   │                               │
 │            │             │   + Edges         │                               │
 │            │             │                   │                               │
 │            │             │ forward via       │                               │
 │            │             │ signal-forge::    │                               │
 │            │             │   Build(records)  │                               │
 │            │             │ ── UDS rkyv ─────▶│                               │
 │            │             │                   │ ┌─ inside forge ─────────────┐│
 │            │             │                   │ │ call prism (lib):          ││
 │            │             │                   │ │  emit .rs from records     ││
 │            │             │                   │ │ FileMaterialiser:          ││
 │            │             │                   │ │  write workdir to disk     ││
 │            │             │                   │ │ NixRunner:                 ││
 │            │             │                   │ │  spawn nix build           ││
 │            │             │                   │ │  ↓ result: /nix/store/...  ││
 │            │             │                   │ │ StoreWriter:               ││
 │            │             │                   │ │  copy + RPATH-rewrite      ││
 │            │             │                   │ │  + blake3 + redb-index     ││
 │            │             │                   │ │  → ~/.arca/<hash>/         ││
 │            │             │                   │ └────────────────────────────┘│
 │            │             │ ◀── BuildOk ──────│                               │
 │            │             │  { store_entry_   │                               │
 │            │             │     hash, ... }   │                               │
 │            │             │                   │                               │
 │            │             │ assert            │                               │
 │            │             │ CompiledBinary{   │                               │
 │            │             │  graph: target,   │                               │
 │            │             │  store_entry_hash,│                               │
 │            │             │  narhash, ...}    │                               │
 │            │             │ ─── write ────────────────────────────────────────▶
 │            │             │ ◀── ack ───────────────────────────────────────────│
 │            │ ◀── Reply ──│                   │                               │
 │            │  Outcome(Ok)│                   │                               │
 │ ◀── text ──│             │                   │                               │
```

**criome's role end-to-end**: validate, read, forward, await,
assert, reply. **No subprocess. No file write. No external
tool. No prism link.**

**forge's role**: receive records, link prism, run prism, write
workdir, run nix, bundle into arca, reply. Everything that's
"doing" lives here.

---

## 9 · Flow — Subscribe (M2+ — push, never pull)

```
CLIENT                CRIOME                                   SEMA
 │                       │                                       │
 │ Subscribe(NodeQuery   │                                       │
 │   { ... })            │                                       │
 │ ── UDS rkyv ─────────▶│                                       │
 │                       │ register subscription                 │
 │                       │ ◀── any matching write ───────────────│
 │ ◀── push: Records ────│                                       │
 │ ◀── push: Records ────│ ◀── any matching write ───────────────│
 │     ...               │                                       │
 │ (close socket)        │ subscription dies with the connection │
 │ ─── EOF ─────────────▶│                                       │
```

No initial snapshot — issue a `Query` first if you want
current state. Per `tools-documentation/programming/push-not-pull.md`,
clients **defer** their real-time feature until Subscribe ships
rather than poll while waiting.

---

## 10 · mentci UI — parallel track (M3-M4, independent of M5)

```
USER       GUI REPO           MENTCI-LIB              CRIOME
gesture       │                    │                     │
 │            │                    │                     │
 │ click /    │                    │                     │
 │ drag /     │                    │                     │
 │ keyboard   │                    │                     │
 │──gesture──▶│                    │                     │
 │            │ buffered locally   │                     │
 │            │ until commit       │                     │
 │            │ (Enter, mouse-up,  │                     │
 │            │  explicit submit)  │                     │
 │            │                    │                     │
 │            │ ── commit ────────▶│                     │
 │            │                    │ translate to        │
 │            │                    │ signal::Request     │
 │            │                    │ ── UDS rkyv ───────▶│
 │            │                    │                     │ validate
 │            │                    │                     │ persist or
 │            │                    │                     │ reject
 │            │                    │ ◀── Reply ──────────│
 │            │ ◀── outcome ───────│                     │
 │            │                    │                     │
 │            │ on Outcome(Ok):    │                     │
 │            │   re-render        │                     │
 │            │ on Diagnostic:     │                     │
 │            │   surface in UI    │                     │
 │            │                    │                     │
```

**Load-bearing property**: the UI never holds state that
contradicts criome. Local in-flight buffer (typing in progress,
wire mid-drag) is *pending input*, not a contradicting
projection. Composite gestures wrap in `AtomicBatch`.

---

## 11 · Open shapes (the agent's known unknowns)

| Item | Open question |
|---|---|
| `signal::BuildRequest` payload | beyond `target: Slot` — nix-attr override, target-platform, env knobs |
| `signal-forge::Build` payload | precise field set; whether to combine with materialize step or split |
| Capability tokens | criome-signed BLS G1 token shape; verification path inside forge |
| criome → forge connection module | re-use criome's `Connection` actor for the forge leg, or introduce a `ForgeLink`? |
| `mentci-lib`'s exact API | precise type names + connection lifecycle (auto-reconnect, handshake retry) |
| GUI repo name | "mentci" remains the working name in design docs until that repo is created |
| Subscribe payload format | what arrives on the stream — snapshot delta or full record? |
| Per-kind sema tables | physical layout in redb (replaces the M0 1-byte discriminator) |
| `RelationKind` control-plane variants | `Supervises`, `EscalatesTo` — exact set when the Supervisor kind lands |
| Node-kind enum | the 5 first kinds (Source / Transformer / Sink / Junction / Supervisor) need to land in `signal/src/flow.rs` |

These are not blockers — each can be settled when the relevant
component is wired.

---

## 12 · What's NOT here (intentionally)

- **No deployment topology.** Whether components compile into
  one binary, many binaries, or talk over a network is left
  open. The architecture is *source-organization*, not
  deployment (per
  [`tools-documentation/programming/micro-components.md`](../repos/tools-documentation/programming/micro-components.md)).
- **No nexus-text grammar additions.** The sigil for
  `BuildRequest` is TBD; nexus parser+renderer wire-in is a
  thin layer.
- **No M6 self-host close.** That's the next layer — criome's
  own request flow expressed as records, prism emits criome
  from them, recompile, loop closes (`bd mentci-next-zv3`,
  `bd mentci-next-ef3`). Mechanism shown here is the
  prerequisite.
- **No mentci UI screens.** The UI's visual design (egui
  widget choices, theming, astrological-chart rotatable rings)
  is out of scope here — this report is about the wire and
  components, not the pixels.
- **No CriomOS / horizon-rs / lojix-cli deploy flows.** Those
  are an existing parallel track that retains its current
  shape; lojix-cli migrates to a thin signal-speaking client
  during phases B–E.

---

## 13 · The criome-runs-nothing rule, illustrated

For verification — the rule made concrete. Each row shows one
concern; columns show which component is responsible.

| Concern | criome | forge |
|---|---|---|
| Validates request against schema/refs/perms/invariants | ✓ | — |
| Reads from sema | ✓ | — |
| Writes to sema | ✓ | — |
| Forwards typed verbs to other components | ✓ | — |
| Awaits replies | ✓ | — |
| Persists outcome records (e.g. `CompiledBinary`) | ✓ | — |
| Spawns subprocesses (nix) | — | ✓ |
| Writes files outside sema (workdir + arca) | — | ✓ |
| Links `prism` (the code-emission library) | — | ✓ |
| Runs `nix build` via crane + fenix | — | ✓ |
| Bundles closures + RPATH-rewrites via patchelf | — | ✓ |
| Updates redb index inside arca | — | ✓ |
| Performs `nixos-rebuild` (deploy) | — | ✓ |

If a future agent finds itself adding a "spawn", "write file",
"link prism", "run X" capability to criome, **that's the
failure mode the doctrine closes**. Add it to forge instead, or
— if it's a new capability with its own bounded context — start
a new component (per the micro-components rule).

---

## 14 · Lifetime

This report is forward-looking — it captures the shape *we
expect to converge on*. Lives in `reports/` until:

- `criome/ARCHITECTURE.md` carries the BuildRequest flow at
  full fidelity (currently has the corrected §7 Compile flow
  but `BuildRequest` itself is not yet a signal verb in code).
- `signal/` carries the `BuildRequest` verb as a typed struct
  + matching `BuildRequestOp` + the 5 first node-kind structs
  (`Source` / `Transformer` / `Sink` / `Junction` /
  `Supervisor`).
- `signal-forge/` carries the `Build` verb + outcome types
  (currently a skeleton-as-design crate with the role
  documented but no payload structs yet).
- `prism/` and `forge/` carry the skeleton-as-design code
  matching this picture (FlowGraphSnapshot type sketch in
  prism; actor-pipeline scaffolding in forge).
- `arca/` reader/writer trait method signatures are sketched
  (currently `todo!()` with no public method shapes).
- `mentci-lib/` and the GUI repo exist (or are explicitly
  scoped to a later milestone).

When all of those exist, this report is deleted. Until then it
is a verification artifact: if the picture above is wrong, this
is the place to correct it before code starts.
