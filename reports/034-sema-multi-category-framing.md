# 034 — sema as a multi-category records store

*Claude Opus 4.7 / 2026-04-24 · Li's scope clarification elevates sema
from "code records DB" to "universal typed records DB" hosting multiple
kinds of criomed state: operational, code-as-logic, world-model, and
whatever comes next. This report enumerates the categories, proposes a
"sema citizen" contract, discusses cross-category cascades, extensibility,
queries, risks, and MVP scoping.*

---

## Part 1 — Category enumeration

Four category-bands emerge from Li's framing, ordered by clarity of scope.

### 1.1 · Core operational (criomed itself)

Purpose: *let criomed behave as a durable, multi-tenant, auditable
daemon rather than a single-user library*. These existed implicitly in
earlier reports but were never called a category.

Example kinds:

- **SubscriptionIntent**, **PrincipalKey**, **CapabilityPolicy** — as
  in 033.
- **CapabilityToken** — short-lived signed delegation tokens.
- **AuditEntry** — append-only log of mutating verbs (actor, verb,
  revision, outcome).
- **RateLimit**, **QuotaBalance** — per-principal budget ledger.
- **RuntimeIdentity**, **VersionSkewGuard** — process fingerprint plus
  the `(nexus-schema, criomed, sema-format)` version triple.
- **BlsQuorumPolicy** *(future)* — threshold set for quorum-gated verbs.
- **Session** — long-lived re-attachable session state (most session
  data is actor memory, not a record).
- **NamedRefEntry** — OpusRoot / Bookmark / WorkingHead; mutable
  pointers, schema still lives here.

Crate: a new **`criome-schema`**, separate from `nexus-schema` because
these kinds do not appear in user-authored nexus text; keeping them out
shrinks the public schema surface rsc and the matcher must know.
`nexus-schema` re-exports only the few kinds that cross the wire.

### 1.2 · Code-as-logic (the Rust slice)

Purpose: *the fully-specified structural representation of Rust code
that rsc projects to `.rs` and that rustc-as-derivation validates*.

Already enumerated in report 004 and report 033 Part 2:

- **Fn, Struct, Enum, Module, Program, Expr, Statement, Pattern, Type,
  Signature, TraitDecl, TraitImpl, Field, Variant, Method, Param,
  Origin, Visibility, Import, Newtype, Const.**
- **Opus, Derivation, OpusDep, RustToolchainPin, FlakeRef** — the
  build/deploy aggregate family (already in `nexus-schema`).
- **Obligation, CoherenceCheck, TypeAssignment, BorrowFacts,
  BorrowResult, Diagnostic, CompileDiagnostic, CompilesCleanly,
  CompiledBinary** — the analysis / outcome layer.
- **Rule, RulePremise, RuleHead, DerivedFrom** — the Phase-2 logic
  layer that drives cascades and attaches provenance.
- **StoreEntryRef, StoredEntry** — lojix-store handles.

Crate: `nexus-schema` — the canonical home, because these records are
authored in nexus text and are the primary payload on `criome-msg`.

### 1.3 · World-model / external data

Purpose: *a physical-world or domain-specific representation for
AI-driven reasoning or external integration*. Deliberately abstract
until a concrete use case lands. Precedents: ROS (`tf`-tree, parameter
server), scene graphs (Unity/Unreal), Datomic's attribute idiom, Cyc's
microtheories.

Illustrative kinds:

- **Observation** — timestamped sensor record with `source`, `kind`,
  `Payload: StoreEntryRef` for large data.
- **Fact** — `Entity × Attribute × Value × Time` EAV (Datomic shape
  without mutable attributes).
- **Entity** — identity of a thing (room, person, task, commodity).
- **Belief** — agent proposition with confidence and provenance.
- **SpatialFrame / SceneGraph** — ROS `tf`-style transform trees.
- **SemanticLink** — `(subject, predicate, object)` triples.

Crate: a separate **`world-schema`**, loaded via extensibility (Part 4);
nexus-cli users who never touch world-model data never compile it.

### 1.4 · "Whatever's next" candidates

- **Events / time-series** — tick-level telemetry, trace spans.
  Distinct from `AuditEntry`: high-volume, short-retention, lossy-
  compactible. Precedent: Prometheus, Honeycomb. `telemetry-schema`.
- **Preferences** — per-principal settings. Sub-namespace in
  `criome-schema`.
- **External API wraps** — memoised responses `(endpoint, request-hash,
  response, fetched-at, ttl)`. `ext-cache-schema`.
