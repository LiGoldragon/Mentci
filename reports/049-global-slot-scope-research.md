# 049 — global slot scope research — auditing Li's "absolute object identity" choice

*Claude Opus 4.7 / 2026-04-24 · deep research on Li's decision
to make sema's slot-id space global (not opus-scoped). Audits
the implication across Opus identity, cross-opus dependencies,
Rust crate boundaries, the ingester, rsc projection, federation,
BLS-quorum authz, and world-model records. Recommends the choice
stands and proposes concrete plumbing. Supersedes P0.1 sub-
question 2 in report 046 (which leaned opus-scoped).*

Li's direction (2026-04-24):

> I think global is better; then we create the right abstraction
> from the beginning, where an object is referred to absolutely.
> When represented in rust, it would use its opus-local
> name-field.

---

## Part 1 — What "global" means concretely

Under the index-indirection model from 046 §P0.1, every record
stored in sema refers to other records by **slot-ref**, not by
name and not by content-hash. The slot-ref is a stable handle;
the index table holds the mutable `slot → { current-content-
hash, … }` mapping. The open sub-question was whether slot-ids
live in a **per-opus namespace** (each opus mints its own slot
sequence, and `slot 42 of opus A` is unrelated to `slot 42 of
opus B`) or a **single global namespace** (slot 42 means the
same thing everywhere sema holds a reference to it). Li's
direction: global.

Three operational consequences:

- **Single minting authority.** Slot-ids come from one sequence
  administered by criomed (MVP) or a quorum of criomeds (post-
  MVP). There is no `(opus, slot)` tuple at reference sites;
  there is just `slot`.
- **Shared sema content across opera.** If opus A and opus B
  both depend on the same `Fn resolve_pattern` record, they
  literally reference the **same slot**. Deduplication is
  structural, not negotiated. The same `Struct Point`
  declaration can appear in both opera's reachable-closure
  without being stored twice.
- **Opus-local names are a display layer, never an identity.**
  Each opus's view of a given slot carries its own `name` field
  — for Rust projection, for human reference, for
  `use crate::foo::Bar`-style paths. Renaming a slot in opus A's
  view does not touch opus B's view of that same slot; the
  slot's identity is absolute, its Rust-visible name is
  per-opus. This is the Datomic `eid` pattern pushed down one
  level: eid-keyed identity, opus-scoped keyword-ident.

Under opus-scoping, a "shared library `serde`" is ingested
twice (once per depender) and its `Serialize` trait becomes two
unrelated slots. Under global, `Serialize` is one slot,
referenced from every opus that uses it. Cleaner mental model
for what sema already is: a content-addressed semantic store.

---

## Part 2 — Implications across architectural concerns

### Opus identity

An `Opus` record (report 017 §1) lists its members: root
`ModuleId`, dep graph, toolchain pin, target, profile, features,
rustflags. Under global slots, an opus's members are slot-refs
to content that may also be members of other opera. The opus's
content hash captures *which slots* are members, *what toolchain
and flags* compile them, and *what names* this opus uses locally
— **not** the current content-hash of each member. When a
referenced slot's current-content-hash changes, the cascade
fires via index subscription (046 §P1.4) but the opus record
itself is stable. Opus identity = "membership + toolchain", not
"membership + bytes". Matches the cargo/nix intuition: recipe is
stable, outputs move.

Global makes "two opera share a member" first-class rather than
a deduplication artefact. The reverse-index query "every opus
depending on `Fn X`" is an O(opera-touching-slot) lookup, not a
workspace-wide scan.

### Cross-opus dependencies

Report 017 §1 specifies `OpusDep { target: OpusId, as_name, … }`.
Under opus-scoping, A reaches B's content only through named
re-export paths, mirroring Rust's `extern crate`. Under global
slots, A's records reference B's slots directly; the `OpusDep`
supplies the visibility contract but the underlying references
use the same slot-ref mechanism they use intra-opus.

Cleaner than Rust's `use` machinery because the "import" resolves
at slot-level, not at path-level. Whatever B calls `Serialize`,
A can call locally anything; both views end at the same slot;
rsc still emits idiomatic `use serde::Serialize;` in the
projection by walking B's module tree with B's local names.

### Rust crate boundaries

Rust enforces `pub`, `pub(crate)`, `pub(super)`. Under global
slots, visibility is not a property of the slot — it's a
property of the *opus's exposure of the slot*. The existing
`Visibility` record (report 004) already points that way: it
annotates a declaration, not an identity. Each opus carries
`members: Vec<MemberEntry { slot, local_name, visibility, kind
}>`; the same slot could be `pub` in A and `pub(crate)` in B if
both expose it (rare but representable). rsc's projection matches
Rust semantics exactly; nothing new at the rustc interface.

### Ingester (report 042 P0.3)

This is where global slots earn their keep. When the `syn`
ingester processes opus A and encounters `serde::Serialize`, it
either reuses an existing slot (found via the workspace-wide
name index — populated when serde was ingested as opus B) or
mints a new one. Under opus-scoping every ingest mints fresh
slots per opus; sharing is impossible at the sema layer, and
post-hoc dedup by content-hash join can't bridge slot-refs.

