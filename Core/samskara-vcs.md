# samskara-vcs — Datalog-Native Version Control

## The Insight

Samskara already has version control primitives hiding in plain sight:

- **`liveness`** — every row carries a liveness degree, from doctrine down to disproven
- **supersession** — correcting a belief asserts new truth and demotes old truth
- **content addressing** — deterministic hashing of the live portion = commit ID

What's missing is the **commit** — the operation that makes the current
world state official, addressable, and reproducible.

## Liveness: Not a Boolean

The original `live: Bool` was too coarse. Truth has degrees. A doctrine
and a rumor are both "live" in the sense of being present in the world,
but they carry different epistemic weight.

### The Liveness Spectrum

```
AUTHORITY (highest)
  │
  ├── doctrine        Foundational invariant. Cannot be superseded without
  │                   explicit principle revision. (e.g., "Samskara never sees files")
  │
  ├── trusted_fact    Verified through direct observation or trusted source.
  │                   Can be superseded by new evidence.
  │
  ├── observation     Learned from the codebase, a session, or agent reasoning.
  │                   Default liveness for new thoughts.
  │
  ├── rumor           Unverified claim from an external or uncertain source.
  │                   Queryable but not authoritative.
  │
  ├── web_gossip      Information from web sources. Useful context but
  │                   lowest trust. May be outdated or wrong.
  │
DEAD (not part of the live portion)
  │
  ├── superseded      Was live, replaced by a newer thought via supersession.
  │                   Retained for lineage. Not in the live portion.
  │
  └── disproven       Actively contradicted by evidence. Retained as a
                      record of what was believed and why it was wrong.
```

### What Constitutes "The Live Portion"

The **live portion** = all rows where `liveness` is NOT `superseded` or `disproven`.
Everything from `doctrine` through `web_gossip` is part of the current world state,
just with different epistemic weight. The dead portion (`superseded`, `disproven`)
is retained for audit and lineage but excluded from the world hash.

```
live_portion(row) := row.liveness IN {doctrine, trusted_fact, observation, rumor, web_gossip}
dead_portion(row) := row.liveness IN {superseded, disproven}
```

Queries over the live portion can filter by minimum authority:
```
// Only doctrine and trusted facts (high-confidence world)
?[id, title] := *thought{id, title, liveness},
                 liveness = "doctrine" ; liveness = "trusted_fact"

// Everything including rumors (full working world)
?[id, title] := *thought{id, title, liveness},
                 liveness != "superseded", liveness != "disproven"
```

## Binary Format: Cap'n Proto

Snapshots and deltas are serialized as **Cap'n Proto messages** — zero-copy,
deterministic, and efficiently embeddable in CozoDB as binary blobs.

### Self-Describing via Reader Fingerprint

Cap'n Proto is not self-describing by design. We make it self-describing
at the application level:

```
┌────────────────────────────────────────────────┐
│  Samskara Archive Block                        │
│                                                │
│  ┌──────────────────────────────────────────┐  │
│  │  Header (stored once per reader version) │  │
│  │  ─────────────────────────────────────── │  │
│  │  magic: "SAMSKARA\0"                     │  │
│  │  reader_version: u64 (capnp type ID)     │  │
│  │  schema_hash: blake3                     │  │
│  │  capnp segment table                     │  │
│  └──────────────────────────────────────────┘  │
│                                                │
│  ┌──────────────────────────────────────────┐  │
│  │  Data blocks (headerless, indexed)       │  │
│  │  ─────────────────────────────────────── │  │
│  │  [content_hash] → raw capnp segments     │  │
│  │  [content_hash] → raw capnp segments     │  │
│  │  ...                                     │  │
│  └──────────────────────────────────────────┘  │
│                                                │
│  Reader version index maps version → header    │
│  so any block can be decoded by looking up     │
│  its reader version and prepending the header. │
└────────────────────────────────────────────────┘
```

Key design:
- **Headerless data**: `get_segments_for_output()` gives raw segments without framing
- **Reader version index**: stored once per schema version in `archive_reader_version` relation
- **Content-addressed blocks**: raw segment data indexed by blake3 hash
- **Reconstruction**: look up reader version → get header → prepend to raw segments → decode

