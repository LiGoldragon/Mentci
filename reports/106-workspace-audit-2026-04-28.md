# 106 — Workspace audit + cleanup pass

*Per Li 2026-04-28: "do a very deep agent assisted audit of all
of the different components, repositories, to see if there's
anything inconsistent in the code, in the architecture
documents… clean state of all the project before I give you my
next architecture idea."*

7 parallel Explore agents covered: M0 daemon graph (criome +
nexus + nexus-cli); signal + sema; nota stack (nota +
nota-codec + nota-derive); mentci internals (reports + checks);
tools-documentation; M2+/TRANSITIONAL repos (lojix family + rsc
+ horizon-rs); cross-repo consistency. Findings synthesized,
substantive items applied this pass, smaller items deferred or
dropped.

---

## 1 · Applied this pass

### 1a · Stale-report references stripped

Every reference to deleted reports (089, 098, 099, 100) removed
from source files and per-repo ARCH/README docs. Per Li's
"reports are ephemeral" doctrine, code shouldn't anchor on
ephemeral artifacts.

| Repo | Files |
|---|---|
| signal | `src/lib.rs`, `src/pattern.rs`, `ARCHITECTURE.md` |
| nota-codec | `src/lib.rs`, `src/decoder.rs`, `ARCHITECTURE.md`, `README.md` |
| nota-derive | `ARCHITECTURE.md`, `README.md` |
| criome | `ARCHITECTURE.md` |
| nexus-cli | `ARCHITECTURE.md` |

The two reports that remain valid as cross-references — 074
(rkyv discipline) and 088 (closed-vs-open schema research) — are
unchanged.

### 1b · Stale crate names replaced

Every reference to deleted crates (`nota-serde`,
`nota-serde-core`, `nexus-serde`) replaced with the current
shape (`nota-codec` + `nota-derive`).

| Repo | Files |
|---|---|
| nota | `ARCHITECTURE.md`, `README.md` (Implementation section rewrite) |
| tools-documentation | `rust/style.md` (serialization + cargoLock examples) |

### 1c · Doc-code accuracy fixes

| Where | Before | After |
|---|---|---|
| nota-derive `src/lib.rs` + `ARCHITECTURE.md` + `README.md` | "Five derives" | "Six derives" — added `NotaTryTransparent` row to the README table |
| nota-codec `ARCHITECTURE.md` | "21 typed Error variants" | "22 typed" |
| signal `ARCHITECTURE.md` | "Round-trip tests (18)" | "42 tests total — 19 wire + 23 text-format" |
| nexus-cli `ARCHITECTURE.md` | "Skeleton. Body lands alongside…" | "M0 working. Verified end-to-end via mentci-integration." |

### 1d · Style-doc discipline fix

`tools-documentation/programming/abstractions.md` had a closing
parenthetical: "(Project enforcement in [criome/ARCHITECTURE.md
§2 Invariant D]…)". Per Li 2026-04-28 ("links like this dont
belong there") — style docs must not invoke a downstream
ARCHITECTURE.md to backstop their claims. Removed.

### 1e · Missing AGENTS.md / CLAUDE.md shims

5 CANON repos lacked the canonical doc shim. Created:

| Repo | Files |
|---|---|
| nexus | `AGENTS.md` (orientation), `CLAUDE.md` (shim) |
| nexus-cli | same |
| signal | same |
| sema | same |
| rsc | same |
| tools-documentation | `CLAUDE.md` (shim) |

