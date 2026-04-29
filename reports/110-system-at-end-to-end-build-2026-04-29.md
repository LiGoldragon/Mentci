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
- `criome` validates + reads records + signs a capability token
  + forwards records-and-token to `forge` via a
  `signal-forge::Build` verb. **criome itself runs nothing.**
- `forge` links `prism`, runs the build pipeline (prism emits
  `.rs` → workdir → `nix build` → bundle), and **deposits the
  bundled tree into arca's write-only staging directory**.
- `forge` sends `signal-arca::Deposit{staging_id, token}` to
  `arca-daemon`.
- `arca-daemon` verifies the token, computes blake3 of the
  staged content, atomically moves into the target store,
  updates the per-store redb index, replies with the hash.
- `CompiledBinary { arca_hash, store, narhash, ... }` asserted
  to sema; reply chain back to the client.

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

6. **arca is general-purpose, with a daemon.** A content-
   addressed store for any data that doesn't fit in sema's
   record shape. **arca is one library + one daemon.** The
   library is the public reader. **arca-daemon** is the
   privileged writer: it owns a write-only staging directory,
   manages multiple stores for access control, verifies
   criome-signed capability tokens, computes blake3 of staged
   content (no TOCTOU race), and atomically moves into the
   target store. forge is the most active writer of many;
   future writers earn the same capability the same way.

7. **prism is a library, linked by forge.** Not by criome
   (criome runs nothing). prism reads flow-graph records and
   emits Rust source; forge calls into it during the
   build pipeline.

8. **Deployment is nix-based, aggregated from mentci.** Each
   canonical crate publishes its own flake; mentci composes
   them into NixOS modules + service specs.
   `nixos-rebuild --flake mentci#<host>` is the deploy. lojix-cli
   drives this today; criome will eventually drive it via
   signal-forge `Deploy` verbs.

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
       ╔══════▼═════════╗   ╔═════▼═════════════════╗   ┌─▼─────────┐
       ║   FRONT-ENDS   ║   ║   EXECUTOR CLUSTER    ║   │  direct   │
       ║   (signal)     ║   ║   (signal + signal-   ║   │  signal   │
       ║                ║   ║    forge + signal-    ║   │  speakers │
       ║  nexus daemon  ║   ║    arca)              ║   │           │
       ║   (text↔sig)   ║   ║                       ║   │  agents,  │
       ║       ▲        ║   ║   ┌──────────────┐    ║   │  scripts, │
       ║       │ text   ║   ║   │    forge     │    ║   │  tools    │
       ║       ▼        ║   ║   │   daemon     │    ║   └───────────┘
       ║  nexus-cli     ║   ║   │              │    ║
       ║                ║   ║   │ links prism, │    ║       ┌────────┐
       ║  GUI repo      ║   ║   │ runs nix,    │    ║       │lojix-  │
       ║   (egui)       ║   ║   │ bundles to   │    ║       │ cli    │
       ║       ▲        ║   ║   │ _staging/    │    ║       │        │
       ║       │ uses   ║   ║   └──────┬───────┘    ║       │ legacy │
       ║       ▼        ║   ║          │ deposits   ║       │ deploy │
       ║  mentci-lib    ║   ║          ▼            ║       │ tool;  │
       ║  (gesture→sig) ║   ║   ┌──────────────┐    ║       │ becomes│
       ║                ║   ║   │ arca-daemon  │    ║       │ thin   │
       ║  + future      ║   ║   │              │    ║       │ signal │
       ║    mobile/alt  ║   ║   │ verifies     │    ║       │ client │
       ║    UIs         ║   ║   │ token, hashes│    ║       └────────┘
       ║                ║   ║   │ blake3,      │    ║
       ║                ║   ║   │ atomic move  │    ║
       ╚════════════════╝   ║   │ to <store>/  │    ║
                            ║   └──────┬───────┘    ║
                            ║          │            ║
                            ║          ▼            ║
                            ║  ┌─────────────────┐  ║
                            ║  │  arca on disk   │  ║
                            ║  │ ~/.arca/        │  ║
                            ║  │  _staging/      │  ║
                            ║  │   (write-only)  │  ║
                            ║  │  <store>/       │  ║
                            ║  │   <blake3>/...  │  ║
                            ║  │   index.redb    │  ║
                            ║  │  (multi-store;  │  ║
                            ║  │   read-only to  │  ║
                            ║  │   consumers)    │  ║
                            ║  └─────────────────┘  ║
                            ╚═══════════════════════╝

      ┌── wire-type crates ──┐    ┌── library crates ──┐
      │                      │    │                    │
      │      signal          │    │       prism        │
      │  (Frame envelope     │    │  (records → Rust   │
      │   + handshake        │    │   source; linked   │
      │   + auth             │    │   by forge)        │
      │   + records          │    │                    │
      │   + front-end verbs) │    │     arca lib       │
      │                      │    │  (public reader;   │
      │  signal-forge        │    │   layout types)    │
      │  (criome ↔ forge:    │    │                    │
      │   Build, Deploy,     │    │     mentci-lib     │
      │   capability tokens) │    │  (gestures →       │
      │                      │    │   signal; linked   │
      │  signal-arca         │    │   by GUI + alt     │
      │  (writers ↔          │    │   UIs)             │
      │   arca-daemon:       │    │                    │
      │   Deposit, …)        │    └────────────────────┘
      │                      │
      │  nota / nota-codec   │   ┌── workspace +────────┐
      │  / nota-derive       │   │   meta-deploy        │
      │  (text codec for     │   │      mentci          │
      │   nexus dialect)     │   │  (umbrella — dev     │
      │                      │   │   shell, design      │
      └──────────────────────┘   │   corpus, agent      │
                                 │   rules, +           │
                                 │   nix-flake deploy   │
                                 │   aggregator)        │
                                 │                      │
                                 │  tools-documenta-    │
                                 │  tion (cross-project │
                                 │  rules)              │
                                 └──────────────────────┘
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
| **signal-forge** | layered atop signal — carries the criome ↔ forge wire (Build, Deploy) | signal |
| **signal-arca** | layered atop signal — carries the writers ↔ arca-daemon wire (Deposit, …) | signal |
| **nexus daemon** | text ↔ signal gateway | signal, nota-codec |
| **nexus-cli** | thin text client | (UDS to nexus daemon) |
| **forge daemon** | executor — links prism, runs nix, bundles outputs to arca's `_staging/`, asks arca-daemon to take ownership | signal, signal-forge, signal-arca, prism, arca (lib) |
| **arca (library)** | public reader API + on-disk layout types | redb (read) |
| **arca-daemon** | privileged writer — owns write-only `_staging/`, manages multi-store, verifies criome-signed capability tokens, computes blake3, atomic moves | signal, signal-arca, arca (lib), redb (write) |
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