Under global, the ingester's canonicalisation step is exactly
what r-a's `DefId` interning does (per 042 precedent): one slot
per semantic identity, minted once, referenced many times.

The "two crates both have a `fn parse`" collision is a
non-issue: names aren't identity. Each `parse` gets its own slot
because the ingester resolves by *import path*, not by *name*.
It merges only when the referring site resolves via `use
crate-x::parse` to an existing slot. Opus-local name-fields
disambiguate in rsc output. Global slot identity is cleanly
orthogonal to name collisions.

### rsc projection

rsc still prefixes names per module/crate; it uses the
opus-local name-field as source of truth. On a slot-ref inside
opus A:

1. Index lookup → defining opus (a slot has one defining opus —
   the one that first declared it) and current-content-hash.
2. Opus A's `MemberEntry` for the slot → A's local name.
3. If defined in another opus B, rsc emits
   `b_as_name::path_to_slot` walking B's module tree with B's
   local names.

The span-table (report 026 Q2) maps `(line, col) → (opus, slot,
sub-record position)`; reverse-projection is unchanged.

### Federation — post-MVP

Multiple sema instances are where global slot-id must earn its
keep a second time. Two criomeds minting from overlapping
integer sequences collide on slot 42. Two options:

- **Partition prefixes.** Each criomed gets an instance-id
  (derived from its root pubkey). Slots become `(instance_id,
  local_seq)`. Within one instance this is the current global
  space; across instances no collision by construction.
