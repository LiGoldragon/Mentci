# 047 — slot-id design research: what IS a sema slot?

*Claude Opus 4.7 / 2026-04-24 · P0.1 refinement. Evaluates Li's
concrete proposal — incrementally increasing integer slot-ids
with a freelist, optionally mapped to a generated enum whose
variant names carry composite display names — against Datomic's
`eid`, PostgreSQL `oid`, Git refs, Linux inodes, Ethereum
storage, and Unison. Recommends `Slot(u32)`, a record-backed
freelist, rsc-generated per-opus enums, compiled-in seed slots
in a reserved low range, and a Phase-2+ partition scheme for
federation.*

---

## Part 1 — The integer-slot with freelist

### Width

Self-hosting at MVP: nexus-schema records (report 004's
inventory) produce ~500 declaration-level items (structs,
enums, fns, traits) in the engine's own code; plus ~10-50×
that in body-level sub-records (Expr, Statement, Pattern,
Type). The body-level records do **not** need slots: they are
referenced structurally by hash as subtree children of
declaration records. Slots only exist for items that can be
named, renamed, or referred to across record boundaries — i.e.
the "top of the tree" for each logical item.

A reasonable upper bound for the self-host subset: **~50k
slots**. A medium Rust workspace the size of rustc itself might
push toward 500k declared items. `u32` gives 4.3 billion — four
orders of magnitude more than any foreseeable single-criomed
workspace. **Lean: `struct Slot(u32)`.**

Why not `u16`: 65k runs out at rustc-scale for sure, and leaves
no headroom for reserved ranges (seed slots, future partition
prefixes).

Why not `u64`: doubles storage cost per reference with no
plausible benefit. rkyv `Archive` on `u32` is 4 bytes aligned;
on `u64` it's 8. Every reference site (potentially hundreds of
thousands in a large workspace) pays.

### Monotonic allocation under single-writer criomed

Single-writer simplifies allocation dramatically. Criomed holds
a `next_unused_slot: u32` counter plus a freelist. Allocation
order:

1. Pop from freelist if non-empty (LIFO or FIFO; doesn't
   matter structurally).
2. Otherwise take `next_unused_slot` and increment.

Both paths are serial under criomed's single-writer
discipline. No CAS, no generation counters — the writer just
holds a mutex on the allocator.

### Freelist representation

Two candidates:

(a) **A redb table inside the same database as sema**, keyed
    by slot-id, values empty (a set). On free: insert. On
    allocate: pop any.
(b) **A sema record kind** — `FreeSlot { id: Slot,
    freed_at_rev: RevisionId, freed_by_verb: VerbKind }`.
    Allocation retracts a `FreeSlot` and asserts the
    allocation somewhere.

Lean **(a) redb table**, for three reasons:

1. The freelist is pure index state — mechanical bookkeeping
   sitting alongside the slot→content-hash index table. Making
   it a record kind promotes bookkeeping to first-class sema
   content, which bloats the history log (every alloc writes
   two records; every free writes one).