### Cap'n Proto Schema (conceptual)

```capnp
@0xSAMSKARA_WORLD_V1;

struct WorldSnapshot {
  commitId    @0 :Data;       # blake3 hash
  relations   @1 :List(RelationSnapshot);
}

struct RelationSnapshot {
  name        @0 :Text;
  rowCount    @1 :UInt32;
  contentHash @2 :Data;       # blake3 of sorted rows
  rows        @3 :Data;       # zstd-compressed capnp-serialized rows
}

struct WorldDelta {
  commitId    @0 :Data;
  parentId    @1 :Data;
  operations  @2 :List(DeltaOp);
}

struct DeltaOp {
  seq           @0 :UInt32;
  relationName  @1 :Text;
  operation     @2 :Operation;
  rowKey        @3 :Data;     # canonical serialized key columns
  rowData       @4 :Data;     # canonical serialized full row
}

enum Operation {
  assert  @0;
  retract @1;
  update  @2;
}
```

## Samskara Version-Controls Database Changes

samskara-vcs is **not** file-based version control. It version-controls
**relation state transitions**. Every mutation to the CozoDB — every `:put`,
every liveness change, every supersession — is a trackable change that
can be committed, diffed, and reconstructed.

```
                    samskara-vcs domain
┌──────────────────────────────────────────────────┐
│                                                  │
│  jj tracks:     files, code, filesystem trees    │
│  samskara tracks: relations, rows, liveness      │
│                                                  │
│  jj commit  = snapshot of filesystem state       │
│  sam commit = snapshot of relation state          │
│                                                  │
│  jj diff    = line/hunk changes in files         │
│  sam diff   = row assert/retract/update in rels  │
│                                                  │
│  jj stores snapshots, computes diffs on-demand   │
│  sam stores deltas, creates snapshots on-demand   │
│  (inverted strategy — relations are cheaper to    │
│   diff than to snapshot, opposite of files)       │
│                                                  │
└──────────────────────────────────────────────────┘
```

### Why Inverted from jj/git?

Git/jj store full file snapshots because files are opaque blobs — diffing
them is expensive (Myers algorithm, patience diff, etc.). Relations are
structured — diffing is trivial (set difference on key columns). So we
store deltas primarily and snapshot periodically for fast reconstruction.

## Two Portions (Updated)

```
┌──────────────────────────────────────────────────────┐
│                      CozoDB                           │
│                                                       │
│  ┌───────────────────────────────┐                   │
│  │        LIVE PORTION           │  liveness:        │
│  │                               │  doctrine         │
│  │  The world state.             │  trusted_fact     │
│  │  Authoritative (by degree).   │  observation      │
│  │  What Samskara reasons over.  │  rumor            │
│  │  Content-hashed at commit.    │  web_gossip       │
│  └───────────────────────────────┘                   │
│                                                       │
│  ┌───────────────────────────────┐                   │
│  │        DEAD PORTION           │  liveness:        │
│  │                               │  superseded       │
│  │  Not part of world state.     │  disproven        │
│  │  Retained for lineage.        │                   │
│  │  Never deleted.               │                   │
│  │  Queryable for audit/replay.  │                   │
│  └───────────────────────────────┘                   │
│                                                       │
│  ┌───────────────────────────────┐                   │
│  │     VERSION CONTROL LAYER     │  always present   │
│  │  commits, manifests, deltas   │  (meta-level)     │
│  │  snapshots, archive index     │                   │
│  └───────────────────────────────┘                   │
└──────────────────────────────────────────────────────┘
```

## Content Addressing

### The Hash

```
for each relation R (sorted alphabetically):
    for each row in R where liveness NOT IN {superseded, disproven}:
        (sorted by key columns)
        append capnp_canonical_serialize(row) to buffer
    relation_hash = blake3(buffer)

manifest = sorted [(relation_name, row_count, relation_hash), ...]
world_hash = blake3(capnp_canonical_serialize(manifest))
```

