# 054 — sema-centric framing; request-based editing; no ingester

*Claude Opus 4.7 / 2026-04-24 · ratifies three Li corrections
from today that, together, sharpen the engine's framing:
(1) "Rust is only an output"; (2) "Nexus is only a messaging
language — there are no nexus records"; (3) "sema is all we
are concerned with; Rust is derived from it; nexus only exists
to interact with it structured, controlled, permissioned."
Supersedes the ingester-related recommendations in reports/042
§P0.3, /043 §P1.1, /047 §2, /049, /050 §1.b, /046 P0.3+P1.1 rows.
Complements reports/051 (self-hosting without ingester), /052
(edit UX under nexus-only), /053 (contamination audit).*

---

## The sema-centric triangle

```
                   sema
                (the records; the canonical state;
                 content-addressed in rkyv)
                 ▲                    │
                 │                    │
   nexus         │                    │     rust
   (request      │                    │    (derived
   language —    │                    │    emission —
   structured,   │                    │    rsc projects
   controlled,   │                    ▼    sema to .rs;
   permissioned) │                         cargo builds it)
                 │
               users / agents
```

- **sema** is what we are concerned with. Everything else is
  in service of it.
- **nexus** exists *only* because humans and LLMs can't
  hand-type rkyv. It is a structured, controlled, permissioned
  request surface for talking to criomed about sema.
- **Rust** is an emission. rsc derives `.rs` from sema for
  rustc/cargo to consume. Nothing reads the emitted `.rs` back
  into sema.

Everything downstream follows from this triangle.

---

## Three invariants

### Invariant A — "Rust is only an output"

- Sema changes **only** in response to nexus requests.
- There is **no** `.rs` → sema parsing path. No ingester
  component. No bootstrap ingest of hand-written Rust.
- rsc projects sema → `.rs` one-way. The engine never reads
  its own emitted text back.