### 4.c · signal-arca — the writers ↔ arca-daemon wire

```
signal-arca::Request
│
├─ Deposit(DepositSpec)               ── ask arca-daemon to take
│   └─ DepositSpec {                     ownership of staged content
│        staging_id: StagingId,
│        target_store: StoreId,
│        capability_token: Token,     ── criome-signed
│     }
│
├─ ReleaseToken(TokenId)              ── relinquish a capability
│
└─ (read queries against the per-store index, TBD)


signal-arca::Reply
│
├─ DepositOk { blake3, bytes }
└─ Failed { code, message }
```

forge is the most active writer of these verbs today; future
writers (uploads, document ingestion, anything blob-shaped)
speak the same protocol.

### 4.d · Why the layering is load-bearing

**Audience-scoped compile-time isolation.** Front-ends depend
only on `signal`. forge depends on `signal-forge` (for criome
verbs it receives) + `signal-arca` (for writer verbs it sends
to arca-daemon). arca-daemon depends on `signal-arca` only.

When a forge-internal field changes (adding
`nix_target_platform`, refining `BuildOutcome`), only criome
and forge recompile. When arca-daemon's deposit shape evolves,
only writers + arca-daemon recompile. nexus daemon, mentci-lib,
the GUI repo, future mobile UIs, agents — none recompile on
either kind of churn.

A unified single-crate signal would force every front-end to
recompile on every builder-protocol or store-protocol tweak.
With the layered shape, internal churn is contained to its
audience.

