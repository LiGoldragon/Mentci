# 036 — world-model data as sema records — scoping research

*Claude Opus 4.7 / 2026-04-24 · Exploratory research requested by Li
after deciding sema's scope will grow past code-as-logic to include
world-model data for AI. MVP does not need any of this; the goal
is to check the sema architecture doesn't foreclose the direction,
and to flag where the framing is strong, mediocre, or wrong.*

---

## Part 1 — What "world model" means in AI right now

The phrase is ambiguous because at least four communities own it.

**Autoregressive latent world models.** Ha & Schmidhuber's "World
Models," the Dreamer line (V1–V3), PlaNet, MuZero's learned
dynamics, LeCun's JEPA and V-JEPA, the video-prediction frontier
(Sora, Genie, GAIA-1). Shape: observation → encoder → latent `z_t`
→ learned transition → next latent. The "model" is a learned
parameter tensor plus recurrent state. **Poor fit for records** —
the latent is opaque gigabyte-scale weights. Sema could hold
metadata (training opus, dataset hash, eval scores) and lojix-
store holds the weights, but the world-content is unreadable at
the record layer.

**Symbolic scene graphs.** SLAM-derived graphs (Armeni et al.
3D-scene-graph line, Hydra, Kimera), household-robotics
(AI2-THOR, iGibson), the video-language work (Visual Genome,
PSG). Nodes are entities with typed attrs; edges are labelled
relations. **Strong fit** — each node and edge is a record;
content-addressing plays well with "scene graph = snapshot of
a place at a time."

**Geometric / coordinate-frame state.** ROS tf2; physics-engine
world state (MuJoCo, Isaac Sim, PyBullet). A tree of coordinate
frames with timestamped transforms. **Decent fit with a caveat**:
update rate is killing. A tf broadcast emits hundreds of updates
per second per robot; per-update records would balloon the DB.
The working pattern is low-rate structural records (the frame
tree) plus high-rate time-series (the numerical transforms) —
sema holds the former, points at the latter.

**Dense parametric representations.** NeRF, Instant-NGP, 3D
Gaussian Splatting, Neural Radiance Caches. Opaque blocks of
parameters queried at `(x, y, z, view_dir)`. **Not a fit** — the
metadata record lives in sema, the weights live in lojix-store.

**Simulation state snapshots.** MuJoCo's `mjData`, Isaac Sim's
USD, a saved game state. Fit depends on structure: USD shards
into records (rigid body → record, joint → record); `mjData` is a
fat float vector that lives in lojix-store as a blob with a
metadata record. USD-shaped fits; `mjData`-shaped doesn't.

**Linked data / RDF triples.** SPARQL, Wikidata, Freebase,
DBpedia, YAGO. The sincerest "everything-is-data" predecessor
and the **best structural analogy** to sema. The knowledge-graph
community already solved most of the modelling questions we face
— entity resolution, temporal qualifiers, provenance, reification.
Worth studying in detail.

**Verdict.** Scene graphs, coordinate-frame trees, and RDF-style
facts are the subset that maps cleanly onto content-addressed
records. Parametric, latent, and dense-tensor representations
don't; they belong in lojix-store with sema holding metadata.
The "world model" framing therefore commits us to a *symbolic*
view of the world, not a *parametric* one. Name the choice.

---

## Part 2 — What sema-as-world-model-store could look like

A plausible post-MVP catalogue. Lives in a new crate —
`world-schema` — outside `nexus-schema` so code records stay
focused.

**Entity** — thing-in-the-world with stable identity. `{ kind:
EntityKind, intrinsic_attrs: Map, identity_basis: IdentityBasis }`.
The identity basis names *what makes this entity this entity*:
serial number, SLAM cluster ID, LLM-generated descriptor, or
"user declared so." Content hash captures identity-basis + kind +
intrinsics; extrinsics (position, state) live elsewhere.

