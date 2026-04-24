# 048 — per-kind change-log design — precedents, alternatives, concrete schema

*Claude Opus 4.7 / 2026-04-24 · P0.1 follow-up research. Li's
proposal: "Those changes live in a change log. Change logs
should be per-kind, to make lookups faster and logs more
manageable." This report stress-tests that proposal against
prior art (Datomic, PostgreSQL, Git, event sourcing, Kafka),
evaluates per-kind vs unified logs across seven concrete
scenarios, proposes a record-shape and redb schema, and flags
tensions with other architecture decisions in reports 033,
035, 036, 043, 046.*

---

## Part 1 — Precedents

**Datomic — single log, per-attribute index sort-order.**
Datoms `(e, a, v, tx, op)` live in one append-only transaction
log. Four live indexes — `EAVT`, `AEVT`, `AVET`, `VAET` — are
sorted trees over the entire datom population; `AEVT` clusters
same-attribute datoms by sort key, but storage is unified.
Hickey's justification: the log is ground-truth-of-time;
indexes are derived views. Splitting the log by attribute
would force cross-attribute transactions into distributed
commits, which Datomic's single-writer avoids. *The log is
durability and ordering; per-attribute access is an index
concern.*

**PostgreSQL — one WAL, one file per table.** Every mutation
writes to a single WAL (global LSN order). Each table's heap
lives in its own file. Crash recovery replays WAL against
per-table files in LSN order, restoring atomicity across
tables. **Partitioning physical storage does not require
partitioning the ordering substrate.** A single LSN clock
serialises cross-partition commits while per-partition files
keep locality.

**Git — one commit DAG, no per-file log.** Per-file history
is reconstructed by walking commits and diffing trees —
linear in commit count. Git's target (Linux) biases toward
whole-tree operations. Sema's target is the inverse: a
programmer cares about one `Fn`'s history; a rule firing on
`TypeAssignment` cares about that kind's deltas.

**Event sourcing — per-event-type topics common at scale.**
Fowler's canonical model is per-aggregate; production
systems (especially Kafka-backed) routinely split by event
type for independent retention, per-type consumers, and
smaller per-topic indexes. Trade-off: losing cross-type
total ordering.

**Kafka — per-topic, total order only within partition.**
Cross-topic ordering is not a primitive — applications that
need it synthesise a global clock via a single "transaction"
topic. Our proposal inverts this: a global Revision clock
exists, and per-kind logs are ordered sub-sequences of it.

**Synthesis.** Precedents either keep unified logs with
partitioned indexes (Datomic, Postgres) or partition logs
and drop total ordering (Kafka, event-sourcing-by-type).
Li's proposal is the Postgres pattern from a different
angle: per-kind tables *are* the log, a single Revision clock
preserves global ordering, and the "WAL" collapses into the
per-kind tables because records are immutable.

---

## Part 2 — Per-kind vs unified — scenario analysis

| Scenario | Per-kind | Unified |
|---|---|---|
| 1 · Single record edit | One append to one kind's log; O(1). | One append to global log; O(1). |
| 2 · "Who changed X last week?" | Range-scan over all kinds since watermark; N table-opens. | Single range-scan by Revision. Cheaper. |
| 3 · History of one `Fn` | Seek in `Fn`'s log to `slot`; linear in kind-local entries. **Much cheaper.** | Seek in global log filtered by `slot`; linear in global entries. |
| 4 · Changes by principal P across all kinds | N table-scans; union. | One scan filtered by `principal`. Cheaper. |
| 5 · Schema-mig rewrite of one kind | Write amplification contained to that kind's log. | Write amplification mixed into global log. Neutral-to-slight. |
| 6 · Crash recovery | redb replays each per-kind table independently; slight parallelism benefit. | redb replays one table; simpler. |
| 7 · Federation diff | Per-kind diff is fine-grained; can ship only changed-kind logs. | Whole-log diff; bigger payloads. |