The Frame envelope, handshake, auth, and capability-token
encoding are shared (live in `signal`); only the verbs differ
per layer.

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
USER  NEXUS    CRIOME              FORGE (links prism)         ARCA-DAEMON       SEMA
 │      │        │                   │                              │              │
 │BuildR│        │                   │                              │              │
 │ @tgt │        │                   │                              │              │
 │─text▶│        │                   │                              │              │
 │      │parse → │                   │                              │              │
 │      │signal::│                   │                              │              │
 │      │ Build- │                   │                              │              │
 │      │ Request│                   │                              │              │
 │      │  {Slot}│                   │                              │              │
 │      │─rkyv─▶│                   │                              │              │
 │      │        │ validate target:  │                              │              │
 │      │        │  Slot → Graph?    │                              │              │
 │      │        │ refs/perms ok?    │                              │              │
 │      │        │ ◀── read records ────────────────────────────────────────────────│
 │      │        │ sign capability   │                              │              │
 │      │        │  token (target    │                              │              │
 │      │        │  store + scope)   │                              │              │
 │      │        │                   │                              │              │
 │      │        │forward via        │                              │              │
 │      │        │signal-forge::     │                              │              │
 │      │        │  Build{records,   │                              │              │
 │      │        │    cap_token}     │                              │              │
 │      │        │── UDS rkyv ──────▶│                              │              │
 │      │        │                   │┌─ inside forge ─────────────┐│              │
 │      │        │                   ││ prism (lib):               ││              │
 │      │        │                   ││  emit .rs from records     ││              │
 │      │        │                   ││ FileMaterialiser:          ││              │
 │      │        │                   ││  write workdir to disk     ││              │
 │      │        │                   ││ NixRunner:                 ││              │
 │      │        │                   ││  spawn nix build           ││              │
 │      │        │                   ││  ↓ result: /nix/store/...  ││              │
 │      │        │                   ││ StoreWriter:               ││              │
 │      │        │                   ││  RPATH-rewrite + det-time  ││              │
 │      │        │                   ││  → write canonicalised     ││              │
 │      │        │                   ││    tree into               ││              │
 │      │        │                   ││    ~/.arca/_staging/<id>/  ││              │
 │      │        │                   │└──┬─────────────────────────┘│              │
 │      │        │                   │   │ ArcaDepositor:           │              │
 │      │        │                   │   │  signal-arca::           │              │
 │      │        │                   │   │    Deposit{staging_id,   │              │
 │      │        │                   │   │      target_store,       │              │
 │      │        │                   │   │      cap_token}          │              │
 │      │        │                   │   ──── UDS rkyv ────────────▶│              │
 │      │        │                   │                              │ verify token │
 │      │        │                   │                              │ scan staging │
 │      │        │                   │                              │ compute      │
 │      │        │                   │                              │  blake3      │
 │      │        │                   │                              │ atomic move  │
 │      │        │                   │                              │  to <store>/ │
 │      │        │                   │                              │  <blake3>/   │
 │      │        │                   │                              │ update redb  │
 │      │        │                   │                              │  index       │
 │      │        │                   │   ◀── DepositOk{blake3} ─────│              │
 │      │        │ ◀── BuildOk ──────│                              │              │
 │      │        │  { arca_hash,     │                              │              │
 │      │        │    narhash, ... } │                              │              │
 │      │        │                   │                              │              │
 │      │        │ assert            │                              │              │
 │      │        │ CompiledBinary{   │                              │              │
 │      │        │   opus, store,    │                              │              │
 │      │        │   arca_hash,      │                              │              │
 │      │        │   narhash, ...}   │                              │              │
 │      │        │ ─── write ────────────────────────────────────────────────────── ▶
 │      │        │ ◀── ack ─────────────────────────────────────────────────────────│
 │      │ ◀── Re-│                   │                              │              │
 │      │ ply Ok │                   │                              │              │
 │ ◀text│        │                   │                              │              │
