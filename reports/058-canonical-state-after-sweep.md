# 058 — canonical state after the sweep

*Claude Opus 4.7 / 2026-04-24 · session-close snapshot after
the deep audit + sweep triggered by Li's "Rust is only an
output / nexus is only a messaging language / sema is all we
are concerned with" invariants. Records what was deleted, what
remains canonical, and the open questions that still matter.*

---

## What changed this session

### Invariants ratified

- **A** — Rust is only an output. No ingester. No `.rs` → sema
  parsing, anywhere, ever.
- **B** — Nexus is a request language (text). Sema is rkyv.
  There are no "nexus records."
- **C** — Sema is all we are concerned with. Everything else
  orbits sema (criomed, nexusd, lojixd, rsc, lojix-store).

### Architecture.md rewrite

`docs/architecture.md` rewritten to lead with the three
invariants (§2), the request flow (§3), and an expanded
daemon diagram (§4). Store models (§5), type families (§6),
data flow (§7), repo layout (§8), grammar (§9), project-wide
rules (§10), reading order (§11), update policy (§12) all
updated. Stale references to deleted reports removed; slot-ref
+ per-kind change log + global scope integrated inline.

### Deleted reports (13 this session)

Per Li's "delete wrong reports, don't banner them" rule:

| # | Report | Reason |
|---|---|---|
| 015 | architecture-landscape v4 | Four-daemon topology + kind-byte registry, superseded |
| 018 | never committed | — |
| 023 | sema-as-rust-checker | Text-layer contamination |
| 024 | self-hosting-cascade-walkthrough | Same |
| 025 | sema-schema-inventory | Same |
| 026 | sema-is-code-as-logic | Thesis absorbed into architecture.md; ingester narrative contaminated |
| 027 | adversarial-review-of-026 | Critique served; ingester-dependent sections moot |
| 031 | uncertainties-and-open-questions | Resolved; P0.3/P1.1 invalidated by invariants |
| 042 | priority-0-decisions-research | P0.3 moot, P0.1 rationale contaminated; ratified decisions in architecture.md |
| 043 | priority-1-decisions-research | P1.1 wrong; surviving recommendations in 054/057 |
| 045 | priority-3-decisions-research | Ingester on critical path; canonical lojix content in 030 |
| 046 | decisions-synthesis | Superseded by architecture.md + 054 |
| 047 | slot-id-design-research | Absorbed into architecture.md §5 + 054 |
| 049 | global-slot-scope-research | Same |
| 050 | slot-index-refinement-synthesis | Same |
| 052 | edit-ux-under-nexus-only (first pass) | Superseded by 057 |

### Surgical fixes

- `reports/033` Part 4 cold-start ingester step replaced with
  "criomed ready to accept nexus requests; no automated ingest."
- `reports/033` open-questions section: hash-vs-name and edit-UX
  resolved.

### Other docs

- `AGENTS.md`, `CLAUDE.md` shim pattern: unchanged; already
  correct.
- `docs/workspace-manifest.md`: unchanged; still canonical.
- `devshell.nix`: unchanged.
- bd memories: new memories saved (`sweep-2026-04-24-post-invariants-deleted-026`,
  `decisions-synthesis-2026-04-24-reports-042-046` superseded
  implicitly by the new memories; `p0-1-ratified-2026-04-24-reports-050` and
  `p0-1-final-ratification-2026-04-24-slot` now point at
  architecture.md and 054 for canonical statement).

---

## Canonical report tree (post-sweep)

### Foundational

- [**004**](004-sema-types-for-rust.md) — Rust-code record kinds (Fn, Struct, Expr, Type).
- [009](009-binds-and-patterns.md) — binds-and-patterns reference.
- [**013**](013-nexus-syntax-proposal.md) — grammar canon (delimiter matrix).
- [014](014-serde-refactor-review.md) — serde refactor history.
- [016](016-tier-b-decisions.md) — early decision journey.
- [**017**](017-architecture-refinements.md) — Opus/Derivation shapes; capability tokens.
- [**019**](019-lojix-as-pillar.md) — three-pillar framing.
- [**020**](020-lojix-single-daemon.md) — daemon consolidation.
- [**021**](021-criomed-evaluates-lojixd-executes.md) — criomed is sema's engine.
- [022](022-records-as-evaluation-prior-art.md) — prior art.

### Operational