Each new `AGENTS.md` is short — repo role, pointer to its
`ARCHITECTURE.md`, pointer to mentci/AGENTS.md for workspace
conventions, pointer to relevant tools-documentation topic
(ractor.md for the actor-hosted daemons), and any
load-bearing repo-specific rule. Each `CLAUDE.md` is a one-line
shim per the [mentci/AGENTS.md §"AGENTS.md / CLAUDE.md
pattern"](../AGENTS.md).

### 1f · Reports/101 deleted

The 2026-04-27 style-audit-pass report. The five fixes it
documents shipped to their respective repos at the time. The
forensic-narrative content (the audit's own meta) is what the
"reports are ephemeral" doctrine specifically says shouldn't
linger. Deleted, no extraction.

### 1g · Ractor.md learnings

Already pushed in a prior commit this session: the **Mailbox
semantics** subsection (priority order Signals > Stop >
SupervisionEvents > User; active `await` blocks the mailbox;
self-call deadlock; `myself.stop` is async-fire-and-forget).
This formalizes the deadlock pattern surfaced in [reports/105
§10](105-nexus-ractor-migration-deep-review-2026-04-28.md).

---

## 2 · Reports inventory after this pass

| Report | Verdict |
|---|---|
| 074-portable-rkyv-discipline | KEEP — pinned feature set is canonical reference; cited from every Cargo.toml |
| 088-closed-vs-open-schema-research | KEEP — research backing Invariant D; reports/104 §6 cites this |
| 102-visual-architecture-2026-04-27 | KEEP — mermaid diagrams are the only comprehensive visual reference |
| 103-ractor-migration-design-2026-04-28 | KEEP — design doc with Li's seven answers; ground truth for M2+ subscribe/streaming work |
| 104-handoff-after-criome-ractor-migration-2026-04-28 | KEEP — active handoff; lurking-dangers list still load-bearing |
| 105-nexus-ractor-migration-deep-review-2026-04-28 | KEEP — fresh deadlock pattern + lesson |
| **106-workspace-audit-2026-04-28** | this report |

7 reports active (was 7; deleted 101, added 106). Soft cap is
~12. Plenty of headroom.

---

## 3 · Deferred — flagged but not applied this pass

These are real findings the audit surfaced but applying them
this pass would exceed scope or require design decisions Li
hasn't made. ✅ marks items applied in the follow-up pass (§6).

### 3a · horizon-rs nota-serde migration ✅ applied in §6

`docs/DESIGN.md:22, 484, 515` and `packages/default.nix:16-19`
referenced `nota-serde` and `nota-serde-core`. The Rust code
was already migrated; only the docs and dead Nix outputHashes
remained. Now done.

### 3b · sema/ARCHITECTURE.md reader_count addition ✅ applied in §6

Sema's Status section now lists `reader_count` /
`set_reader_count` / `iter` / `DEFAULT_READER_COUNT`, with
test count corrected 7 → 12.

### 3c · criome/AGENTS.md cleanup ✅ applied in §6

Restate-to-refute paragraphs ("aski no longer in the stack",
"Earlier framing (historical): criome-store") removed. The
"Shelved for MVP: arbor" note kept (forward-looking, matches
workspace-manifest).

### 3d · horizon-rs README CANON marker — N/A

There is no `README.md` in horizon-rs (the audit agent's report
was a false flag). No action needed.

### 3e · nexus-cli `[lib] name = "nexus_cli"` underscore

`Cargo.toml:11` uses underscores while everything else uses
hyphens. Cargo-mandated for lib-name semantics; not an
inconsistency in our control. **No action needed.**

### 3f · nexus pin strategy alignment

`nexus/Cargo.toml` pins signal + nota-codec by exact `rev = …`,
while `criome/Cargo.toml` uses `branch = "main"`. Functional
but inconsistent. Pinning by branch produces faster lockfile
drift; pinning by rev produces deterministic builds at the cost
of staleness. **Choice belongs to Li**; not applied.

### 3g · Free function `diagnostic` in criome/src/engine.rs

The `pub fn diagnostic(code, message) -> Diagnostic` at
module level in `engine.rs:188` is used by sibling modules
(`connection.rs`). Agent A flagged it as a methods-on-types
violation. **Not applied** — the file's doc comment explicitly
calls this out as a deliberate "module-level helper" used by
sibling modules; converting it to `Diagnostic::new_error(...)`
would be an upstream signal change (Diagnostic lives in signal,
not criome). Defer until signal restructures.

### 3h · workspace-manifest M0-scope column

The manifest lists lojix family as CANON but they aren't in
flake.nix inputs (intentionally — out of M0 scope). Agent D
suggested an "M0 scope" column for clarity. **Flagged for Li's
discretion.**

---

## 4 · Open bd issues — confirmed all live

Per agent D's check, every open bd issue is genuinely open. No
phantom-closed candidates.

- `mentci-next-ef3` — self-hosting "done" moment
- `mentci-next-7tv` — M1 per-kind sema tables
- `mentci-next-d3b` — M0 step 7 genesis.nexus
- `mentci-next-0tj` — rsc records-to-Rust projection
- `mentci-next-4jd` — M2 method-body layer
- `mentci-next-7dj` — cross-repo flake input pattern
- `mentci-next-8ba` — M3 sema redb wrapper
- `mentci-next-zv3` — M6 bootstrap demo
- `mentci-next-dqp` — rename rsc to a full English word
- `mentci-next-rgs` — **closed this session** (nexus ractor migration shipped)

---

## 6 · Follow-up pass — deferred items applied

Per Li 2026-04-28: *"do you feel like you would know how to fix
the issues that were found in horizon-rs … if so, please go
ahead and fix them and remove all of the stale mentions and I
would like you to go over anything you think that you know how
to fix clearly and fix it."*

Picked up the deferred items I had high confidence on. Each
landed in its own commit per the audit-trail discipline.

| Item | Repo | What | Verification |
|---|---|---|---|
| 3a | horizon-rs | `packages/default.nix` — removed dead outputHashes for `nota-serde` + `nota-serde-core` (Cargo.lock no longer references those crates; nota-codec + nota-derive use the `git+url#rev` form which crane resolves without outputHashes). `docs/DESIGN.md` — replaced 3 stale references with the current shape. | `nix build .#packages.x86_64-linux.default --no-link` exit 0 |
| 3b | sema | `ARCHITECTURE.md` Status — added `Sema::iter`, `Sema::reader_count`, `Sema::set_reader_count` to the implemented-and-tested list; fixed test count 7 → 12; new paragraph documenting the redb-meta-table reader-count storage. | static — doc-only |
| 3c | criome | `AGENTS.md` — stripped the restate-to-refute paragraphs ("aski no longer in the stack — its role is now played by `nexus-schema` records" + "Earlier framing (historical)"); replaced with a forward-looking note pointing at signal as the home of `KindDecl` records. | static — doc-only |
| 3d | horizon-rs | False flag (no `README.md` exists). | n/a |

### Items intentionally left

- **§3e** nexus-cli `[lib] name = "nexus_cli"` underscore — Cargo-mandated; not in our control.
- **§3f** nexus pin strategy alignment — design choice, not cleanup.
- **§3g** free function `diagnostic` in criome/engine.rs — would need a signal-side type addition; outside this scope.
- **§3h** workspace-manifest M0-scope column — Li's discretion.

Side observation while building horizon-rs: its `nix flake
check` errors with "Path 'lib/default.nix' does not exist"
because it uses `blueprint` and has a Cargo crate at `lib/`
which blueprint tries to import as a Nix lib. **Pre-existing
flake structure issue**, unrelated to this cleanup. Direct
`nix build` on the package works fine. Flagging for whenever
horizon-rs is next worked on.

## 5 · Workspace state at end of pass

- All M0 demo features shipping (criome + nexus + nexus-cli ractor-hosted, verified by `mentci-integration`).
- `nix flake check` from mentci passes all 14 derivations.
- 11 CANON repos have ARCHITECTURE.md + AGENTS.md + CLAUDE.md shim. Spec-only and doc-only repos exempt.
- 7 active reports; one deleted; one added.
- ractor.md captures the framework's load-bearing operational knowledge in one place.
- Stale references to deleted crates / deleted reports / outdated counts: zero in the M0 daemon graph + signal + sema + nota stack + tools-documentation. Three remain in horizon-rs (TRANSITIONAL, deferred per §3a).

Clean enough. Next phase ready.
