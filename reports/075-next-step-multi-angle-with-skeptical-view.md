---
title: 075 — next step forward, three-angle research with skeptical view
date: 2026-04-25
feeds: reports/072 §2; reports/073 §2; reports/074 §6; architecture.md §10
status: synthesis
---

# 075 — next step forward (three-angle audit)

Three parallel agents were asked the same question — *what is the
next step?* — from forward-momentum, skeptical (philosophy-grounded),
and coherence angles. They converge on a single conclusion that is
sharper than any single angle.

## 1. The three angles in summary

**Forward-momentum.** Of the carried Li-blockers (Q-α 15-kind set,
Q-β genesis principal, Q1 criome-types nod, Q4 cancel-criomed verb,
072 §2 items 5-6), Q1 has the highest unblock-leverage: confirming
criome-types creation unblocks parallel scaffolds for criome-msg +
criome-schema + sema (~1500-2000 LoC). Q-α and Q-β are isolated
single-crate decisions (criome-schema and criomed respectively).
Q4 and 072 §2 items 5-6 are narrow and safe to defer.

**Skeptical.** The corpus has grown by ~8,400 lines across 23
reports in two weeks. The functioning, non-skeleton code is ~1,550
lines across three repos, all read-only leaf utilities (frame
serialisation, hash encoding, path handling, UUID generation). The
ratio of design-doc commits to production-code commits in the last
two weeks is ~45:0 (excluding yesterday's rkyv-derives landing).
The smallest *observable* end-to-end requires criome-schema +
criome-msg + criomed + genesis.nexus + first Query — a 6-step chain
gated behind Q-α and Q-β, both pending since report/067.

**Coherence.** Three concrete drifts in the corpus:
1. Five stale dead-report citations remain: [reports/064:87](../reports/064-bootstrap-as-iterative-competence.md#L87)
   and [:260](../reports/064-bootstrap-as-iterative-competence.md#L260)
   cite `reports/051 §Q3`; [reports/065:59](../reports/065-criome-schema-design.md#L59)
   cites `reports/051 §Q4`; [reports/057:6](../reports/057-edit-ux-freshly-reconsidered.md#L6)
   cites `reports/054`. 051 was deleted per reports/069; 054 never
   existed.
2. [lojix-store/Cargo.toml](../../lojix-store/Cargo.toml) has no
   rkyv dependency. Architecture.md §10 ratified "all-rkyv except
   nexus" with the canonical feature set; lojix-store is named in
   074 §1 as one of the rkyv-using crates but lacks the dep.
3. Workspace-manifest is current; other rkyv-using crates (nexusd,
   nexus-schema, sema) all use the canonical feature set.

## 2. The skeptical view, taken seriously

The skeptical angle is not devil's advocacy. It names a real risk
that values Li's central philosophy:

- *Skeleton-as-design* is a load-bearing pattern when the skeleton
  is small, recent, and converging on integration. It calcifies
  when the bodies stay `todo!()` long enough that the skeleton
  becomes a reference point in *later* designs (which it already
  is — 074 cites nexusd's frame.rs as the canonical rkyv pattern).
- *Implement what doesnt need me* is a hygiene rule, not a
  productivity strategy. There is a finite supply of clean-cut
  unblocked work. The remaining unblocked items (the three
  coherence drifts above + a few small body-fills) total maybe
  ~80 LoC. After that, every meaningful step requires Li input
  *or* commits a load-bearing design choice without it.
- The corpus is internally coherent and the rkyv hardening was
  principled, but **another report is not the next step.** Each
  report adds reference surface area; the surface needs running
  code to discharge against.

This report itself is suspect on those grounds. The case for
writing it: the three angles needed to be reconciled, and Li
explicitly asked for it. The case against: the synthesis fits in
a chat message; the file is corpus that has to be maintained.
Mitigation: keep this short, land Tier 1 work immediately, and
do not defer Li's blockers any further.

## 3. Synthesis

Tracks A and B (corpus cleanup, body-fill, rkyv hard requirement,
nexusd derives) closed every clean-cut item that did not need Li
input *as of yesterday*. The audits surfaced three new clean-cut
items (the coherence drifts) and validated the carried Li-blockers
as genuine.

The path forward is asymmetric:
- *Without Li input*, there is ~80 LoC of cleanup left.
- *With one short Li response* (Q-α + Q-β answered), ~3,000-4,000
  LoC of scaffolds become buildable, and the smallest observable
  smoke test (Query → seed record) becomes reachable.

Q1 (criome-types nod) and Q4 (cancel verb) are softer than Q-α/Q-β.
Q1 was effectively pre-confirmed in reports/067 §3 and 072 §2; Q4
can be resolved positively at criome-msg landing time (skip for
v0.0.1, add at rung 2 if demand surfaces). Q3 (hex crate vs inline)
is moot — inline already landed in lojix-store/src/hash.rs. 072 §2
items 5-6 are cosmetic.

So the genuinely-load-bearing pending input from Li is **Q-α and
Q-β**. Two questions, not five.

## 4. Recommended next steps

**Tier 1 — autonomous, lands immediately (~80 LoC, ~30 min):**
1. Fix the three stale dead-report citations in [reports/064](../reports/064-bootstrap-as-iterative-competence.md),
   [reports/065](../reports/065-criome-schema-design.md),
   [reports/057](../reports/057-edit-ux-freshly-reconsidered.md) —
   either rewrite to cite the live home of the lesson
   (architecture.md §10, reports/061/064/067/069) or drop the
   reference if it served only historical narration.
2. Add the canonical rkyv dependency to
   [lojix-store/Cargo.toml](../../lojix-store/Cargo.toml) —
   `default-features = false, features = ["std", "bytecheck",
   "little_endian", "pointer_width_32", "unaligned"]`.
3. Add rkyv derives to lojix-store types named in 074 §1 (index
   entries: hash, path bytes, metadata) — types only; bodies stay
   `todo!()`. Compile-validate.

**Tier 2 — needs Li, two questions, ~150 words of input:**
1. **Q-α:** confirm or revise the ~15-kind v0.0.1 schema set
   listed in [reports/067 §2](../reports/067-what-to-implement-next.md).
2. **Q-β:** genesis principal mechanism — (a) hardcoded
   bootstrap-principal-id, (b) first-message-bypasses-permission-check.
   Reports/067 leans (a).

Q1, Q4, 072 §2 items 5-6 do not need separate answers. They
collapse into Tier 3 implementation choices.

**Tier 3 — unlocked by Tier 2 (parallel, ~3,000-4,000 LoC):**
1. Create `criome-types` crate (newtype layer; ~410 LoC).
2. Scaffold `criome-msg` and `criome-schema` in parallel (uses
   criome-types).
3. Extend `sema` to import criome-types newtypes for redb keys.
4. Scaffold `criomed` (uses criome-msg + criome-schema + sema).
5. Author `genesis.nexus` (~50 lines).
6. Smoke test: nexus-cli → nexusd → criomed → seed record reply.

That sequence ends at the first observable end-to-end run of the
engine. After that, the project's question shifts from *what to
build* to *does what we built do what we said*. That is the right
question to be asking, and the corpus today is ready to support it
the moment Tier 2 closes.

## 5. What this report does not recommend

- More design reports before Tier 2 closes.
- Creating criome-types speculatively *off-tree* — Q1 will be
  resolved as part of Tier 2 (the criome-types decision is implied
  by the act of scaffolding criome-msg, which needs the types it
  exports). Speculative off-tree creation buys ~30 min of momentum
  at the cost of a potentially-discarded directory.
- Filling more `todo!()` bodies before integration shape exists.
  The remaining bodies in lojix-store and (future) criomed need
  integration context to specify correctly.

## 6. Open questions for Li (carried)

- **Q-α** — 15-kind v0.0.1 schema set. (reports/067 §2, 072 §2,
  carried since 2026-04-22.)
- **Q-β** — genesis principal mechanism (a) or (b). (reports/067
  §2, 072 §2, carried since 2026-04-22.)

The other questions previously carried (Q1, Q3, Q4, 072 §2 items
5-6) collapse into Tier 1 or Tier 3 implementation choices and do
not need separate answers.