- **Knowledge graph** — cross-category edges ("this Fn implements
  RFC-1234"). `kg-schema`.
- **Agent scratchpad** — LLM reasoning chains, draft records, rejected
  hypotheses; different retention and authz from code. `agent-schema`.
- **Test/benchmark outcomes** — structured counterpart to cargo stdout.
- **Schema-migration records** — paper trail of kind evolution (Part 4).

---

## Part 2 — The sema-record contract

Across all categories, a minimal contract is what makes a record "a sema
citizen". The contract is the intersection of structural invariants the
engine already enforces plus a small set of schema-level declarations
every kind must expose.

### 2.1 · Structural invariants (engine-enforced)

- **Canonical rkyv encoding** — every kind has a deterministic byte
  representation that fixes equivalence.
- **Content-addressing by blake3** — identity is the blake3 of the
  canonical encoding. No category may opt out of hashing-as-identity;
  mutability lives only in the named-ref table (see 2.2).
- **Reference discipline** — all inter-record references are
  `RecordId` at rest (per 026). The dual-mode name→hash resolution
  lean from 031 P0.1 applies to every category: names on ingest,
  hashes on store. No category is permitted to carry name-only refs
  post-commit.
- **Kind declaration** — every record kind has a `KindDecl` / schema
  record stored in sema; the kind byte/id is itself a record reference,
  not a registry entry compiled into criomed. See Part 4.
- **Schema validation on mutate** — criomed's mutation pipeline calls
  the kind's schema to reject ill-formed record trees before they
  enter sema. Uniform across categories.

### 2.2 · Declarations every category-schema must expose

- **KindDecl** — the record kind's `StructSchema`/`EnumSchema`, with
  field types, visibility, and any generic-parameter slots.
- **Named-ref policy** — does this kind participate in a git-refs-style
  mutable-pointer table (like `OpusRoot`)? If yes, the schema declares
  the table name and key-tuple shape.
- **Cascade-participation declaration** — three-valued:
  - *inert* (no rule fires on assertions/retractions of this kind; it
    is pure data);
  - *triggering* (rules may match this kind as premise);
  - *derived* (this kind may only be written by rule-firing, not by
    user-visible verbs).
  The declaration lets criomed plan cascade work and lets the schema
  forbid manual tampering with derived records.
- **History mode** — *append-only* (every revision preserved),
  *compact* (history may be truncated beyond watermark),
  *ephemeral* (only current state retained; no Assertion log entry).
  Categories like LLM scratchpad or sensor telemetry are cheap only
  if they may be ephemeral.
- **Query/index hints** — which fields are queryable, which warrant
  secondary indices, which participate in subscription matching.
  Indices themselves are records in a meta category; hints tell
  criomed which to build.
- **Authorization envelope** — default `CapabilityPolicy` class for
  verbs on this kind: who may assert, retract, subscribe, or emit a
  derivation-target of it. The category-schema declares a policy
  record that is itself versioned and discoverable.
- **Durability class** — *durable* (must survive restart, fsync on
  commit), *cached* (may be rebuilt after restart), *session*
  (exists only within one session). Pairs with history mode.

The minimum for "sema citizen" is the intersection: a `KindDecl`
record, a cascade-participation class, a history mode, and a default
auth policy. Everything else (named refs, index hints, derivation
machinery) is optional and additive.

### 2.3 · Precedents

Datomic attributes (`cardinality`, `valueType`, `unique`, `index`,
`fulltext`) are the closest fit. CRDT libraries use a similar "opt
into a uniform protocol to be a peer" shape, though we do not need
merge because sema is single-writer. rkyv's trait contract is the
Rust-level counterpart; the sema contract sits one layer up.

---

## Part 3 — Rules and cascades across categories

### 3.1 · Do rules cross category boundaries?

**Yes, selectively.** The whole point of holding diverse state in one
store is that derivations can join across categories: an `AuthzPolicy`
change may invalidate a `CompilesCleanly` verdict if a `RunCargoPlan`
requires a capability the user no longer holds; a world-model
`Observation` may trigger a `Rule` that asserts a new `Obligation`
in the code-as-logic category (e.g. "if the environment's temperature
record exceeds 80°C, require the firmware opus to set `#[cfg(hot-mode)]`"
— contrived but representative).

Full isolation would make cross-cutting queries (Part 5) impossible and
would replicate the "separate databases" problem that the single-sema
design exists to avoid.

### 3.2 · Stratification strategy

Unrestricted cross-category rules are dangerous: a noisy world-model
feed can amplify into code-plan churn. The stratification pattern with
the best precedent is **layered datalog stratification** — rules are
assigned a stratum, and a rule in stratum N may only match premises
from strata ≤ N and assert heads in stratum N (no back-edges).

Concretely:

- **Stratum 0 — core operational.** Seeds, capabilities, principals,
  subscriptions. Rules here may only cross into themselves.
- **Stratum 1 — code-as-logic.** May read stratum 0 (e.g. read a
  `CapabilityPolicy` when deciding whether a compile plan is
  permitted) but may not write it.
- **Stratum 2 — world-model.** May read 0 and 1.
- **Stratum 3 — derived / higher-order (knowledge-graph, agent
  scratchpad).** Reads all.

Stratum assignment is a property of the `Rule` record (mandatory
field in the rules layer's `KindDecl`). Criomed's rule engine refuses
to install a rule whose head-kind's stratum is lower than its premise-
kinds' strata. This mirrors datalog's negation-stratification
constraint and guarantees cascade termination per stratum per revision.

### 3.3 · Derived-from across categories

A code-as-logic record derived-from a world-model record is *allowed*
under the stratification above (stratum 2 may write stratum 2, not
stratum 1), but the reverse — code derived from world-model — should
normally live in a higher stratum. If we genuinely need a code record
whose content depends on world-model state, the right pattern is a
**view record in stratum 3** that wraps / projects the code record
with world-model-dependent metadata, rather than mutating the code
record itself. This keeps the code category reproducible and
hash-stable under world-model churn.

`DerivedFrom` provenance edges (033 Part 2) are orthogonal to
stratification — they work across strata because they only record what
drove what, without allowing writes across the boundary.

---

## Part 4 — Schema extensibility

### 4.1 · Categories at runtime vs compile time

Categories should **not** be baked into criomed. A compiled-in category
set makes every new state kind (world-model sensors, domain-specific
records, experimental telemetry) a criomed rebuild, which violates the
self-hosting tightness we want.

### 4.2 · Minimum compiled-in set

Criomed ships knowing only:

- The schema-of-schema records themselves (StructSchema, EnumSchema,
  FieldSchema, VariantSchema, TypeRef, TypeParam from 033 Part 2) —
  bootstrapped from Rust literals per 033 Part 5.
- The `criome-schema` operational minimum: PrincipalKey,
  CapabilityPolicy, SubscriptionIntent, RuntimeIdentity,
  VersionSkewGuard, AuditEntry, NamedRefEntry, and the `Rule` family
  (if rules are enabled in MVP).
- The `nexus-schema` code-as-logic minimum so criomed can validate its
  own rebuild cycle.

Everything beyond this — world-model, telemetry, agent scratchpad,
knowledge graph, external API caches — is loaded as schema records
from sema itself at startup. Criomed knows the *meta* layer (how to
read a `KindDecl`); it learns the *domain* layer from sema.

### 4.3 · Precedent fit

Datomic's schema-as-data (attributes as transacted entities) is the
closest fit; Unison's namespace-as-data is compatible. Postgres
`ALTER TABLE` is wrong — assumes a rigid base set. ROS / EAV stores are
informative for world-model but too loose for code.

Sema should adopt Datomic + Unison's shape, with one refinement: a
**`CategoryDecl`** record sits above `KindDecl` to declare a category
namespace, default cascade stratum, default durability class, default
auth envelope. New categories arrive by asserting a `CategoryDecl` plus
`KindDecl`s; criomed validates them and makes the category live without
restart.

### 4.4 · Migration records

Kind evolution (adding a field, renaming a variant) is recorded as a
`KindMigration { from: KindDecl, to: KindDecl, transform: RuleId }`
record. Criomed applies the migration lazily on read, or eagerly via a
batch plan at a quiet moment. This is Datomic's pattern; its cost is a
migration-engine subsystem we do not ship at MVP.

---

## Part 5 — Cross-category queries and UX

### 5.1 · The example query

"Show me every `Fn` that calls `resolve_pattern` AND has failed its
last compile attempt" joins code-as-logic (`Fn`, call-edges) with
outcomes (`CompileDiagnostic`). Unsurprising SQL/Datomic shape: project
`Fn` by call-graph predicate, semi-join with `CompileDiagnostic` whose
`site` hashes into the `Fn`'s closure. Primitives exist.

### 5.2 · Query surface

Report 013's delimiter matrix generalises cleanly: a query body
introduces pattern variables, binds them across kinds, asserts a
projection. Category membership is not a syntactic concept — the
planner figures out which category/index hits.

UX conventions: no category prefixes when unambiguous (kind names are
globally unique; `KindDecl` registration rejects collisions); optional
filter `{ @category: code ... }` for scoping; index selection hidden,
planner chooses by `KindDecl` hints.

### 5.3 · Patterns across categories

`RawPattern` → `PatternExpr` works unchanged. Pattern types (report
009) reference kinds and fields; they know nothing about categories.
The *planner* is category-aware (world-model patterns hit time/spatial
indices; code-as-logic patterns are structural); the matcher is not.

---

## Part 6 — Risks and non-obvious consequences

**Category starvation.** A high-churn category (LLM scratchpad, video
observations) can flood the writer and starve code cascades.
Mitigation: `CategoryDecl` carries a priority band / rate budget; the
writer honours per-category admission control. Precedent: network QoS,
kernel scheduler classes.

**Hash-dedup under churn.** Unique records never dedup anyway; the
real risk is nearly-identical records bloating sema. Mitigation:
*ephemeral* or *compact* durability class plus time-window compaction
rules that collapse N observations into a summary.

**Not everything must be durable.** The contract already declares
durability class per kind. `CapabilityToken` is session-scope;
cached external-API responses are rebuildable. Storage layer routes
each class (redb for durable, actor memory for session, bounded cache
for cached).

**When categories disagree** (Li's "world-model says winter, code says
`#[cfg(summer)]`"): explicit conflict policy in `CategoryDecl`. Either
*strict isolation* (world-model state cannot feed a cfg flag — safe
default) or *oracle projection* (a content-hashed
`WorldModelProjection` record is what code derivations observe,
keeping reproducibility). Without either, drifting world-model would
silently rebuild binaries — the classic IoT failure mode.

**Cross-category query cost.** Joins can go O(N × M). Keep cross-
category rules few, require secondary indices on matched fields,
surface plan estimates before committing a subscription.

**Authorization sprawl.** `CapabilityPolicy` inherited at category
level, overridable at kind level — filesystem ACL inheritance shape.

---

## Part 7 — MVP scope

Given solstice pressure and the self-hosting target:

### 7.1 · MVP-essential

- **Core operational**, minimum viable subset: PrincipalKey,
  CapabilityPolicy, SubscriptionIntent, RuntimeIdentity,
  VersionSkewGuard, AuditEntry, NamedRefEntry. No BLS quorum yet; a
  single-principal authz is enough for self-host.
- **Code-as-logic**, full scope: the report 004 kind list plus the
  Opus family, outcomes (CompileDiagnostic, CompilesCleanly,
  CompiledBinary), and StoreEntryRef. This is the working surface.
- **Schema-of-schema**, hardcoded seed records per 033 Part 5.

### 7.2 · Phase-1 (immediately post-self-hosting)

- **Rules layer** enabled: `Rule`, `RulePremise`, `RuleHead`,
  `DerivedFrom`. Stratification enforced from day one so later
  categories can join safely.
- **Category extensibility** (Part 4): `CategoryDecl` record kind,
  runtime-loadable schemas. Until this lands, category-hood is
  implicit; new kinds compile into `nexus-schema` or `criome-schema`.
- **Migration records**: `KindMigration` + batch-apply plan. Enables
  schema change without losing history.

### 7.3 · Phase-2+

- **World-model category.** Defer — concrete use case pending. The
  framing above is enough preparation; no crate needs to exist until a
  user claims it. `world-schema` is a post-MVP crate.
- **Telemetry / events.** Same deferral; add when observability needs
  exceed `AuditEntry`.
- **External API wraps** and **knowledge graph** — opportunistic; each
  adds when a concrete workflow demands it.
- **Agent scratchpad** — gated on nexus-cli and agent tooling
  maturity; probably earlier than world-model because LLM agents are
  already adjacent to the engine.

### 7.4 · Where world-model belongs on the roadmap

World-model is **Phase 2 or later**. The MVP does not need it, and
premature design risks overfitting to hypothetical domains. The
contract (Part 2) ensures that when a real world-model need arises,
dropping in a `world-schema` crate is an extensibility exercise, not
an architecture change.

---

## Closing synthesis

Sema is not a code database with bolted-on auxiliary tables; it is a
uniform typed record store whose discipline (content-addressing,
schema-bound kinds, cascade participation, history, authz) is the
same regardless of what the records describe. Categories exist to
organise meaning and to scope cost — stratification, priority,
durability — not to partition storage. The "sema citizen" contract
(Part 2) makes the rules explicit enough that new categories cost a
schema declaration rather than a code change, which is what Li's
"whatever we think of next" demands. MVP stays narrow (core-ops +
code-as-logic); the rest arrives as the ecosystem finds its real
shape.

---

*End report 034.*