- **Content-address the slot.** Slot-id = blake3 of the
  first-content-hash at birth (aligns with 046 §P0.1
  sub-question 1's "birth-hash" lean). 256-bit space; collision
  probability across peers is cryptographically negligible.
  Subsumes partitioning.

MVP (single criomed) works with either. Birth-hash is the
cleaner bet because it aligns with the rest of sema's
content-addressing posture.

### BLS-quorum (report 035)

Multi-peer slot minting would otherwise become an N-of-M
signature event. Partition prefixes sidestep this (each peer
mints in its own sub-namespace). Birth-hash sidesteps it more
cleanly (minting is content-derived, no authority required). For
MVP with one criomed, minting is a local write under BLS-quorum
the same way any sema mutation is — no extra machinery.

### World-model records (report 036)

Global slots fit symbolic world-model content: an `Entity {
kind: RobotHand, serial: … }` minted by one sema gets a slot;
any other opus or system referencing that physical object
converges via serial-number-as-identity-basis. Cross-system
sharing of "this is the same hand" is the natural read.

Edge case: an `Observation { agent, at, content }` is specific
to one agent at one moment. It still gets a global slot (fine —
observations are first-class, referenceable), but the semantics
of "belongs to this agent" live in the record's fields, not in
the slot's identity. Standard RDF/SPARQL reification pattern.

---

## Part 3 — Risks and mitigations

**Collision under multi-peer writes.** Direct risk under naive
integer sequences. Non-issue for MVP (single criomed).
Post-MVP: birth-hash slot-ids or partition prefixes; either
eliminates collision.

**"Too shared" renaming risk.** The worry: if a function
renamed in opus A appears renamed in opus B because they share
the slot. Li's resolution is exactly right — the name lives on
the *opus's reference to the slot*, not on the slot itself.
Opus A renames its local view; opus B's view is unchanged. No
sharing risk exists because names were never the shared thing.
(This is the "Datomic keyword-ident is not identity" lesson.)

**Deletion / GC semantics.** Under global scope, "opus A
retracts its reference to slot 42" is a reachability update in
the index; if no opus still references 42, the slot is
eligible for GC sema-wide. The index tracks reachability
per-slot (a refcount, or a full reverse-index query at GC
time). GC is bounded and well-defined. Under opus-scoping, the
equivalent is "opus A's copy of slot 42 is unreferenced";
sema-wide GC would miss cross-opus identical content (kept
alive by opus B even though A retracted). Global is strictly
simpler.

**Import semantics.** "Does `use crate::foo::Bar` in opus A map
to the Bar defined in opus B?" Yes — the ingester's resolver,
when it sees the `use` path, walks the module tree *of the
opus that declares Bar*, finds the slot, and emits opus A's
reference to that slot. The `OpusDep` carries the visibility
contract; the slot is the identity. This is *exactly* how r-a
`DefId` resolution works across crate boundaries today, just
with content-hash-derived IDs instead of salsa-interned ones.

**Two crates with identical `fn parse`.** As noted above, each
gets its own slot because the ingester resolves by
*import-path*, not by *name-of-fn*. Two independent `fn parse`
declarations in unrelated crates are two separate slots; opus-
local name-fields disambiguate in Rust output. The concern
collapses.

**Cross-opus coupling surface.** The worry: global slots make
every opus a potential consumer of every other opus's edits.
This is mitigated by: (a) cascade firewalls (046 §P1.4 — only
the slots an opus actually references trigger re-derivation
for that opus); (b) `OpusDep` as the explicit visibility gate
(an opus can't reach slots not exposed via its dep graph).
Global *storage* doesn't imply global *reachability*.

---

## Part 4 — Comparison with Rust's crate system

Rust's crate boundaries do three things: namespace isolation,
compilation unit isolation, and distribution unit isolation.
Under global slots:

- **Namespace isolation** is preserved by opus-local name-fields
  and by `OpusDep`'s visibility gate. The Rust programmer's
  view through rsc is unchanged: `serde::Serialize` is a path
  through two opera, not a global keyword.
- **Compilation unit isolation** is preserved by cargo-as-
  derivation: each opus still compiles to its own `.rlib` /
  `.so` / `.bin`; rustc doesn't know or care that sema's
  storage is global.
- **Distribution unit isolation** is preserved by `OpusDep`'s
  explicit dependency declaration and by the content-hash of
  each opus. An opus is still a redistributable unit.

Nothing in Rust's crate-system contract breaks. What changes is
*sema's internal representation* — which is exactly the thing
Li is asserting should be the right abstraction from day one.
The opus-scoped alternative would have introduced a "crate-
boundary" artefact into sema's storage layer that has no
corresponding constraint in semantics. Global is the more
principled choice.

---

## Part 5 — Recommendation

**Confirm Li's choice. Global slot scope is sound and preferable
to opus-scoped.** The opus-scoped lean recorded in 046 §P0.1
sub-question 2 should be withdrawn in favour of this report's
conclusion.

### Concrete plumbing

**Slot minting (MVP).** criomed owns a single `next_slot`
counter in the sema redb, incremented under a write transaction
whenever a mutation introduces a new semantic identity. The
ingester's resolver is the primary caller: when translating
a `syn::Item` it either (a) finds an existing slot via the name-
index and reuses it, or (b) requests a fresh slot from criomed
and caches the mapping for the rest of the ingest pass. Every
slot-mint is an `Assertion` inside the current `Revision`; the
revision log therefore captures the full minting history, and
"undo" is a Retract-slot that releases the id.

**Slot identity shape.** For MVP, `Slot(u64)` — a plain counter.
For post-MVP federation readiness, migrate to `Slot(Blake3)` —
the birth-hash of the record that first occupied the slot. This
migration is mechanical (a Migration record per report 044
§P2.3) because slot-refs are stored at reference sites as an
opaque typedef; widening the underlying type is a schema-bump,
not a semantics change.

**Opus-local name field storage.** Each opus carries a
`members: Vec<MemberEntry>` where `MemberEntry { slot,
local_name, visibility, kind }`. This is a per-opus table
(small — on order of the opus's directly-declared items).
Renaming updates only this table. The index has a *canonical*
name-field per slot (the name at the slot's defining opus); the
per-opus `MemberEntry` is the view-layer override. rsc picks
the right name by walking from the referring opus down: if the
opus has a `MemberEntry` for the slot, use its `local_name`;
otherwise fall back to the defining opus's canonical name.

**Cross-opus reference rendering.** When rsc renders a slot-ref
in opus A's projection:

1. If the slot is A-local (defined in A), render with A's
   `local_name`, no path prefix.
2. If the slot is B-local (via an `OpusDep { target: B,
   as_name: "b" }`), render as `b::path_to_slot` where
   `path_to_slot` is walked in B's module tree using B's
   `local_name`s.
3. If the slot is std-local (per 042 P0.3's hand-curated
   well-known map), render as `std::option::Option`-style.

No new Rust semantics; the `use` emission layer is where this
all gets normalised into idiomatic imports.

**First post-MVP concern.** Federation prefixing. The moment a
second criomed becomes relevant (whether for multi-machine
development, CI sharing sema state, or eventual multi-tenant
deployment), the slot-id space must be partition-safe. Leaning
toward **birth-hash slot-ids** as the migration target — it
aligns with content-addressing and makes federation a non-event
at the storage layer. BLS-quorum (report 035) then governs
*trust* (which peer's mints are canonical for which domains),
not *coordination* (who gets to mint which integer).

### What this unlocks

- Sema's storage is genuinely *the* semantic store, not one
  per-opus shard.
- Cross-opus queries (find-all-callers of `Fn X`) are O(reverse-
  index-on-slot), workspace-scoped not opus-scoped.
- Library updates (opus B bumps its `Serialize` trait) cascade
  naturally to every consumer via the index-subscription model
  (046 §P1.4); no per-opus re-ingest needed.
- Ingest deduplication is automatic (import resolution reuses
  slots); no post-hoc join.
- Renaming stays a view-layer concern forever; the engine never
  re-hashes records because someone renamed a fn.

The choice also makes the engine feel more Unison-shaped and
less rustc-shaped — which is the direction the `code-as-logic`
thesis (report 026) has been heading all along. Global slots
are the operational commitment that makes that thesis
self-consistent.

---

*End report 049.*