- [028](028-doc-propagation-inventory.md) — doc inventory.
- [029](029-ra-chalk-polonius-structural-lessons.md) — r-a/chalk/polonius lessons.
- [**030**](030-lojix-transition-plan.md) — lojix transition plan.
- [032](032-lojix-store-correction-audit.md) — lojix-store correction audit.
- [**033**](033-record-catalogue-and-cascade-consolidated.md) — MVP record catalogue.

### Post-MVP scope

- [034](034-sema-multi-category-framing.md) — multi-category sema.
- [035](035-bls-quorum-authz-as-records.md) — BLS quorum authz.
- [036](036-world-model-as-sema-records.md) — world-model data.

### Workspace + audit

- [**037**](037-workspace-inclusion-and-archive-system.md) — workspace manifest.
- [038](038-deep-audit-code-repos.md), [039](039-deep-audit-mentci-next.md), [040](040-criomos-cluster-audit.md), [041](041-deep-audit-final.md) — audit quartet.

### Research (survivors)

- [044](044-priority-2-decisions-research.md) — P2 ergonomics (diagnostics, semachk, migration).
- [048](048-change-log-design-research.md) — per-kind change log design.

### Post-invariant reasoning

- [051](051-self-hosting-under-nexus-only.md) — self-hosting gradient.
- [053](053-ingester-contamination-audit.md) — audit methodology record.
- [**054**](054-request-based-editing-and-no-ingester.md) — **the three invariants ratified**.
- [055](055-framing-audit-post-invariants.md) — post-invariants audit.
- [056](056-nexus-grammar-under-request-lens.md) — grammar refinements.
- [057](057-edit-ux-freshly-reconsidered.md) — edit UX (canonical).
- [**058**](058-canonical-state-after-sweep.md) — this report.

---

## Open questions that matter

Most prior open questions are resolved or superseded. A short
list of what genuinely remains:

1. **Non-Rust workspace surface** — build.rs, test targets,
   doctests, proc-macro crates, Cargo.toml's full shape,
   flake.lock. Some addressed in prior research; not fully
   specced in canonical docs. Needs a dedicated pass when we
   implement beyond the minimal Opus record.

2. **Comments / doc-comments** — `DocStr` as a record kind was
   proposed (kept thesis); field assignment per record-kind not
   yet wired.

3. **Diagnostic translation** — criomed's reply to a rejected
   request needs a structured `Diagnostic` shape. Report 044
   has the recommendation (hybrid: primary span → RecordId;
   secondary spans as JSON blob) — implementation pending.

4. **semachk scope** — when do we start writing the in-criomed
   native checker? Report 044 recommends Option B (cheap phases
   first; body typeck stays in rustc). No action yet.

5. **BLS-quorum authz rollout** — report 035's design stands;
   implementation pending. MVP uses trivial single-operator
   authz.

6. **Proc macros** — running proc-macro Rust code is a Turing
   complete side-effect that doesn't fit criomed's validation
   model. Candidates: sandboxed subprocess via lojixd;
   pre-expanded at source-author time; ignored entirely for
   MVP. Open.

7. **Self-host first-opus order** — reports/051 leans
   nota-serde-core → nexus-schema → rsc → nexusd → criomed →
   lojixd. No ratification yet.

8. **External Rust→nexus translator** — Li's stance leans
   "we don't care to read Rust." Report 057 rejects the
   translator. Confirmed: agents and humans learn to write
   nexus directly.

---

## What's unblocked

- `nexus-schema` refactor to the slot-ref model can start
  (replace `Type::Named(TypeName)` etc. with slot-refs; add
  `Slot(u64)` newtype; add `SlotBinding`, `MemberEntry`
  record kinds).
- `lojix-msg` crate scaffold can begin (report 030 Phase B).
- `criomed` scaffold — once `criome-msg` contract crate exists.
- `rsc` codegen for the per-opus slot-enum (report 050 pattern;
  now in architecture.md §5 reference).

---

## What's deferred

- Federation / multi-criomed (BLS, partition prefix, Slot(Blake3)
  migration).
- semachk native phases.
- World-model records.
- Arbor (shelved).
- `lojix-store` real implementation (scaffold repo exists;
  real code waits for lojixd).

---

## How to use this report

Future sessions that open this project should read:

1. `docs/architecture.md` (canonical).
2. `reports/054` (invariants A/B/C ratified).
3. Category-specific reports per the reading order in
   architecture.md §11.

This report (058) is the "what happened this session"
narrative. If a future session wants to know "when did X
become canonical?" — check the commit history on
architecture.md, or grep this report for X.

---

*End report 058.*