2. The index table (P0.1's `slot → { current_content_hash,
   display_name, … }`) is already a redb table; the freelist
   lives in the same db, same transaction boundary.
3. Historical queries don't need the freelist — they need the
   *index's* past state, which is covered by sema's bitemporal
   log (see §1.3 below).

### Slot reuse and historical queries — the "slot 42 was Foo
then Bar" problem

The worst-case narrative: slot 42 held `Foo` at revision R1;
`Foo` was retracted at R5; slot 42 was freed at R5; at R7, a
new `Bar` allocated slot 42; a query against R3 asks "what's
at slot 42?" and must answer "Foo", not "Bar".

This is a solved problem under bitemporal records. The index
table is **versioned by revision** — every write to
`slot_index(42)` produces a new entry in the index's own
assertion log. Query at revision R3 reads `slot_index(42) as
of R3` and gets `{ content: hash-of-Foo, name: "Foo" }`. Query
at R7 gets `{ content: hash-of-Bar, name: "Bar" }`. The slot
integer is reused; the per-revision binding is not.

Concretely this means the index is **not a single redb table
keyed by slot**; it's a redb table keyed by `(slot, revision)`
with a current-row accelerator. Or — the cleaner phrasing —
the index **is** a record kind: `SlotBinding { slot: Slot,
content_hash: ContentHash, display_name: CompositeName,
valid_from: RevisionId, valid_to: Option<RevisionId> }`. The
"current-state" accelerator is a redb table keyed by slot
pointing at the latest `SlotBindingId`; historical queries
walk the SlotBinding records.

**Slot reuse does not break historical queries under this
scheme.** It would break a naive "slot → current-hash" redb
table with no history, which is why we keep history in sema
records and redb is a materialised current-state cache.

### Precedents checked

**Datomic `eid`.** Partition-aware 64-bit integer: high bits
select a partition (`:db.part/user`, `:db.part/tx`), low bits
are a monotonic counter within that partition. Post-excision
IDs are reused after a compaction. Core lesson: partition
prefix in the high bits of the integer is a cheap
federation/sharding primitive (see Part 4). Datomic doesn't
expose a freelist; excision is the closest analog. Slot reuse
is fine because Datomic's fact log is also bitemporal —
`[eid attr value tx op]` at `tx=R1` vs `tx=R7` are independent
facts.

**PostgreSQL `oid`.** 32-bit, global, wraparound. The pain
point: wraparound happened at ~4 billion, and reused OIDs
collided with still-live ones when tables weren't vacuumed.
Several Postgres versions ago `oid` was removed from most
tables and marked as legacy. Lesson: a freelist + explicit
allocation boundary (not passive reuse on wraparound) is
necessary. We're fine here because we explicitly free and
explicitly reuse; no silent wraparound.

**Git refs vs object hashes.** Git refs are name → hash; hashes
are immutable. A "ref = integer" variant would be Git with
integer branch names — mechanically equivalent, aesthetically
worse. The actual lesson is the **layer separation**: refs are
mutable, objects aren't. Our slot-index is the refs-analog;
content hashes (the record payloads under each slot) are the
objects-analog. This report cements that layering.

**Linux inodes.** Int + freelist, 32-bit historically, 64-bit
on modern filesystems. Scale problems hit at:
 - Wraparound exhaustion on small filesystems (fixed by 64-bit).
 - `nlink` races between free and reuse (fixed by
   filesystem-level transactions).
 - Backup/restore assumptions that inode numbers are stable
   (broken by restore-to-new-fs).
We avoid all three: 32-bit is ample for our scale (well below
the wraparound regime); criomed is single-writer (no races);
backup = dolt/jj of the whole sema db, so inode-numbers-aren't-
stable-across-backups maps to "slot-ids aren't stable
across sema db clones."

**Ethereum storage slots.** 256-bit addresses per contract,
because a contract's storage is keyed by hash-derived slots
for map-style indexing. Totally different design point —
contract storage is *addressed* by hash of key material, not
assigned by a central allocator. Not applicable.

**rkyv on small ints.** `u32` archives to 4 bytes, aligned.
`struct Slot(u32)` with `#[derive(Archive)]` zero-copy-
deserialises trivially. Reference sites inside stored records
carry 4 bytes; at ~500k reference sites in a large workspace,
that's 2 MB of slot-ref overhead total — comfortably in the
noise.

---

## Part 2 — The enum-mapping idea

### Who owns the enum

Li's three candidates:

**(a) rsc generates it at projection time, per-opus.**
When rsc emits `.rs` for opus O, it also emits
`pub enum SemaSlot { /* only O's slots */ }`. Each opus sees
only its own slot range. Cross-opus references become
`SemaSlot_OtherOpus::name` via re-exports.

**(b) A single shared global enum generated from sema.**
Every slot ever allocated anywhere appears as a variant.
Grows without bound.

**(c) A manually-maintained Rust enum that sema validates
against.** Humans edit a hand-written `SemaSlot` enum; criomed
rejects any mutation that doesn't match the enum. Rejected —
requires human labor at every allocation; doesn't scale.

**Lean (a), rsc-generated per-opus.** Rationale:

 - **Locality.** A rustc-facing `.rs` projection only needs
   the slots referenced in *that opus's* rendered code. Slots
   from unrelated opera are noise.
 - **Size.** Option (b) produces an enum with millions of
   variants over time; rust-analyzer and rustc both choke on
   enums with >~10k variants. Option (a) bounds the enum to
   the per-opus slot count (~hundreds to low thousands).
 - **Incremental regeneration.** An edit in opus O
   regenerates O's `SemaSlot`. No other opus's generated code
   changes. This mirrors how rsc already works (report 026 §3)
   — per-opus projection.
 - **Cross-opus references become first-class.** Just like
   Rust itself, cross-crate references name the crate:
   `other_opus::SemaSlot::Thing`. This maps directly onto the
   existing Rust mental model.

### Display name in the enum

The proposal is that the enum's variant name *is* the display
name: `SemaSlot::shapeOuterCircle = 42`. This makes the
display-name the load-bearing text identifier for Rust code
that references the slot.

**Who computes the composite name?** Lean: **the ingester at
slot-creation time.** The ingester knows the module path, the
item name, and (if needed) a disambiguating suffix for
duplicates. The composite is a deterministic function of
`(module_path, item_name, disambiguator)`; store it as the
`display_name` field of the slot binding.

