# 055 — framing audit across the workspace against the three invariants

*Claude Opus 4.7 / 2026-04-24 · deep audit of every report and
doc for passages that contradict Invariants A (Rust-is-output),
B (nexus-is-language), C (sema-is-concern). Supersedes report
053 (previous ingester-only pass).*

---

## Invariants (for reference)

- **A**: Rust is only an output. No `.rs` → sema parsing. No ingester.
- **B**: Nexus is a request language, not a record format. Records are rkyv in sema.
- **C**: Sema is the concern; criomed/nexusd/lojixd/rsc/lojix-store all orbit it.

---

## Critical fixes (Part A)

| File | Line(s) / § | Issue | Fix |
|---|---|---|---|
| `docs/architecture.md` | §9 entry for reports/050 | "ingester owns composite names" violates Invariant A | "user supplies name in nexus request; criomed stores as SlotBinding.display_name" |
| `reports/026-sema-is-code-as-logic.md` | Layer 5 "ingester (bootstrap-only)" + Part 2 narrative | Ingester step in bootstrap violates Invariant A | Replace with "sema populates via nexus requests; no ingester" |
| `reports/033-record-catalogue-and-cascade-consolidated.md` | Part 4 step 3 (cold start) | "Ingester tool walks workspace, streams Assert verbs" | Replace step: "Criomed ready to accept requests; first user/LLM request arrives via nexus" |
| `reports/042-priority-0-decisions-research.md` | §P0.3 entire + §P0.1 passage "ingester normalises at ingest time" | Section about non-existent component; P0.1 rationale wrong owner | Delete §P0.3 section entirely; fix P0.1 passage to "criomed normalises at mutation time" |
| `reports/043-priority-1-decisions-research.md` | §P1.1 text-roundtrip-via-ingester; §P1.2 ingester parses doc attrs | Edit UX based on re-ingest; docs parsed by ingester | Supersede with pointer to 057; fix docs to "DocStr is a record kind; user supplies in nexus request" |
| `reports/045-priority-3-decisions-research.md` | §P3.4 flow diagram + critical path | "ingester loads .rs into sema" + "bottleneck is criomed + ingester" | Remove ingester from flow; critical path is criomed only |
| `reports/046-decisions-synthesis.md` | TL;DR P0.3 row; §P0.1 ratified block; §P0.3 section; action plan "kick off ingester" | Multiple ingester-centric items | Delete P0.3 row; fix P0.1 block ("user supplies name"); delete §P0.3 section; drop action item |
| `reports/047-slot-id-design-research.md` | §2 "ingester computes composite name"; §5 final rec | Ingester-owned naming violates A | Replace: "user supplies the name in the nexus request" |
| `reports/049-global-slot-scope-research.md` | §1.1, §3.1 | "ingester resolves references" | Replace: "criomed's resolver at mutation-handling time" |
| `reports/050-slot-index-refinement-synthesis.md` | §1.b tension; action "Gated on ingester" | Ingester-owned naming; ingester-gated action | Replace: user-supplied name; delete gated-on-ingester subsection |
| `reports/027-adversarial-review-of-026.md` | §3 "Edit via projection" re-ingest; §5 "ingestd daemon" | Both moot under Invariant A | Correction banner at top |
| `reports/031-uncertainties-and-open-questions.md` | §P0.3 "ingester not weekend-sized"; §P1.1 edit UX lean | Both moot or wrong | Mark P0.3 resolved; update P1.1 lean |

---

## Wording cleanups (Part B)

- Terminology: "records in sema" → "sema" where the slip is load-bearing; "nexus records" → "records" or "nexus-schema records" depending on intent.
- `reports/019` §5 daemon table still shows `lojix-forged`+`lojix-stored` — already has partial-supersession banner; stands.
- Stale daemon topology and blob-DB framing was cleaned in prior audits (032, 037).

---

## Reports to delete outright (Part C)

None per Li's "delete wrong reports" rule — all contamination is sectional, not full-report. Reports 042/043/045/046/047/049/050 have clearly-scoped bad sections that excise cleanly; the rest of each report carries load-bearing content.

---

## Observations (Part D)

- Canonical sibling repo docs and the CriomOS cluster are clean.
- bd memories should be audited: `decisions-synthesis-2026-04-24-reports-042-046` and
  `p0-1-ratified-2026-04-24-reports-050` and
  `p0-1-final-ratification-2026-04-24-slot` all mention ingester-owned composite names — need update.
- Report 033 Part 4 cold-start is the last place the ingester lingers as a narrative step. Fixing it closes the loop.

---

*End report 055.*
