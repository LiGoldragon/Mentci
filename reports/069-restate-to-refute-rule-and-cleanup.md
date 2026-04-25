# 069 — restate-to-refute rule and project-wide cleanup

*Claude Opus 4.7 · 2026-04-25 · per Li directive: "create an
agent rule to avoid this kind of approach, where an
incorrect approach is repeated, in order to be refuted,
instead of deleting the incorrect report and replacing it
with a correct document — then apply this rule project-wide."
Rule landed in AGENTS.md; project-wide audit + cleanups
applied below.*

---

## 1 · The rule (now in AGENTS.md "Report hygiene")

**Don't restate-to-refute.** When a frame has been
decisively rejected (architecture.md §10 "Rejected
framings", a bd memory, or a chat correction), do not
re-present it as a candidate in subsequent reports just to
refute it. State only the correct frame.

**Wrong report → delete and replace.** Don't append
corrections, don't banner, don't restate-to-refute. Delete
the wrong report; write a clean successor that states only
the correct view.

The rejected-framings list in architecture.md §10 is the
*only* place wrong frames are named, and only as one-line
entries.

## 2 · Audit findings

Grep for `Two options|Option \([Aa]\)|Option \([Bb]\)|Option
\([Cc]\)|baked-in|internal.assert` across `reports/`
surfaced the anti-pattern in five places, plus two reports
whose entire premise was wrong:

| Location | Pattern | Fate |
|---|---|---|
| `reports/051` §Q2 | option-list (A/B/C) for genesis state, leaning to (A) (now-rejected baked-in) | **delete** (largely superseded by 064/065/067; valuable invariants moved to architecture.md §2/§10 long ago) |
| `reports/062` (whole report) | wrong-premise "walking skeleton" with five constraint-collapsing v0 stubs | **delete** (premise rejected; replaced by 064/067) |
| `reports/063` (whole report) | forensic of 062's contaminations | **delete** (lessons in architecture.md §10 + bd memories) |
| `reports/064` §2.4 step 1 | "Decide seed delivery — baked-in vs genesis.nexus" | **edit** to state only `genesis.nexus` |
| `reports/064` §3 last bullet | conditional "if seed delivered via baked-in self-assert" | **edit** to unconditional genesis-marker mechanics |
| `reports/064` §6 | open-question Q1 was the seed-delivery option-list; Q2 superseded by 067 | **delete §6 entirely**; pointer to 067 §Q-α instead |
| `reports/067` §2 Q-α | "Two options canvased — (A) baked-in vs (C) genesis.nexus" | **edit** to drop Q-α (settled by rung-by-rung rule); renumber Q-β/Q-γ to Q-α/Q-β |
| `reports/067` §6 Q1 | restated "Confirm seed delivery is genesis.nexus (not baked-in)" | **edit** removed; only two genuine open questions remain |

## 3 · What was deleted

- `reports/051-self-hosting-under-nexus-only.md` — large research report from before the rung-by-rung principle. Its valuable content (the no-ingester invariant, the crate-by-crate self-hosting gradient) is in architecture.md §2 (Invariant A) and §10 (project-wide rules) plus reports/061 §1.12 (self-hosting is normal engineering).
- `reports/062-intent-to-implementation-path.md` — wrong-premise walking-skeleton report that proposed five constraint-collapsing v0 stubs. Replaced by reports/064 (rung-by-rung) and reports/067 (what-to-implement-next).
- `reports/063-diagnostic-v0-shortcut-contamination.md` — forensic of 062. Lessons live in architecture.md §10 reject-loud and bd memories `v0-shortcut-as-constraint-collapse-pattern`, `no-hand-built-records`, `no-process-collapse`, `hand-wave-as-contamination-signal`.

## 4 · What was edited

- **`reports/064`**: §2.4 step 1 rewritten to "Author `genesis.nexus`"; §3 last bullet made unconditional; §6 deleted (Q1 was anti-pattern, Q2 superseded).
- **`reports/067`**: §Q-α (seed delivery option-list) deleted — settled by rung-by-rung rule; §Q-β and §Q-γ renumbered to §Q-α and §Q-β; §6 Q1 (restated seed-delivery) removed; the report now has two genuine open questions instead of three.
- **`AGENTS.md`**: new "Report hygiene — don't restate-to-refute" section before "Session-response style."

## 5 · Surviving reports (16)

004, 009, 013, 017, 019, 030, 033, 048, 057, 059, 060, 061,
064, 065, 066, 067 — plus 068 (tree-sitter grammars, unrelated)
and this one (069).

## 6 · What's not addressed

- Other reports with option-lists were checked (`grep`-pass);
  none surfaced the anti-pattern beyond what's listed in §2.
  057, 060, and 061 have leans-and-tradeoffs framings, but
  for genuinely open design questions — not for decisively-
  rejected frames being relitigated.
- The forensic-exception clause in the AGENTS.md rule: a
  report whose explicit purpose is to document *why* a
  contamination occurred could legitimately name the
  rejected frame. None remain in the corpus after the three
  deletions above; the rule's forensic exception is dormant.

---

*End report 069.*