Rejected: criomed computing it. Criomed doesn't see module
paths directly — it sees record trees. The name-composing
logic belongs where the source-text context exists (ingester
on ingest; user on direct-record creation).

Rejected: rsc computing it at projection. rsc's job is
records → text; computing composite names at projection
requires rsc to know about every slot's origin, which it
doesn't. It projects *from* stored display-names; it doesn't
generate them.

### Rename story

Two layers change on a rename:

1. **Index-layer (cheap).** The slot's `display_name` field
   updates in the SlotBinding record. The slot's
   `current_content_hash` is unchanged.
2. **Rsc-projection-layer (text-only).** Next time rsc
   projects the opus, it emits
   `SemaSlot::shapeRenamedCircle = 42` instead of
   `shapeOuterCircle = 42`. Any generated Rust file that
   referred to `SemaSlot::shapeOuterCircle` now emits
   `SemaSlot::shapeRenamedCircle` — rustc sees consistent
   names.

**Stored records carrying slot 42 are untouched.** The rkyv
bytes at rest don't move. This is the win of the
index-indirection design.

### Problems with the rsc-enum approach

**Rust code using `SemaSlot::X` literals unstable across
regenerations.** If an agent writes human-facing Rust code
referring to `SemaSlot::shapeOuterCircle` literally in a
comment or a string, and the slot is renamed, the literal
breaks. But this failure mode already exists for any
codegen — you can't hand-write code that references an enum
variant and expect the variant to stay named that way.
Mitigation: `SemaSlot` variants are an internal codegen
artifact; human-authored Rust code addresses records by
name through the nexus-schema API, not through `SemaSlot`
literals. If a human wants to refer to "slot 42
specifically", they refer to it by the composite name; if
the composite name changes, their code's semantic meaning
changed by definition.

**`use sema::SemaSlot::*;` blanket imports.** Post-MVP
concern. At MVP rsc can emit explicit variant uses; blanket
globs can be a later ergonomic. Don't over-engineer.