```

**criome's role**: validate, read records, sign capability
token, forward to forge, await, assert outcome record, reply.
No subprocess. No file write. No external tool. No prism link.

**forge's role**: receive records, link prism, run prism, write
workdir, run nix, bundle to arca's `_staging/`, ask
arca-daemon to take ownership, await hash. forge does NOT
compute the canonical blake3 — arca-daemon does.

**arca-daemon's role**: verify token, compute blake3 of
exactly-what-was-staged, atomic move into the right store,
update per-store index, reply with the canonical hash. Sole
writer of the canonical store directories.

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
| `signal-forge::Build` payload | precise field set including the capability-token field criome signs for forge to present to arca-daemon |
| `signal-arca::Deposit` payload | precise field set; how staging IDs are minted; whether multiple deposits batch |
| `signal-arca` repo | needs to be created as a peer to signal-forge; same layered shape (depends on signal for envelope/auth) |
| Capability tokens | criome-signed BLS G1 token shape; one token covers (depositor, target store, validity window); verification logic in arca-daemon |
| Write-only staging mechanism | filesystem-level (chmod 1733 + per-deposit subdirs?) or process-boundary-level (SCM_RIGHTS, namespace)? |
| Multi-store registry | how arca-daemon learns which stores exist and their ACL — sema records read at startup, or pushed via signal-arca? |
| criome → forge connection module | re-use criome's `Connection` actor for the forge leg, or introduce a `ForgeLink`? |
| `mentci-lib`'s exact API | precise type names + connection lifecycle (auto-reconnect, handshake retry) |
| GUI repo name | "mentci" remains the working name in design docs until that repo is created |
| Subscribe payload format | what arrives on the stream — snapshot delta or full record? |
| Per-kind sema tables | physical layout in redb (replaces the M0 1-byte discriminator) |
| `RelationKind` control-plane variants | `Supervises`, `EscalatesTo` — exact set when the Supervisor kind lands |
| Node-kind enum | the 5 first kinds (Source / Transformer / Sink / Junction / Supervisor) need to land in `signal/src/flow.rs` |
| mentci flake structure | per-host NixOS module surface (criome service + nexus service + forge service + arca-daemon service); composing the canonical crate flakes |

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

| Concern | criome | forge | arca-daemon |
|---|---|---|---|
| Validates request against schema/refs/perms/invariants | ✓ | — | — |
| Reads from sema | ✓ | — | — |
| Writes to sema | ✓ | — | — |
| Forwards typed verbs to other components | ✓ | — | — |
| Awaits replies | ✓ | — | — |
| Signs capability tokens (criome holds the key) | ✓ | — | — |
| Persists outcome records (e.g. `CompiledBinary`) | ✓ | — | — |
| Spawns subprocesses (nix) | — | ✓ | — |
| Links `prism` (the code-emission library) | — | ✓ | — |
| Runs `nix build` via crane + fenix | — | ✓ | — |
| Bundles closures + RPATH-rewrites via patchelf | — | ✓ | — |
| Performs `nixos-rebuild` (deploy) | — | ✓ | — |
| Writes the bundled tree into arca's `_staging/` | — | ✓ | — |
| Verifies criome-signed capability tokens | — | — | ✓ |
| Computes blake3 of staged content | — | — | ✓ |
| Atomic move from `_staging/` into `<store>/<blake3>/` | — | — | ✓ |
| Updates per-store redb index | — | — | ✓ |
| Manages multi-store ACL (only writer of canonical store dirs) | — | — | ✓ |

If a future agent finds itself adding a "spawn", "write file
into a store", "link prism", "run X" capability to criome,
**that's the failure mode the doctrine closes**. Add it to
forge or arca-daemon (whichever owns that concern) — or, if
it's a new capability with its own bounded context, start a
new component (per the micro-components rule).

---

## 14 · Lifetime

This report is forward-looking — it captures the shape *we
expect to converge on*. Lives in `reports/` until:

- `criome/ARCHITECTURE.md` carries the BuildRequest flow at
  full fidelity (the corrected §7 Compile flow is there;
  `BuildRequest` itself isn't a signal verb in code yet).
- `signal/` carries the `BuildRequest` verb as a typed struct
  + matching `BuildRequestOp` + the 5 first node-kind structs
  (`Source` / `Transformer` / `Sink` / `Junction` /
  `Supervisor`) + capability-token shape (BLS G1 signed by
  criome).
- `signal-forge/` carries the `Build` verb + outcome types
  (skeleton-as-design today; no payload structs yet).
- `signal-arca` repo created with the `Deposit` verb + outcome
  types (parallel to signal-forge; depends on signal for
  envelope/auth).
- `prism/` and `forge/` carry the skeleton-as-design code
  matching this picture — FlowGraphSnapshot type sketch in
  prism; NixRunner + StoreWriter + ArcaDepositor +
  FileMaterialiser actor scaffolding in forge.
- `arca/` carries arca-daemon binary skeleton + StoreReader
  trait body + StoreWriter (in-process inside arca-daemon)
  trait body + capability-token verification logic + write-only
  staging mechanism choice.
- `mentci/flake.nix` has the per-host NixOS module surface
  composing all four daemons (criome, nexus, forge,
  arca-daemon).
- `mentci-lib/` and the GUI repo exist (or are explicitly
  scoped to a later milestone).

When all of those exist, this report is deleted. Until then it
is a verification artifact: if the picture above is wrong, this
is the place to correct it before code starts.