**Lookup cost.** Scenarios 3 and 7 strongly favour per-kind.
Scenarios 2 and 4 strongly favour unified. Scenarios 1, 5, 6
are neutral. The split is along query shape: **per-kind wins
when the predicate is "kind = K"; unified wins when the
predicate is "time ∈ [T1, T2] ∧ kind = any".** For an
IDE-driven workflow — "show me this function's history"
dominates — per-kind is the correct primary index.

**Write amplification.** Under per-kind, a cross-kind
transaction writes to multiple tables, each append O(1). Total
writes equal the number of kinds touched. Under unified, one
append per record-changed regardless of kind. *Per-kind pays a
slight write-amp tax for cross-kind transactions* — one
extra table-open per kind touched. redb handles this well
(tables share the same WAL); the tax is measurement-visible
but not architectural.

**Storage overhead.** Per-kind tables carry some fixed
per-table overhead (a redb table header, a B-tree root, free
pages). For ~60–120 record kinds (the projected MVP schema —
see 033 Part 2), total overhead is ~120–240 redb pages or a
few hundred KB. Negligible.

**Consistency and ordering.** Per-kind preserves
within-kind total order (entries in kind K's log are in
Revision order within K). Across kinds, a **shared Revision
counter provides global total order** — you can always merge
two per-kind logs in Revision order to reconstruct the global
history. This is strictly weaker than a single physical
total order only if Revision assignment isn't atomic with log
append, which under criomed's single-writer is a non-issue:
the writer assigns Revision and writes to all touched kind-
logs inside one redb transaction.

**Implementation complexity.** Per-kind adds one layer of
indirection: "which table does this entry go in?" The kind is
known (every record carries its kind-id), so dispatch is
constant-time lookup in a `KindId → TableHandle` map. Simple.
Unified is marginally simpler (one table handle). The delta
is implementation minutiae, not architectural burden.

**Verdict.** Per-kind is the right primary index for sema's
query patterns, given (a) criomed's single-writer preserves
global ordering trivially, (b) the dominant IDE/agent query
shape is per-kind, (c) the overhead is a one-time schema
decision paid at criomed startup. Unified-query scenarios
(2, 4) remain cheap via a secondary index — see Part 3.

---

## Part 3 — Concrete per-kind log design

### The core entry

```
ChangeLogEntry {
    seq: u64,                  // per-kind sequence (0..)
    rev: RevisionId,           // global monotonic
    slot: SlotId,              // per 046/P0.1 index-indirection
    op: ChangeOp,              // Assert | Retract | Mutate
    new_content: Option<Hash>, // Some for Assert/Mutate; None for Retract
    old_content: Option<Hash>, // Some for Retract/Mutate; None for Assert
    principal: PrincipalId,
    sig_proof: Option<ProofRef>, // Some for quorum-authored changes
}
```

- `seq` is local to the kind's log. Zero-initialised when the
  kind first receives data; monotonic thereafter.