**Enum variant name collisions.** If two items in the same
opus produce identical composite names (e.g., two modules
both having a `new` fn and the disambiguator missing), the
enum has a compile error. Ingester responsibility: the
composite-name algorithm must guarantee uniqueness within an
opus. Pascal-namespacing by module path is the simplest
sufficient discipline (`shapeOuterCircle` encodes `shape`
module + `OuterCircle` item; `queueOuterCircle` lives in a
different module and doesn't collide).

---

## Part 3 — Seed slots

Some slots must exist at cold-start before any user mutation:

 - Schema-of-schema records (StructSchema, EnumSchema, etc.
   from report 033 Part 2).
 - Seed rules (P1.5's compiled-in `SEED_RULE_IDS` allowlist).
 - The `SchemaVersion` sentinel (P2.3).
 - The root `Quorum` record if BLS-authz is enabled
   (report 035).

These need **stable slot-ids across criomed rebuilds**, because
rkyv-stored references to them (in other records, in generated
code, in external tooling) must resolve identically on every
criomed startup.

### Mechanism

**Reserve the low range `[0, SEED_SLOT_MAX)`.** Lean:
`SEED_SLOT_MAX = 1024`, allocated at the top of the criomed
source as a `const`. Every seed slot has a compiled-in
assignment: `const SLOT_SCHEMA_OF_SCHEMA_STRUCT: Slot = Slot(0);`
and so on. The first-boot initialisation code writes these
seed bindings into the index; subsequent boots verify them.

**User allocations start at `SEED_SLOT_MAX`.** Criomed's
`next_unused_slot` counter initialises to `SEED_SLOT_MAX` on
fresh-database creation. The freelist never hands out IDs
below that range.

**Collision protection.** The slot allocator must refuse to
mint any slot < `SEED_SLOT_MAX` from the freelist or the
counter. User mutations that explicitly specify a slot-id
(rare — most mutations don't specify, they let the allocator
choose) are rejected if the specified slot is in the reserved
range.

**Verify-on-startup.** At criomed boot, the seed-slot bindings
are checked against the compiled-in expectations. If a seed
slot is missing or its content-hash doesn't match the
compiled-in seed record, criomed re-asserts the seed record
(which may trigger a cascade) and logs a warning.

### Precedent

Matches:
 - Unix fd 0/1/2 reserved for stdin/stdout/stderr.
 - Ethernet MAC `00:00:00:00:00:00` reserved.
 - IP ranges 0.0.0.0/8, 127.0.0.0/8 reserved.
 - PostgreSQL system catalog OIDs < 16384 reserved for
   system tables.

The discipline is old and well-understood. 1024 is arbitrary
but comfortable — we'll have ~50-100 seed records at most
(schema-of-schema + seed rules + a few sentinels); 1024 leaves
10× headroom.

---

## Part 4 — Distributed / BLS-quorum interactions

### BLS-quorum authz for slot allocation

Is a slot allocation a quorum-gated operation? **No, at least
not directly.** Slot allocation happens as a side-effect of
asserting a new record — the mutation verb that carries the
record payload is what goes through authz. The allocator hands
out a fresh slot to the committed mutation. If the mutation
is rejected at the authz gate (insufficient signatures), no
slot is allocated.

Sharper framing: **slots are allocated to committed records,
not to proposed records.** `MutationProposal` records (report
035 Part 2) carry payloads that, if applied, would require new
slots. The allocator is invoked only when the proposal's
quorum threshold is met and the payload commits. A rejected
proposal consumes no slots.

This preserves the "slot allocation is trivial local
operation" property. The quorum gate sits upstream of the
allocator.

### Federation: multiple criomed instances

Phase-2+ concern. Single-writer is the MVP invariant.

When federation arrives, two shapes are plausible:

**(i) Partition-prefixed slots (Datomic-style).** Reserve the
high 8 bits of `u32` for a partition/origin ID; each criomed
instance allocates within its own partition. Slots are
globally unique by construction; no cross-node coordination
needed. Cost: `u32` shrinks to 24 bits of per-partition slots
(~16 million), which is still fine for any single node.
Alternatively, move to `u64` at federation time — that's a
schema migration, but a mechanical one (zero-extend the high
bits on all existing slots during the migration).

**(ii) Consensus-based allocation.** All federated criomeds
agree on each allocation via a BLS-quorum vote or Raft-style
log. Slower; requires coordination per allocation; couples
federation to authz protocol.

**Lean (i) for Phase-2+.** Datomic's precedent is persuasive;
the coordination-free property preserves single-node
allocation performance; BLS-quorum's record-layer
responsibilities (which record commits, who signed) stay
orthogonal to slot numbering.

At MVP this whole section is deferred. The MVP invariant:
one criomed, one allocator, slot-ids are local to that
criomed's sema database.

---

## Part 5 — Final recommendation

### Slot-id type

```
struct Slot(u32);
```

Newtype. `#[derive(Archive, Serialize, Deserialize)]` for rkyv.
Lives in `nexus-schema`. 4.3B slots per workspace; 4 bytes per
reference.

### Slot index

Stored as **record kind** `SlotBinding`:

```
SlotBinding {
    slot: Slot,
    content_hash: ContentHash,
    display_name: CompositeName,
    valid_from: RevisionId,
    valid_to: Option<RevisionId>,
}
```

Plus a redb materialised view `slot → current_SlotBindingId`
for O(1) current-state lookup. Historical queries walk the
record log.

### Freelist

Plain redb table inside criomed's sema db. Not a record kind.
Two operations: `freelist.pop() -> Option<Slot>` and
`freelist.push(slot)`. Invariant: no slot below
`SEED_SLOT_MAX` ever enters the freelist.

### Enum mapping

**rsc-generated, per-opus.** Each opus's projected `.rs`
includes a `pub enum SemaSlot` whose variants are the opus's
slots, named by their `display_name`, integer-valued by slot
id. Cross-opus references go via `other_opus::SemaSlot::Foo`.

Composite names computed by the **ingester** at slot-creation
time, stored in the `SlotBinding.display_name` field.
Algorithm: `camelCase(module_path_segments) + PascalCase(item_name)
+ optional_disambiguator`.

### Seed slots

Reserved range `[0, 1024)`. Compiled-in `const` declarations
in criomed for every seed slot's ID. First-boot init writes
seed bindings; subsequent boots verify and re-assert if drift
detected. User allocations start at 1024.

### Distributed roadmap

Deferred to Phase-2+. Lean partition-prefix scheme when
federation lands: high 8 bits = partition/origin ID, low 24
bits = per-partition counter. Each criomed allocates in its
own partition; no cross-node coordination. Migration from
MVP single-partition to multi-partition is mechanical (all
existing slots get partition 0).

### What's landed vs deferred

Landed (spec-ready):
 - `Slot(u32)` type
 - `SlotBinding` record kind
 - redb-backed freelist
 - Seed-slot reserved range
 - Per-opus rsc-generated `SemaSlot` enum
 - Ingester owns display-name composition

Deferred (Phase-2+):
 - Federation / partition-prefix widening
 - BLS-quorum signatures inside slot allocation (signatures
   stay at the MutationProposal layer, per report 035)
 - Mid-flight rename visibility to held SlotBinding history

---

*End report 047.*
