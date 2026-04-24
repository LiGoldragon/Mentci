# 060 — post-MVP directions

*Claude Opus 4.7 · consolidates speculative future-direction
content previously in 034/035/036/044/048. Minimal by design —
each section names a direction, not a design space. Reports
034/035/036/044/048 are deleted; this replaces them.*

---

## 1 · Sema as the universal records store

Sema holds all of criomed's durable state. Operational records
(SubscriptionIntent, PrincipalKey, CapabilityPolicy,
RuntimeIdentity, VersionSkewGuard, AuditEntry, NamedRefEntry),
code records (the Fn/Struct/Module/Program/Derivation/Opus
catalogue), authz records (Principal, Quorum, Policy,
MutationProposal, CommittedMutation), and eventual world-model
records all share one substrate: rkyv-canonical, blake3-
addressed, schema-bound, with inter-record references as
`RecordId`. No category gets a special database; no category
opts out of content-addressing or schema validation. Rules
cross category boundaries under **layered datalog
stratification** — each record kind declares a stratum in its
`KindDecl`; rules may only read from strata ≤ their head's
stratum and write at their head's stratum. Criomed ships knowing
only the schema-of-schema plus the operational minimum plus the
code catalogue; new categories arrive as runtime-loaded
`CategoryDecl` + `KindDecl` records, not as criomed rebuilds.

## 2 · BLS-quorum authorisation

Sensitive mutations eventually require threshold BLS signatures
from a quorum of Principals. The proposal → signature-collection
→ commit lifecycle is modelled as sema records: `Principal` (id
+ 48-byte BLS12-381 G1 pubkey), `Quorum` (members + threshold),
`Policy` (resource_pattern + allowed_ops + required_quorum),
`MutationProposal` (proposer + payload + frozen required_quorum
+ payload_digest), `ProposalSignature` (one per signer,
accumulated as separate records so collection stays content-
addressed), and `CommittedMutation` (aggregate-sig + signer_set,
asserted atomically with the payload's effect when a seed rule
fires on threshold-met). Single-writer criomed serialises
signature submissions and makes the threshold-crossing revision
unambiguous. Library: `blst`. MVP runs single-operator with the
existing CapabilityPolicy + PrincipalKey sketch and no BLS at
all. Phase-1 introduces a hardcoded genesis quorum: criomed's
first boot seeds a `Principal` + `Quorum { threshold: 1 }` +
root `Policy` from launch configuration, and all later quorum
changes sign back to that genesis. Phase-2+ handles chained
rotation via `parent_quorum`, delegation with expiring sub-keys,
and external key custody.

## 3 · World-model data

Sema eventually holds world-model records for AI/agent
workflows, but only for the **symbolic slice**: `Entity` (with
explicit `identity_basis` separating entity identity from record
identity), `Relation` (n-ary RDF-style triples with Wikidata
qualifiers), `Observation` (sensor + timepoint + payload +
provenance), `Belief` / `Prediction`, `Frame` (spatial
scaffolding), `Action` / `ActionOutcome`, and catalogue records
for `Sensor` / `Actuator`. These live in a separate
`world-schema` crate, loaded via `CategoryDecl`. Bulk parametric
and dense data — camera frames, point clouds, NeRF weights,
Dreamer latents, `mjData` float vectors, audio segments — lives
in lojix-store, with metadata records in sema carrying
`StoreEntryRef` handles. Time-series firehoses (tf updates at
100 Hz, 30 FPS video ingest) stay out of sema entirely; an
external TSDB or Parquet-in-lojix-store handles them while sema
holds `ObservationSession` records pointing at the stream. World
records are read at runtime, never baked into code-closure
hashes — the two strata are hash-isolated so world churn cannot
invalidate compile caches. The named-ref table generalises from
`OpusRoot` to `EntityHead` via a `(namespace, name)` key.

## 4 · rustc diagnostic translation