- `rev` is the global Revision. Under criomed's single-writer,
  all entries written inside one writer transaction share the
  same `rev`. Revisions are dense across the global log; they
  are **sparse** across any one per-kind log (a kind that
  didn't change in Revision R has no entry with `rev = R`).
- `slot` is the identity per report 046 §P0.1. Slots are
  opus-scoped; `SlotId` is globally unique under that scope.
  The slot is what you use to reconstruct "the history of
  this one `Fn`": seek to `slot = S` in the `Fn` kind's log
  and stream forward.
- `op` is a three-valued enum. `Mutate` is syntactic sugar for
  "Retract old + Assert new in one atomic entry" — important
  for reducing log volume on edits. Without a native `Mutate`,
  every content edit would generate two entries; with it, one.
- `new_content` / `old_content` are the content-hashes before
  and after. The entry is self-describing: given an entry,
  a reader knows the full before/after without consulting any
  index. This is the Datomic discipline — datoms are
  self-contained.
- `principal` and `sig_proof` carry audit identity. For
  routine single-author commits, `sig_proof = None` and the
  `principal` is the sole author. For quorum-authorised
  commits (report 035), `sig_proof = Some(ref)` points at a
  `CommittedMutation` record that carries the aggregated BLS
  signature and signer set.

### Storage layout in redb

**One table per kind, keyed by `(slot, seq)`:**

```
changelog::Fn              (SlotId, u64) → ChangeLogEntry
changelog::Struct          (SlotId, u64) → ChangeLogEntry
changelog::TypeAssignment  (SlotId, u64) → ChangeLogEntry
... one per kind ...
```

The `(slot, seq)` key gives `history_of_slot` as a range-scan
on the slot prefix. An optional secondary per-kind table
`changelog_by_rev::K : RevisionId → Vec<(SlotId, u64)>`
supports "all K-changes since rev R" — the Datomic EAVT vs
AEVT pattern at per-kind granularity.

**One global rev-index table:**

```
rev_index  RevisionId → Vec<(KindId, SlotId, u64)>
```

The cross-kind Revision view. Values are small integer
triples; the table is compact. This makes scenario 2 cheap
despite per-kind sharding — walk `rev_index` over a time
window, fetch entries from the per-kind tables.

**Optional per-principal index (Phase-1):**
`audit_by_principal : (PrincipalId, RevisionId) → Vec<(KindId, SlotId, u64)>`.
Derived and rebuildable; MVP skips it and filters `rev_index`
in memory.

### Where does the global order come from?

A single `u64` **Revision counter**, incremented once per
writer-actor transaction in criomed. Under single-writer
(architecture.md §3) there is no race: the writer assigns
`rev`, appends to every touched kind-log at that Revision,
updates `rev_index`, and commits the redb transaction
atomically. Readers at MVCC snapshot see all-or-none of
transaction R's entries. Per-kind `seq` is assigned by the
writer as `seq_{K,R} = last_seq_{K} + 1`.

### Audit log placement

**Embedded, not separate.** Each entry carries `principal`
+ `sig_proof` inline; the per-kind logs already contain every
mutation with its author. The `CommittedMutation` record
(report 035) is **not** a duplicate — it's a *proof* record
pointing *at* the log entry. The entry says "Revision R, slot
S, op Mutate, new-hash H, principal P, sig_proof → C". The
`CommittedMutation` says "aggregated BLS sig over the payload
is X, signers = {P1, P2, …}". The log is *what happened*; the
proof is *who authorised*.

### Derived current-state

The **index table** (per 046 §P0.1) lives in a third table
family:

```
Table: "index::Fn"      key: SlotId  value: IndexEntry
Table: "index::Struct"  key: SlotId  value: IndexEntry
...

IndexEntry {
    current_content_hash: Hash,
    display_name: String,
    kind: KindId,
    created_at_rev: RevisionId,
    updated_at_rev: RevisionId,
}
```

Every append to a per-kind change log updates that kind's
index table atomically in the same redb transaction. The
index tables are a **derived view** of the per-kind change
logs — rebuildable at startup by replaying each per-kind log.
Their own changes don't need a separate log; they're a
materialisation of the per-kind logs.

Point-in-time queries ("what was `Fn` X at Revision R?")
work by walking the per-kind log for X up to the first entry
with `rev > R` — the entry's `old_content` (or the prior
entry's `new_content`) is the answer. This is standard
bitemporal reconstruction; the index table only answers
*current*.

---

## Part 4 — Tensions with other decisions

**Global Revision vs per-kind seq.** No tension. Revision
is the global commit boundary; `seq` is the within-kind
density counter; one redb transaction assigns both.
Subscriptions by Revision or by kind+slot both index cheaply.

**Index-indirection.** The slot-ref model (046 §P0.1) is a
storage-layer construct, not a record kind. Its changes don't
need their own log — they're a deterministic consequence of
per-kind log appends and rebuildable at startup. Per-kind log
is source of truth; `index::K` is the cache.

**BLS-quorum authz.** Routine single-principal mutations need
no signature; `sig_proof = None` and criomed's local policy
check suffices. Quorum mutations set `sig_proof = Some(ref)`
pointing at a `CommittedMutation` record in that kind's own
log. Entry and proof are separate but linked.

**World-model high-churn kinds.** `Observation` at 10Hz × N
sensors generates tens-to-hundreds of millions of entries.
Per-kind isolation is **decisive**: (a) the `Observation` log
grows independently of code-kind logs, so code queries aren't
slowed by sensor data; (b) retention is per-kind —
`Observation` for 30 days, `Fn` forever; (c) schema migration
of one high-churn kind doesn't force a global rewrite. Mixing
code-rate and sensor-rate data in one log would be
architecturally painful.

**Per-rule materialisation.** Report 043 §P1.4's salsa-firewall
caches imply some analysis kinds are lazily materialised. For
lazy kinds, the change log is **sparse** — only demanded
subsets have entries. The log records what happened, and
nothing happens for never-demanded slots. Per-kind degrades
gracefully to lazy mode.

**Schema migration (046 §P2.3).** A schema change to kind K
re-derives `index::K` but **does not rewrite** the change
log — entries keep their original rkyv bytes; readers upgrade
the decoder. Incompatible kinds get a `Migration` record and
a read-only window. Per-kind makes migration per-kind by
construction.

---

## Part 5 — Recommendation

**Adopt per-kind change logs as the primary storage substrate
for sema mutations.** Each record-kind owns a redb table
keyed by `(slot, seq)` with `ChangeLogEntry` values. A global
`rev_index` table provides the cross-kind Revision view
without duplicating content. The `index::K` family of tables
holds per-kind current-state — a derived view of the per-kind
logs, rebuildable at startup.

### Schema sketch

- Per kind K in the schema catalogue:
  - `changelog::K : (SlotId, u64) → ChangeLogEntry`
  - `index::K : SlotId → IndexEntry`
- Global tables:
  - `rev_index : RevisionId → Vec<(KindId, SlotId, u64)>`
  - `kind_registry : KindId → KindMeta` (for dynamic dispatch)
- Optional (Phase-1):
  - `audit_by_principal : (PrincipalId, RevisionId) → Vec<(KindId, SlotId, u64)>`

### Audit log placement

Embedded in each `ChangeLogEntry` as `principal` + `sig_proof`.
No separate audit table at MVP; `rev_index` + in-memory
filtering covers the rare "all changes by P" query until
Phase-1 adds the derived index.

### Cross-kind queries

- **By revision** → `rev_index` range-scan → entry fetches.
- **By principal** → `rev_index` scan + filter (MVP) or
  `audit_by_principal` direct lookup (Phase-1).
- **By slot within kind** → `changelog::K` range-scan on
  slot prefix. Cheap.
- **By kind + time window** → `changelog_by_rev::K` (a
  per-kind secondary index on `rev`) if the query is hot;
  `rev_index` + kind-filter otherwise.

### What to defer to post-MVP

- `audit_by_principal` derived index. Not needed for a solo-
  developer workspace; easy to add when multi-principal
  scenarios arrive.
- `changelog_by_rev::K` per-kind rev-index. Start with just
  `(slot, seq)`; add `rev`-index per kind only if profiling
  shows scenario-2-style queries are hot.
- Per-kind retention and compaction policies. Not needed
  until world-model records land; structural code records
  don't need expiry.
- Cross-instance federation-diff format. Keep it to "two
  instances can compare per-kind logs by hash" until
  federation is a concrete user story.
- DBSP-style rule deltas (report 022, 043 §P1.4). The per-kind
  log is the input substrate for a differential-dataflow
  engine when we land it; MVP reads entries with naïve
  re-compute.

### Design invariant

**The per-kind change log is the ground truth; every other
table is a derived view.** `index::K` is derivable from
`changelog::K`. `rev_index` is derivable from every
`changelog::K`. `audit_by_principal` is derivable from
`rev_index` + entry lookups. Derived tables are rebuildable
at criomed startup — a corruption-recovery path that's
architecturally robust.

This matches Datomic's discipline (the log is ground truth;
indexes are maintainable views), the Postgres pattern (WAL is
durable; heap files are per-table locality wins), and Git's
DAG-as-truth principle — with the sema-specific twist that
*ground truth is also partitioned by kind*, trading a small
cross-kind-ordering workload (the `rev_index` update) for
large per-kind-query wins.

---

*End report 048.*