- External tools (e.g., an LLM agent's preprocessor) operate
  in user-space on their side; only nexus requests cross the
  boundary into the engine.

### Invariant B — "Nexus is a language, not a record format"

- **Sema** is rkyv (binary, content-addressed). That is its
  only stored form.
- **Nexus is a request language** (text) used to talk to
  criomed. Parsing `nexus` produces `criome-msg` rkyv
  envelopes; it does not produce sema directly.
- There are no "nexus records." There is sema (rkyv);
  there are nexus messages (text requests).
- The analogy is SQL-and-a-DB: SQL is a request language;
  stored rows are in the DB's on-disk format. No one calls a
  row a "SQL record."

### Invariant C — "Sema is the concern; everything orbits"

- criomed = sema's engine / guardian.
- nexusd = sema's text-request translator.
- lojixd = executor for effects sema can't perform directly
  (processes, filesystem) — outcomes return as sema.
- lojix-store = where artifact files live, *referenced from*
  sema.
- rsc = projects sema → `.rs` when Rust emission is needed.

If something doesn't serve sema directly, it's not core to
the engine.

---

## The request flow (canonical)

```
  user writes nexus text
      │
      ▼
  nexusd ───────────── parses text → criome-msg (rkyv)
      │                         (CriomeRequest::Assert / Mutate /
      │                          Retract / Query / Compile / …)
      ▼
  criomed ───────────── [validate] ─────────────────────────────
      │                   consults sema for:                     │
      │                     • schema conformance                 │
      │                     • reference resolution               │
      │                     • authorization (caps, BLS quorum)   │
      │                     • rule-engine feasibility            │
      │                     • invariant preservation             │
      │                   if all good → apply to sema            │
      │                   otherwise → reject with error reply    │
      │                                                          │
      ▼                                                          │
  criomed sends criome-msg reply (rkyv) ◀───────────────────────┘
      │
      ▼
  nexusd ───────────── rkyv → nexus text
      │
      ▼
  user reads reply
```

**Every edit is a REQUEST.** criomed is the arbiter. "Assert
this record" can be rejected. "Retract this rule" can be
rejected (per report 043 §P1.5 seed-rule protection). This is
the hallucination wall; this is the consistency boundary.

---

## What this kills (from prior design work)

### Reports and sections now moot

- **`reports/042` §P0.3 — ingester scope.** The whole decision
  matrix (`syn` vs r-a crates vs `rustc_driver`) is about a
  component that doesn't exist. §P0.3 should be excised.
- **`reports/043` §P1.1 — "text round-trip via rsc" as primary
  edit UX.** Wrong. Edits are nexus requests; see report 052
  for the replacement.
- **`reports/047` §2 — "ingester computes composite
  display-name".** Wrong. The display-name comes from the
  nexus request itself. If a user asserts `(Fn :name
  :shapeOuterCircle …)`, `shapeOuterCircle` is what lands in
  `SlotBinding.display_name`. Criomed stores what it was
  given.
- **`reports/049` §1.1 & §3.1 — ingester as canonicalisation
  owner.** Canonicalisation is criomed's mutation handler.
- **`reports/050` §1.b — "ingester owns first-pass naming".**
  Replaced by "the request carries the name; criomed stores
  it."

### Conceptual corrections

- "Nexus records" as a term is wrong. Use "records" (rkyv in
  sema) or "nexus messages/requests" (text transport) — never
  conflate.
- "The engine's source becomes records via nexus messages" is
  shorthand for: "a user issues nexus requests to assert
  records; criomed validates and applies; sema accumulates
  records."
- "Ingester" as engine infrastructure is retired. If we ever
  have a **user-space** Rust→nexus translator tool (for LLM
  preprocessing), it is NOT part of the engine; it is a tool
  the user runs; its output is nexus text just like any other
  client's.

---

## What replaces the "ingester" in earlier plans

### In report 031 §P0.3 — ingester scope

The whole decision is retired. There is no scope to decide.
§P0.3 closes: no ingester.

### In report 042 §P0.3

Excise the section. The P0.1 (reference model) and P0.2 (SCC
hashing) decisions stand with the index-indirection model from
reports/046/050. Criomed's mutation handler owns name→slot
canonicalisation.

### In report 043 §P1.1 — edit UX

Supersede by report 052:
- **Humans**: write nexus requests directly (patch verbs primary
  for small edits; full trees for fresh authoring). Tooling
  roadmap: MVP = hand-composed nexus; Phase-1 = structural
  editor + TUI; Phase-2+ = templates/macros.
- **LLMs**: agent harness exposes query / projection-read /
  request-send tools. LLM emits nexus requests one at a time.
  System prompt teaches nexus grammar.
- **Read for display**: rsc projects records to `.rs` for
  humans to read. That projection is not re-parsed by the
  engine; it's a display surface. Edits from that text never
  flow back in automatically.

### In report 047 §2 / 050 §1.b — composite names

User supplies the name in the request:
```
(Assert (Fn :name :shapeOuterCircle :module :geometry ...))
```
nexusd parses this; criomed validates ("is this name unique
in scope?", "does the slot it resolves to match?"), mints or
reuses a slot, writes `SlotBinding { slot, content_hash,
display_name: "shapeOuterCircle", … }`. No ingester in the
picture.

### In report 045 §P3.4 — critical path

"criomed existing + ingester scope" → "criomed existing".
Ingester is not on the critical path. Ingester does not exist.

### In report 049 — global slot scope

Still good; just retire the ingester mentions. Canonicalisation
happens at request-handling time inside criomed.

---

## Self-hosting under these invariants (from report 051)

Report 051 worked this out. Summary:

- **Cold start** = empty sema + seed writes by criomed
  (schema-of-schema, seed rules). No ingester step.
- **Engine source as records** = the engine's own code
  accumulates in sema over time as someone (Li, LLM agents)
  writes nexus requests that assert the records.
- **The current hand-written `.rs`** (in nota-serde-core,
  nexus-schema, sema, nexusd, nexus-cli, rsc) is scaffolding.
  It produces the binary today via cargo. Eventually each crate
  is rewritten record-by-record into sema via nexus; then rsc
  projects it; then cargo builds the records-authored version;
  then that binary replaces the hand-written one.
- **Self-hosting is a gradient**, not a binary event. Each
  crate flips when its records-authored version can produce an
  equivalent binary.
- **Bootstrap-order lean** (per report 051): nota-serde-core →
  nexus-schema → rsc → nexusd → criomed → lojixd.

---

## What the hand-written `.rs` files are

Under Invariant A, they are **scaffolding with a lifetime**:
- Today: the only way to get a running engine. Compiled by
  cargo in the usual way.
- After MVP self-host: each crate's records-authored version
  supplants its hand-written version. The hand-written `.rs`
  stays in Git for historical continuity; rsc's projection
  becomes the authoritative `.rs` that cargo actually builds.
- Post-transition: the hand-written `.rs` in Git is a frozen
  snapshot; no one edits it; changes go via nexus to sema.

There is no moment where the hand-written `.rs` gets "ingested"
into sema. It stays as text forever (or until someone deletes
it). Parallel tracks; records track wins.

---

## Validation as a first-class criomed responsibility

Li's message made explicit what was implicit: criomed **must
analyze** each request before applying. The analysis answers:

- **Is the request well-formed?** — schema-level check;
  unknown kinds or field types fail.
- **Do all referenced slots exist?** — reference-validity
  check under the index-indirection model; hallucinated names
  fail here.
- **Does the mutation preserve invariants?** — schema-invariant
  checks (e.g., "every Fn's body is a valid Block").
- **Is it authorized?** — capability tokens / BLS-quorum
  signatures (report 035).
- **Does the rule engine permit it?** — e.g., mutating a seed
  rule requires unlocked authz (report 043 §P1.5).
- **Is the requested new content consistent with cascading
  rules?** — e.g., asserting a TypeAssignment that contradicts
  an existing Obligation may fail.

This is the "hallucination wall" from report 017 and it's
where the engine earns its correctness. Every nexus request
goes through this gauntlet before the write happens.

---

## Impact on reports touched in earlier sessions

Per the contamination audit in report 053:

| Report | Action this session |
|---|---|
| 027 §3 & §5 | Correction banner (moot under Invariant A) |
| 031 §P0.3 | Mark resolved: no ingester |
| 031 §P1.1 | Update lean to nexus-patch-primary |
| 042 | Delete §P0.3; fix §P0.1 rationale |
| 043 §P1.1, §P1.2 | Banner + fix where needed |
| 045 §P3.4 | Fix critical-path language |
| 046 | TL;DR P0.3 + P1.1 rows; §P0.1 ratified-block; action plan |
| 047 §2, §5 | Fix display-name ownership |
| 049 §1.1, §3.1 | Replace ingester with criomed-mutation-handler |
| 050 §1.b | Fix display-name ownership |
| `docs/architecture.md` | Add Invariant A + B to §8 rules; fix §9 |
| bd memories | Update 3 memories per 053 Part 3 |

---

## Open questions that survive

- **External Rust-to-nexus translator tools**: permitted as
  user-space utilities? Li's "we don't care at all to read it"
  leans no — we don't want to build or bless such a tool.
  LLMs learn nexus. But if someone in the community builds one
  externally, that's orthogonal to the engine.
- **What do records look like on the nexus wire?** Not a
  decision for this report; depends on nexus grammar evolution
  (report 013 delimiter-family matrix).
- **How does an LLM see the current state?** rsc projects to
  `.rs` for reading. Query verbs return records. What's
  the canonical "show me this function's current code" request
  that an LLM issues? (Open question for edit UX; report 052
  explores.)

---

*End report 054.*