**Relation** — `{ predicate: RelationKind, subjects:
Vec<EntityId>, qualifiers: Map }`. RDF with Wikidata-style
qualifiers (every triple carries "as of T, according to source
S, confidence C"). N-ary falls out since records can have any
arity.

**Observation** — `{ sensor: SensorId, at: TimePoint, payload,
provenance, confidence }`. Payload is inlined for small scalars/
vectors or `StoreEntryRef` for image/point-cloud/video frames.

**Belief** / **Prediction** — cascade outputs. `{ about: EntityId,
assertion: AttributeUpdate, derived_from: Vec<ObservationId>,
rule: RuleId, confidence, valid_for: TimeInterval }`. Predictions
are beliefs with `valid_for` in the future.

**Frame** — spatial scaffolding. `{ name, parent: FrameId,
transform: Transform3D, at: TimePoint }`. The frame tree is a
low-churn structural record set; the actual transform stream is
time-series (Part 4).

**Action** / **ActionOutcome** — intent and effect records.

**Sensor** / **Actuator** — catalogue records carrying
intrinsics, calibration (StoreEntryRef to calibration file),
and the frame they live in.

**Time-series sensor data does not live as per-frame records.**
It lives in an adjacent store — TimescaleDB, Parquet files in
lojix-store, a bespoke ring buffer — and sema holds
`ObservationSession` metadata plus hand-picked "interesting"
observations. Interesting-ness is itself a rule in sema.

---

## Part 3 — Tensions with the core sema model

**Content-addressing vs continuous change.** 30 FPS × one camera
= a new record hash every 33 ms. Naively ingesting each frame
gives tens of millions of records per hour per sensor. Redb can
probably survive; the cascade cannot. The answer is a **two-tier
model**: the high-rate layer isn't in sema, sema holds
`ObservationSession` records pointing at time-series storage,
and selected individual observations ("frame at which we first
saw the chair") do warrant record status. The selection filter
is a rule.

**Record identity vs entity identity.** Deepest friction. A
*chair* has persistent real-world identity — same chair at 10:03
and 10:04 — but every observation hashes to a different content.
Sema identity is content-identity; real-world identity is
continuant identity.

RDF / Wikidata solved this with **IRIs as stable handles**:
`Q12345` is that chair, triples accumulate. The hash-based
equivalent is to hash the entity's identity-basis subset
(serial number, SLAM cluster, or "user-declared") and call that
the persistent ID. The full `Entity` record changes as attributes
update; the ID stays stable because it's derived from the
identity-basis subset only. This is the git-refs pattern sema
already uses — `OpusRoot` is name → latest-record-hash.
`EntityHead` is the same pattern for entities. The infrastructure
generalises; policy is the new work.

This sharpens the **hash-vs-name refs question** (report 031
P0.1). Code has few named anchors; world has *many* — every
entity is effectively a name. The named-ref table has to scale
to millions of entries (redb handles this) and policy (who
creates entity IDs, GC, dangling references) gets materially
harder.

**Cascade cost.** Rules-cascade-across-all-records is
catastrophic for world data. 10 Hz observations × N rules × M
downstream records = unshippable. Cascade has to be
**stratified**: world rules fire over world records; code rules
over code records; cross-stratum rules are explicit and rare.
Datalog-with-strata is well-established; the sema rule engine
has to grow stratum awareness.

**Cardinality.** Millions-to-billions of records is plausible
for long-running world models. Redb scales there but once the DB
exceeds RAM, page-fault cost dominates and queries have to be
index-aware. The **dedup assumption** — content-addressing
deduplicates — works well for code (many identical sub-exprs),
less so for world data (every observation is unique because
timestamps differ). Mitigation: don't hash observations as whole
records; hash the stable subset, treat timestamp + payload as
sidecar. This is the same entity-identity pattern applied to
observations.

**Lossy vs lossless.** Raw sensor data is firehose. Autoregressive
world models compress to latents; symbolic models compress to
entity/relation assertions. Sema is symbolic: **it stores the
interpretation, not the raw**. Raw bytes can live in lojix-store
as StoreEntryRefs on observation records if we want them.
Consistent with sema's existing character — records are meaning,
not text.

---

## Part 4 — Time and temporal records

Sema is already temporal via `Revision` and `Assertion` —
bitemporal-ish in the Datomic sense.

**Records-as-snapshots.** Each moment is a full world record.
Storage-heavy; query-cheap; impractical at world scale unless
sparse (keyframes only).

**Records-as-events.** Each change is an event; current state
derives via fold. CQRS tradition: Kafka pipelines, EventStore,
Akka Persistence. Cheap storage; expensive arbitrary historical
reconstruction. Sema's Assertion log already works this way.

**Hybrid.** Entity records with temporal fields; Observation
records as events; Belief records as derived sparse snapshots.
This is Datomic's and XTDB's resting shape, and Hydra's in
robotics — layers of abstraction, each updated at its natural
rate. Sensible default.

**External time-series store.** Bulk high-rate data in Timescale /
Influx / Parquet; sema holds metadata. Every real-world robotics
system does this because nothing else survives sensor firehoses.

**Leaning.** Sema should *not* try to be a time-series DB. Define
a time-series adapter — probably another lojixd-adjacent daemon
or a library — and sema records reference time-series handles
the way they reference lojix-store entries. XTDB's bitemporal
model (valid-time × transaction-time) is the shape to study for
temporal queries; its primitives translate to sema's Revision +
Assertion vocabulary.

---

## Part 5 — Interaction with code sema

**Config from world.** A robot's `Current-battery-level` is a
world record updated every second. If every battery update
cascades a rebuild, we thrash and compile continuously. Fix is
record-shape discipline, not architecture: `Current-battery-
level` is not a compile-time `Const`; it's a runtime value the
compiled binary queries through the normal sema API. Code
records reference a *name* (`battery-level-sensor`) that resolves
to a world record at runtime, not a compile-time hash.

Useful line: **world records are read at runtime, not baked into
code-record hashes.** Code closure hash excludes world content.
The two strata are hash-isolated. Otherwise the compile cache is
worthless.

**Self-modifying agents.** An agent reads world data, mutates
its code records, cascade produces a new `CompiledBinary`.
Already possible under the existing design; world-in-sema
doesn't change the pathway. Discipline concern: don't update
code at observation frequency. The stratification from Part 3
makes this safe by default.

---

## Part 6 — Rules that span world and code

The engine doesn't need to distinguish world-reactive from
code-modifying rules at its lowest level; both are records with
premises and heads. Architecturally fine.

Operationally: a code-modifying rule fired from a world-reactive
premise means every close obstacle triggers a recompile. Almost
certainly not what the designer intended.

Not **hard stratification** (forbid cross-stratum rules) — that
rules out legitimate self-improvement. Instead **explicit-
gesture requirement**: cross-stratum rules carry a marker
(`Effect: TriggersCompile`), runtime can refuse high-rate firing
or schedule into low-frequency epochs. Engine accepts; operator
opts in.

Eve / Bloom / Dedalus is useful prior art — they distinguish
point-in-time (fast inner loop) from eventual (cross-epoch)
rules, syntactically. Something similar will be needed once
rules span high-churn world records.

---

## Part 7 — Scale realism

**Humanoid robot, working day.** ~100 stable entities; tf tree
of ~50 frames at 100 Hz (~18M tf updates/hour — none become
records, all time-series); 10 cameras at 30 FPS producing raw
frames into lojix-store, maybe 1% (300/hour) become records
carrying structural observations; 1000 Relation updates/hour;
100 Belief revisions/hour. 8-hour shift: ~5K records/day in
sema, millions of time-series points outside. Tractable.

**LLM agent, multi-day session.** 10–50 entities (task hierarchy,
docs, users, tools); entities update once per turn; ~100
records/hour; persistent across sessions. Very small. Sema is
overkill for storage but natural for structure — symbolic
matches LLM-agent reasoning exactly. The most obviously *good*
fit of the three.

**Distributed swarm.** 1000 agents × 100 entities each = 100K
entities in shared world. Writes must reconcile. This is where
sema alone stops sufficing and we need the CRDT machinery
(Automerge, Yjs) or distributed-DB transaction logs (Spanner,
FoundationDB). Shelving as out of scope for sema v1 is the
honest answer — sema per agent; cross-agent state is its own
system.

---

## Part 8 — Non-goals for MVP

Explicitly deferred: full world-model support; temporal indexing
beyond Revision/Assertion; time-series abstractions; sensor
ingestion; world-entity-identity machinery beyond the named-ref
generalisation code already needs; cross-stratum rule policy.

What the MVP **needs to not foreclose**:

- **Schema-registration interface.** Sema's schema-of-schema is
  record-valued; adding a `world-schema` crate is pure addition,
  not refactor. Confirm by writing one hypothetical world record
  and checking it stores without touching `nexus-schema`.
- **Named-ref table.** Today it holds `OpusRoot`. Same mechanism
  must generalise to `EntityHead` without schema changes — key
  by `(namespace, name)`, not just `name`, so code and world
  namespaces don't collide.
- **Rule-engine stratification.** MVP may ship rule-less or with
  one stratum. When rules arrive, have a *stratum* concept from
  day one so world rules add later without rule-system surgery.
- **StoreEntryRef opacity.** World observations need large blob
  references (frames, point clouds). Existing `StoreEntryRef`
  already handles this. Confirm GC and path resolution work for
  "attached media" as well as compiled binaries.

**Minimum architectural hook**: a namespace-keyed named-ref
table plus a stratum-aware rule engine. Both are needed for code
already; design them with generalisation in mind. No world-
specific code needs to land in the MVP.

---

## Part 9 — Open questions, honestly

**Is "sema holds world data" sincere, or a category error?**
Sincere for the symbolic slice (scene graphs, entity-relation
fact bases, RDF-style knowledge graphs); category error for the
parametric slice (NeRF weights, Dreamer latents, LLM KV caches).
Being explicit matters. "Sema is a knowledge graph over the
world" is accurate; "sema is a world model" over-claims if it
implies the learned-parameter kind.

**Lojix-store as home for raw sensor blobs?** Yes. Camera frames,
point clouds, recorded audio, video segments — all content-
addressed filesystem-native. Schema difference with compiled
binaries is zero. Sema records reference them identically. No new
machinery.

**Does hash-vs-name refs (report 031 P0.1) get harder?**
Materially. Code has dozens of named refs (one per opus); world
has millions (one per entity). Policy questions — orphaning,
revival, GC — scale with the count. MVP decision: `(namespace,
name) → hash` is a simple map with a clear GC rule (delete only
on explicit retract), namespaces are first-class so per-namespace
policy can be added later.

**Do sensor readings need BLS-quorum signatures?** For high-
stakes inputs ("the person I'm lifting is safe"), cryptographic
provenance is real. For 30 FPS camera frames, impractical. Right
answer: **signatures at the session level, not per observation**.
`ObservationSession` carries a signature asserting "I am sensor
X, I produced this session, here's the hash of the whole log."
Individual observations inherit trust. Matches how TLS secures
streams (once per session, not per byte). API-layer capability
enforcement — "only sensor X's principal writes to its session"
— does the rest.

---

## Verdict

The sema-as-world-model framing is **sincere for the symbolic
slice and misleading for the parametric slice**. The architecture
doesn't foreclose the direction — the schema-crate pattern,
named-ref table, lojix-store reference mechanism, and rule engine
all generalise cleanly if designed with stratification in mind.
New design work needed: entity-identity separation from record-
identity; time-series adapter for high-churn data that shouldn't
live in sema; stratum-aware rule firing; scale-up path for the
named-ref table. None must land in the MVP; all should be cheap
extensions later.

Biggest honest risk is **ambient confusion** — users thinking
"sema is my world model" and expecting it to eat their camera
firehose. Docs should name the symbolic/parametric split early
and direct parametric cases to lojix-store with metadata records.
Get the mental model right, the implementation is straightforward.

---

*End report 036.*
