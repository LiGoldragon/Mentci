# 037 — workspace inclusion, archive system, and the criome-store question

*Claude Opus 4.7 / 2026-04-24 · addresses Li's cluster of
messages about repo inclusion/exclusion, missing symlinks,
archiving strategy, and the proposal to repurpose `criome-store`
as the sema-DB backend. Synthesises a concrete plan.*

---

## 1 · Li's messages, each addressed

### Q1 — "criome-store is sema, right? The concept might be redundant."

**Yes, the concept is redundant.** Under the current
architecture, sema is the records DB and lojix-store is the
content-addressed filesystem for real files. The original
`criome-store` concept ("one universal content-addressed byte
store for everything") no longer exists as a distinct thing —
it split into sema (records under redb) + lojix-store
(hash-keyed directory of real unix files).

The **prototype code** in `criome-store/` (a `MemoryStore`
HashMap plus a `ChunkStore` trait) maps partially onto
lojix-store's future reader library, but it's structurally the
wrong shape — lojix-store holds real files, not byte arrays.
The current code is effectively an abandoned prototype.

### Q2 — "criome-store isn't in our linked repos, so the agent shouldn't be concerned with it"

**Correct, and I violated this earlier.** I updated
`/home/li/git/criome-store/CLAUDE.md` this session to add a
"rename-context banner". That was outside the canonical
mentci-next workspace and the doc change shouldn't have
happened without your involvement. Going forward: I will
only update docs inside `repos/` symlinks unless you direct
otherwise.

### Q3 — "do we need to move those repos out of ~/git so the agent doesn't get confused?"

**Yes — for retired/abandoned repos, yes.** Agents default to
globbing `~/git/` and will freely read anything there. Moving
genuinely-retired repos to `~/git/archive/` (or similar)
removes them from the agent's default search surface without
deleting them. Git history is preserved; the path is just
outside the agent's working radius.

However: moving mid-project is disruptive (breaks any
in-memory references, broken absolute paths in docs, etc.), so
do it in a batch when we can afford the churn. The interim
solution is a **manifest file** (below) + strong CLAUDE.md
markers on retired repos so agents get a hard signal without
moves.

### Q4 — "criomed is missing from our symlink, so others might be too, we need to review that together"

**Confirmed: criomed is missing from `repos/`, and the repo
doesn't exist at all on disk yet.** Table below shows the full
inventory.

### Q5 — "many other repos are missing from our repos symlinks, like the messaging contract repos"

**Confirmed.** Missing and not-yet-created: `criome-msg`,
`lojix-msg`, `lojix-store`, `lojixd`. Missing-but-exists:
`criome` (spec), `lojix` (currently the working deploy CLI;
per report 030 will remain in the canonical set through all
transition phases).

### Q6 — "create a report that addresses every one of the prompts"

This report.

### Q7 — "keep criome as spec, sema as spec, put sema-database code in criome-store"

**My take: the idea has appeal but the naming collides.**
Full analysis in §3 below. Short version: symmetry with
lojix-store is tempting, but "criome-store" as a name for a
records-DB (redb-backed, structured) conflicts with our own
definition of lojix-store ("content-addressed filesystem of
real files, like /nix/store"). Better alternative: keep
`sema/` as the records-DB code repo (one thing, clear name),
retire `criome-store/` to archive, mint new `lojix-store/`
when we need it.

---

## 2 · Inventory — every sema-ecosystem-adjacent repo under ~/git/

Status key:
- **CANON** — part of the current MVP workspace; should be in
  `mentci-next/repos/` symlinks.
- **CANON-MISSING** — belongs in canonical set but repo doesn't
  exist yet; needs creating per architecture plans.
- **TRANSITIONAL-CANON** — currently canonical but in a
  transition phase (see reports/030).
- **RETIRED** — superseded, should be archived out of the
  agent's working surface.
- **ARCHIVED** — already marked archival (CLAUDE.md banner) but
  still living in ~/git/.
- **SHELVED** — design-valid but post-MVP; keep around but
  don't include in canonical.
- **OFF-SCOPE** — unrelated to sema-ecosystem; ignore for this
  exercise.

### Current canonical (symlinked in mentci-next/repos/)
| Repo | Status | Role |
|---|---|---|
| nota | CANON | data grammar spec |
| nota-serde-core | CANON | shared lexer + ser/de kernel |
| nota-serde | CANON | nota's public API |
| nexus | CANON | messaging grammar spec |
| nexus-serde | CANON | nexus's public API |
| nexus-schema | CANON | record-kind vocabulary (logic code records) |
| sema | CANON | records DB (redb-backed) |
| nexusd | CANON | messenger daemon |
| nexus-cli | CANON | text client |
| rsc | CANON | records → Rust source projector |
| tools-documentation | CANON (reference) | cross-project rules |

### Missing from canonical (per docs/architecture.md §4)
| Repo | Status | What to do |
|---|---|---|
| criome | CANON-SHOULD-BE | spec repo (three-pillar framing); **add symlink** |
| lojix | TRANSITIONAL-CANON | currently Li's deploy CLI (report 030); **add symlink** |
| criomed | CANON-MISSING | the sema-engine daemon; create scaffold |
| criome-msg | CANON-MISSING | nexusd↔criomed contract; create scaffold |
| lojix-msg | CANON-MISSING | criomed↔lojixd contract; report 030 Phase B |
| lojixd | CANON-MISSING | lojix daemon; report 030 Phase C |
| lojix-store | CANON-MISSING | content-addressed filesystem + index DB |

### Retired / archived / shelved
| Repo | Status | What to do |
|---|---|---|
| criome-store | RETIRED | predecessor of lojix-store + (arguably) sema; move to archive |
| lojix-archive | ARCHIVED | already banner-marked this session |
| arbor | SHELVED | post-MVP prolly-tree versioning |

### Off-scope
Every other repo in `~/git/` — aski / askic / aski-cc / aski-core / aski-macro / astro-aski / ply-aski / synth-core / semac / sema-codegen / noesis / noesis-schema / veri-core / veric / corec / maisiliym / etc. — plus the CriomOS world (CriomOS, horizon-rs, CriomOS-emacs, CriomOS-home, criomos-archive) and the non-technical ones (BookMaker, AnaSeahawk-website, etc.).

These are **not** sema-ecosystem MVP concerns. Agents
shouldn't need to touch them. They'll sit in `~/git/` until a
future cleanup.

---

## 3 · The `criome-store` question — should it hold the sema-DB code?

Li's proposal: criome = spec, sema = spec, sema-database-code
→ criome-store. The motivation is to keep every repo "doing
something meaningful" so retired names don't litter the
workspace.

### Tempting symmetries
- `criome-store` parallels `lojix-store`.
- Pillar → Store → Daemon feels clean: criome→criome-store→criomed; lojix→lojix-store→lojixd.
- `sema` as a spec repo matches `nota` and `nexus` (both spec
  repos) — three pillars each with a spec.

### Why it's still probably wrong

1. **Naming collision with our own definition of "store".**
   We defined lojix-store as "content-addressed filesystem of
   real files, nix-store analogue". If criome-store means
   "records DB under redb", then "-store" in our vocabulary
   means two different things. Cognitive load.

2. **sema already IS the records DB's name.** In every
   architecture doc, `sema` refers to both the concept (records
   representing meaning) AND the storage code. Renaming the
   storage code to `criome-store` forces everyone to map
   "the sema DB is in a repo called criome-store". Naming
   obscurity in service of symmetry.

3. **`sema` as a spec-only repo is a hard sell.** nota and
   nexus are small grammars with stable specs. Sema is a
   growing record vocabulary where the *library* (read/write
   paths, cascade engine hooks, indexes) is the substantive
   artifact. A spec-only sema repo would probably be ≤50 lines
   of README pointing at nexus-schema; feels undersized for the
   namesake of a pillar.

4. **lojix-store will be created fresh anyway.** The
   prototype in criome-store doesn't survive unchanged — it's
   byte-map code and lojix-store is filesystem code. Whatever
   repo we use as "lojix-store's home" starts empty. Reusing
   the criome-store slot for sema-DB code (then eventually
   needing a fresh lojix-store repo) doesn't save a repo; it
   just moves the churn.

### Recommended alternative (Option Z from earlier note)

- Keep **`sema/`** as the records-DB *code* repo (likely what
  it already is). It holds the library for reading/writing
  records, index tables, cascade hooks. Its README describes
  the concept; the code is the spec-in-action.
- Keep **`criome/`** as spec-only repo (three-pillar framing,
  runtime-substrate philosophy). Already what it is.
- **Retire `criome-store/`** to `~/git/archive/`. The prototype
  survives as git history.
- When `lojix-store` is needed, create it fresh. No reuse of
  criome-store.

This gives:
- One-artifact-per-repo rule preserved.
- No "which -store is this" ambiguity.
- `sema/` has a real job (records-DB code).
- `criome/` has a real job (spec + pillar identity).
- `criome-store/` doesn't have a stale identity.

If you still want spec-only `sema/` for pillar parity with
nota/nexus specs, the alternative is to split
`sema/` → `sema/` (spec) + `sema-db/` (code). But that's
another repo, more symlinks, more churn. I'd pick the
simpler single-repo-for-sema model.

**This is your call** — I'm flagging the tradeoffs, not making
the decision.

---

## 4 · Proposed manifest system

The problem: agents need to know which repos are canonical
without having to read architecture.md + reason about it. A
structured manifest file solves this.

### Proposed location

`mentci-next/docs/workspace-manifest.md` (alternative:
`workspace-manifest.toml` for machine-parsing, but markdown is
fine for a small inventory and humans can read it).

### Proposed shape

For each `~/git/<repo>/`: one-line entry with:

- **status**: CANON | CANON-MISSING | TRANSITIONAL | RETIRED |
  ARCHIVED | SHELVED | OFF-SCOPE
- **role**: one-line what-it-does
- **pointer**: link to the authoritative report or
  architecture section if the status is non-trivial
- **last-reviewed**: date; when this entry was last verified

### Workflow

- When architecture changes, the manifest updates alongside.
- When a repo's status changes, its manifest entry updates and
  (for CANON) the `repos/` symlink updates.
- When a repo is retired, it gets a terminal entry here plus a
  CLAUDE.md banner plus (eventually) a move to
  `~/git/archive/`.

### Inclusion/exclusion rule for agents

"If a repo is not in the manifest's CANON or TRANSITIONAL list,
don't touch its docs or source without explicit instruction."

This should live in `mentci-next/AGENTS.md` as a hard rule.

### Physical archive

Make `~/git/archive/` a directory. Move obviously-retired
repos there when it's safe to do so (no inbound references).
The first candidates:

- `criome-store` — superseded prototype (per this report §3)
- `lojix-archive` — already archival by banner

Off-scope repos can stay in `~/git/` for now — they're just
noise, not actively misleading. Revisit if the noise becomes
friction.

---

## 5 · Concrete action items (proposed for this session or next)

### Immediate, low-risk (this session)

1. **Add symlinks for two missing canonical repos**:
   `criome` (spec) and `lojix` (transitional-canon per 030).
   Both repos exist; both are canonical under current
   architecture.
2. **Update mentci-next/AGENTS.md** to describe the full CANON
   set (not "ten repos for the MVP" — that count is stale) and
   add the "don't touch non-manifest repos" rule.
3. **Revert the CLAUDE.md change I made to criome-store this
   session** (it was outside canonical workspace per Q2).
4. **Create the manifest** at
   `mentci-next/docs/workspace-manifest.md` with the inventory
   from §2 above.

### Needs Li's decision

5. **Settle the sema-DB code location question** (§3). I lean
   "keep sema/ as the code repo; retire criome-store"; you may
   prefer otherwise.
6. **Greenlight the physical archive directory** (`~/git/archive/`)
   and what moves when.
7. **Decide when to create the CANON-MISSING repos**: criomed,
   criome-msg, lojix-msg (Phase B of 030), lojix-store, lojixd
   (Phase C of 030). These are empty shells at first; creating
   them now gives the symlinks a home even if most are stubs.

### Defer

8. **Off-scope repo cleanup** — not pressing. The aski / old-
   sema / CriomOS clusters don't actively mislead; they're
   just ambient.

---

## 6 · Summary table

| Thing | Status | Next action |
|---|---|---|
| criome-store as concept | Redundant with sema (records) + lojix-store (files) | Retire |
| criome-store repo | Prototype code; outside canonical | Move to archive; revert my this-session CLAUDE.md edit |
| criome in symlinks | Missing | Add |
| lojix in symlinks | Missing | Add (transitional; per 030 it stays) |
| criomed in symlinks | Missing (repo doesn't exist) | Create scaffold, then symlink |
| criome-msg in symlinks | Missing (repo doesn't exist) | Create scaffold, then symlink |
| lojix-msg in symlinks | Missing (report 030 Phase B) | Create in Phase B |
| lojix-store in symlinks | Missing (not yet created) | Create when needed |
| lojixd in symlinks | Missing (report 030 Phase C) | Create in Phase C |
| sema-DB code location | `sema/` (status quo — recommended) or move to `criome-store/` (your proposal) | Your call |
| Workspace manifest | Doesn't exist | Create at docs/workspace-manifest.md |
| Agent inclusion rule | Implicit (AGENTS.md lists ten repos; stale) | Explicit "manifest is authoritative" rule |
| Physical ~/git/archive/ | Doesn't exist | Create when we do the move |

---

*End report 037.*