The world hash is a **merkle root over relation hashes**.

### Why blake3?

Fast, parallelizable, already in the Rust ecosystem. The scheme is
hash-agnostic — any cryptographic hash works.

## The Commit

```
world_commit
    │
    ├── id (= world_hash, content-addressed)
    ├── parent_id (previous commit, "" for genesis)
    ├── agent_id
    ├── session_id
    ├── message
    ├── ts
    │
    ├──► world_manifest (one row per relation)
    │       relation_name
    │       row_count
    │       content_hash
    │
    ├──► world_delta (what changed since parent)
    │       seq (ordering)
    │       relation_name
    │       operation (assert | retract | update)
    │       row_key (capnp canonical, headerless)
    │       row_data (capnp canonical, headerless)
    │
    ├──► world_snapshot (periodic full capture)
    │       relation_name
    │       data (zstd-compressed capnp, headerless)
    │       reader_version (capnp type ID)
    │       byte_count
    │
    └──► world_commit_ref (cross-references)
            ref_type ("jj_change" | "jj_commit" | "external")
            ref_value
```

## Snapshot Strategy

### Tier 1: Delta + Manifest (every commit)
Every commit records `world_delta` and `world_manifest`.
Cheap. Sufficient to reconstruct via replay from nearest snapshot.

### Tier 2: Full snapshot (periodic or on-demand)
A `world_snapshot` stores zstd-compressed capnp serialization of all
live rows per relation. Headerless — reader version stored in the
`reader_version` column, actual capnp header in `archive_reader_version`.

**When to create a full snapshot:**
- Every N commits (configurable)
- On explicit request
- At session boundaries
- When delta chain exceeds size threshold

### Archive Index

```
archive_reader_version {
  version_id: String =>        // capnp 64-bit type ID as hex
  schema_hash: String,         // blake3 of the .capnp schema file
  segment_table: Bytes,        // the capnp framing header
  capnp_schema: String         // the .capnp source (for auditability)
}

world_snapshot_index {
  commit_id: String =>
  snapshot_exists: Bool,
  nearest_snapshot_id: String,
  delta_depth: Int
}
```

## Relationship to jj

Parallel timelines, cross-referenced but not coupled:

```
jj history:        A ─── B ─── C ─── D ─── E
                         │           │
samskara history:  α ─── β ────────── γ ─── δ
```

## Bootstrap: Genesis Commit

The genesis commit bootstraps samskara-vcs itself:

```
1. Create all VCS relations (world_commit, world_manifest, etc.)
   These are "pre-VCS" — they exist before version control starts.

2. Create all world relations (thought, repo, principle, etc.)
   Load seed data.

3. Compute the first world hash over everything that's live.
   This is the genesis hash.

4. Record world_commit{id: genesis_hash, parent_id: "", ...}
   Record world_manifest for each relation.
   Record world_snapshot (full snapshot — this is commit zero).

5. The VCS relations are now part of the world they version-control.
   The genesis commit's manifest includes the VCS relations themselves.
   From this point on, samskara-vcs is self-hosting.
```

The genesis commit is the **fixed point**: it's the first commit that
includes itself in its own manifest. Its parent_id is "" (the empty
string — the void before samskara).

## Resolved Decisions

| # | Decision | Resolution |
|---|----------|------------|
| 1 | Binary format | **Cap'n Proto** — headerless data blocks indexed by reader version, self-describing via application-level envelope |
| 2 | Liveness | **Enum** — doctrine / trusted_fact / observation / rumor / web_gossip / superseded / disproven |
| 3 | What is versioned | **Database changes** — relation state transitions, not files |
| 4 | Cross-agent commits | **TBD** — to be determined as the contract surface matures |
| 5 | Bootstrap | **Self-hosting genesis** — VCS bootstraps itself, genesis commit includes its own relations in its manifest |

## Dependencies

| Crate | Purpose |
|---|---|
| `capnp` + `capnpc` | Serialization / code generation |
| `blake3` | Content-addressing hash |
| `zstd` | Snapshot compression |
| `criome-cozo` | Database wrapper |
