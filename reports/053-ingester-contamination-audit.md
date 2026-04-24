# 053 — ingester-contamination audit across reports and docs

*Claude Opus 4.7 / 2026-04-24 · identifies every passage that
assumes an "ingester" (a `.rs` → sema-records parser) under
Li's 2026-04-24 correction: "Rust is only an output. All of the
database is going to be created and edited with Nexus messages."
Inventories file + line + quote + recommended fix.*

---

## Invariant (restated from Li 2026-04-24)

- Sema mutations flow **only** through nexus messages.
- There is **no** `.rs` → records parsing path in the engine.
- rsc projects records → `.rs` for rustc/cargo. That text is
  consumed only by the Rust toolchain. Nothing in the engine
  ever reads it back.
- Users (humans, LLMs) write nexus; tools may translate on
  the user's side, but the engine only accepts nexus.

---

## Part 1 — `/home/li/git/mentci-next/` contaminated passages

### `docs/architecture.md`

- §9 reading-order entry for 027 references "ingester scope"
  as an open question.
- §9 reading-order entry for 050 says "ingester owns composite
  names" — contradicts the invariant.

### `reports/042-priority-0-decisions-research.md`

- **Heaviest contamination.** §P0.3 is entirely about an
  ingester (`syn` + custom resolver vs r-a crates vs
  rustc_driver). Whole section moot.
- §P0.1 has a passage "The ingester normalises at ingest time"
  as the rationale for dual-mode refs. Rationale needs
  re-grounding to "criomed normalises at mutation time."

### `reports/043-priority-1-decisions-research.md`

- §P1.1 "Text round-trip via rsc" depends on "the ingester
  re-parses and streams delta verbs back" — wrong.
- §P1.2 DocStr story mentions "r-a-linked ingester… parses
  doc attributes via hir-def." Moot.

### `reports/045-priority-3-decisions-research.md`

- §P3.4 flow diagram includes "ingester loads it into sema".
- Critical-path text says "bottleneck is criomed + ingester".
  Update to criomed only.

### `reports/046-decisions-synthesis.md`

- TL;DR row P0.3 references ingester.
- §P0.1 ratified block mentions "composite display-names
  computed by the ingester" — fix to "user-provided in the
  nexus mutation."
- §P0.3 section entirely moot.
- P1.1 row "Hybrid: text round-trip default + Patch verb
  family" — wrong. Should become "nexus messages (patch verbs
  primary); rsc read-only for display."
- Action plan "Gated on ingester" step is moot.

### `reports/047-slot-id-design-research.md`

- §2 "Who computes the composite display-name?" — ingester was
  the answer. Replace with "user supplies in the nexus
  mutation; criomed stores and subsequently mutates it."
- §5 final recommendation: drop ingester authorship of names.

### `reports/049-global-slot-scope-research.md`

- §1.1 and §3.1 reference the ingester's role in
  canonicalisation. Replace with "criomed's mutation handler"
  / "the mutation-authoring client."

### `reports/050-slot-index-refinement-synthesis.md`

- §1.b "Composite name ownership" was "ingester" (my lean).
  Must shift to "name comes from the nexus mutation itself."
- "Gated on ingester" subsection of action plan is moot.
- Recent update already shifted to this for §P0.1 at the
  document's end ("ingester is the .rs→records translator") —
  but that sentence itself assumes an ingester. Remove.

### `reports/031-uncertainties-and-open-questions.md`

- §P0.3 is entirely "ingester scope". The decision is not
  "scope of ingester", it's "there is no ingester." Mark as
  resolved: no ingester.
- §P1.1 lean was "text-edit-via-rsc-roundtrip". Wrong. Update
  to "nexus patch verbs primary; rsc projection read-only for
  display."

### `reports/027-adversarial-review-of-026.md`

- §3 "Edit via projection" assumed re-ingest. Flag as moot
  under the corrected invariant.
- §5 proposal to elevate ingester to daemon-class (`ingestd`)
  is obviously moot.

### `AGENTS.md`, `CLAUDE.md`, `docs/workspace-manifest.md`

- No contamination found.

---

## Part 2 — Sibling repo docs

Clean across the canonical set (nota, nexus, nexus-schema,
nota-serde-core, nota-serde, nexus-serde, nexus-cli, nexusd,
rsc, sema, criome, lojix, lojix-store, CriomOS cluster). One
minor item in `nexusd/README.md` line 18 said "lojix-store
blobs" — should be "real files, hash-keyed" per the earlier
lojix-store correction; this is a separate issue from the
ingester audit and was already captured in report 038.

---

## Part 3 — bd memories

Candidates to update:
- `decisions-synthesis-2026-04-24-reports-042-046`: mentions
  "P0.3 syn+resolver MVP ingester" — update to "P0.3 no
  ingester; rust is only an output."
- `p0-1-ratified-2026-04-24-reports-050` and
  `p0-1-final-ratification-2026-04-24-slot`: both mention the
  ingester owning composite display-names. Should be "mutation
  supplies display-name; no ingester exists."

---

## Part 4 — Summary table

| Report | Action |
|---|---|
| 042 | **Delete §P0.3**. Fix §P0.1 rationale. Keep §P0.2. Add correction banner. |
| 043 | Rewrite §P1.1. Fix §P1.2 doc ingest reference. Add correction banner. |
| 045 | Fix §P3.4 flow diagram + critical path references. Add correction banner. |
| 046 | Update TL;DR table (P0.3 row; P1.1 row). Fix §P0.1 ratified block. Delete §P0.3 section. Update action plan. |
| 047 | Rewrite §2 display-name ownership. Fix §5. Add correction banner. |
| 049 | Fix §1.1 and §3.1. Add correction banner. |
| 050 | Fix §1.b. Delete "Gated on ingester" action. Add correction banner. |
| 031 | Resolve §P0.3 (no ingester). Update §P1.1 lean. |
| 027 | Mark §3 "Edit via projection" and §5 "ingestd" as moot via correction banner. |
| `docs/architecture.md` | Add §8 rule "Rust is only an output." Fix §9 reading-order entries. |
| bd memories | Update three memories flagged in Part 3. |

---

*End report 053.*