When rustc rejects a build, lojixd parses the JSON output.
`Diagnostic.primary_site` maps to a `RecordId` via rsc's
reverse-projection span table; `level`, `code`, `primary_message`,
and children-prose become structured record fields. Secondary
spans, suggestions, and the recursive macro-expansion tree live
as an opaque rustc-JSON blob in lojix-store, referenced from the
`Diagnostic` record as `raw_rustc_json: StoreEntryRef`.
`DiagnosticSuggestion` records are emitted separately when
`applicability = MachineApplicable` so an `ApplySuggestion` verb
can find them without blob parsing. Since sema holds post-
expansion records only, macro diagnostics degrade gracefully to
"closest enclosing record" attribution via
`expansion.macro_decl_name`. The hybrid survives rustc's JSON
schema drift (the blob is the source of truth); the structured
projection covers the 80 % of queries — "which records are
unhealthy?", "error count per opus?", "errors in this Fn" —
that do not need the full blob. This is rust-analyzer's
`flycheck` posture applied to criomed.

## 5 · semachk (native Rust checker)

Eventually a native Rust checker inside criomed operates on
records directly, eliminating the rustc-as-derivation round-trip
for cheap phases. In order: schema validity and reference
validity (already required at criomed's mutation gate), module
graph + visibility, public-API signature-equality checks
(cargo-semver-checks shape), orphan-rule checking on
`TraitImpl` records, and unused/unreachable-item detection.
Each phase is weeks of focused work, runs purely over sema
records, and emits the same `Diagnostic`/`CompilesCleanly`
record kinds rustc's path produces (distinguished only by
`source: Rustc | SemachkPhaseN`). Trait solving follows later
via a `chalk-solve` + `chalk-ir` adapter; body-level typeck and
borrow-check stay in rustc forever (rust-analyzer's `hir-ty` is
still team-years of work and permanently diverges on GATs,
specialisation, and const-eval; polonius needs its own MIR
frontend). rustc is the oracle: every native phase ships with a
rustc-oracle test that records disagreements as reproducer
bugs. Precedents: rust-analyzer's `hir-def` / `hir-ty`, chalk,
polonius.

## 6 · Schema migration

When the schema shape (nexus-schema, criome-schema, or a
category crate) shifts, criomed needs to migrate old sema.
Strategy: **read-only fallback with an explicit `Migrate`
verb**. On open, criomed reads the sema's `SchemaVersion`
sentinel; mismatch with its own build opens the store read-only
and pushes a `RequiresMigration` event to subscribers. The user
runs `nexus-cli migrate`; criomed computes the migration chain,
applies it as a single Revision, writes a `MigrationRun`
evidence record, and bumps the sentinel. `Migration` records
carry steps as a variant: `AssertSchemaRecord` /
`RetractSchemaRecord` / `RewriteRule { source_pattern,
target_pattern }` / `RenameAttribute` / `DropAttribute` /
`SetDefault`. Derived analyses (`ProgramClause`,
`TraitResolution`, `InferenceResult`, `CompilesCleanly`,
`CompileDiagnostic`) are **never migrated** — criomed erases
them on upgrade and re-derives on demand, narrowing the
migration surface to user-authored records. Precedents:
Datomic's add-only schema discipline, PostgreSQL `pg_upgrade`,
Unison's explicit codebase-format version.

## 7 · Per-kind change log mechanics

Each sema record-kind owns a redb table `changelog::K` keyed by
`(SlotId, u64 seq)` carrying `ChangeLogEntry { rev, op,
new_content, old_content, principal, sig_proof }`. `seq` is
per-kind monotonic; `rev` is the global Revision counter,
assigned once per criomed writer transaction. A global
`rev_index: RevisionId → Vec<(KindId, SlotId, u64)>` table
supports cross-kind queries (all changes in a time window, all
changes by a principal). The `index::K` family of tables
carries per-kind current-state (`SlotId → IndexEntry`) as a
**derived view** over the per-kind logs — rebuildable at
startup by replay. Per-kind logs are the ground truth; every
other table is a cache. The per-kind split makes "history of
this `Fn`" a range-scan on slot prefix (rather than a filtered
scan over a global log), isolates high-churn kinds — future
`Observation` logs, at 10 Hz × N sensors, will grow independent
of code-kind logs — and lets per-kind retention and compaction
evolve without touching structural code history. Quorum-
authored changes set `sig_proof = Some(ref)` pointing at the
`CommittedMutation` record that proves the aggregated BLS
signature; routine single-author commits leave it `None`. The
per-kind log is the input substrate a differential-dataflow
engine can later consume for rule deltas.

---

*End report 060.*
