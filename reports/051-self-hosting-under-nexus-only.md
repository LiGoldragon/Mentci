# 051 — self-hosting under the no-ingester invariant

*Claude Opus 4.7 / 2026-04-24 · reconsidering the bootstrap and
self-host story after Li's correction "Rust is only an output;
sema is populated and mutated exclusively through nexus
messages." Supersedes the ingester scaffolding in reports 026 §3
(one-shot ingester), 033 Part 4 (cold-start loader that ingests
workspace `.rs`), 042 §P0.3 (ingester-scope research), and the
ingester mentions in 046 and 050. Names the architecture docs
that contradict the correction so they can be re-drafted next.*

---

## 0 · The correction, restated

> I never actually said we were going to ingest Rust. All of the
> database is going to be created and edited with Nexus messages.
> Rust is only an output. We don't care at all to read it.

**The invariant**: there is no `.rs → records` path. Anywhere.
Ever. The only direction text crosses the engine boundary is
*out* — rsc projects records to `.rs`, rustc consumes that text,
cargo drives rustc, and the produced binary bytes land in
lojix-store. Sema is populated by **nexus messages only**; those
messages arrive at nexusd, are parsed to rkyv record trees, and
are asserted by criomed.

The two shapes of text in the system are therefore:

- **Inbound text — nexus syntax.** Humans and LLMs author nexus
  at nexusd's boundary. Nexusd parses it to record trees. This
  is not "ingestion of Rust"; this is authoring records in their
  native surface syntax.
- **Outbound text — `.rs`.** Rsc projects records to `.rs` when
  rustc needs bytes. The `.rs` is scratch — regenerable from
  records — and no daemon ever reads it for semantic content.

Everything below follows from this single rule.

---

## Q1 — How does the engine's own source end up in sema?

### Re-statement

The current sibling repos (`nota-serde-core`, `nexus-schema`,
`sema`, `nexusd`, `nexus-cli`, `rsc`) are working Rust crates
today. Under the no-ingester invariant, none of that `.rs` text
becomes records via parsing. So by what path does
"`nexus-schema`'s `Fn` definitions" end up as `Fn` records in
sema?

### Options

**(a) Re-authored from scratch in nexus.** The hand-written `.rs`
today is scaffolding. It runs the first criomed binary. But the
records-in-sema version of the engine's own code is **written
anew** — record by record, via nexus messages — by Li or an LLM
agent using nexus syntax as the authoring surface. When the
nexus-authored version compiles (via rsc → `.rs` → cargo) and
runs, the hand-written scaffolding is retired. The retirement
happens crate by crate: once `nexus-schema` is fully authored in
nexus, its `.rs` can be removed from Git entirely — rsc emits it
on demand.

**(b) Two parallel artifacts forever.** The hand-written `.rs` in
Git produces the binary today (via cargo). The records-in-sema
version is built up independently and produces a *different*
binary tomorrow. Both exist in parallel; they can diverge. At
self-host close, the user picks one as canonical and the other
withers.

**(c) Hand-written `.rs` is the permanent ground truth; records
are derived.** In this world, sema is an analysis view over text.
This is precisely the model the correction rejects — it implies
an ingester, it implies text as an input. Rule out.

### Lean

**(a).** The hand-written `.rs` is strictly scaffolding; the
long-term shape is "records in sema are the definitive
representation; `.rs` is produced by rsc on demand." Option (b)
is a transition anti-pattern — "two sources of truth" is exactly
the problem the engine exists to retire — and (c) contradicts
the correction. The nexus-authored version is the only one that
survives.

This settles a question that reports 033 and 042 danced around
without naming: *what is the final relationship between Git-
tracked `.rs` files and records?* The answer is that Git-tracked
`.rs` is a transient artifact during bootstrap. Once a crate has
been fully authored in nexus, its `.rs` is ephemeral output from
rsc, not source-of-truth. The repo layout shifts from "N `.rs`
source trees" to "a records database plus a few bootstrap scripts
and flake files."

### Tensions

- **Who writes the initial records?** Li, in collaboration with
  LLM agents that speak nexus. This is a substantial authoring
  project — the engine's own crates are collectively maybe
  20–40 KLOC of Rust today. At nexus syntax's density
  (roughly 1:1 with HIR, not token-level), this is a
  proportional records-authoring project. The correction does
  not make this cost disappear; it clarifies that *this cost is
  where the effort goes* rather than into an ingester.
- **What does the hand-written `.rs` for nexusd itself do during
  re-authoring?** It stays in Git, produces the running nexusd
  binary, and accepts nexus messages that describe (eventually)
  its own replacement. When the nexus-authored version compiles
  and runs, we switch. This is Ship-of-Theseus at the crate
  granularity, not the item granularity.
- **What tempts option (b)?** Divergence is a real risk. If Li
  fixes a bug in the hand-written `.rs` and forgets to mirror it
  in the nexus-authored records, the two drift. The mitigation
  is discipline: during the bootstrap window, bugs get fixed in
  the records and rsc regenerates the `.rs`; the hand-written
  `.rs` is frozen (or deleted crate by crate as re-authoring
  completes).

---

## Q2 — What is the "genesis" state of sema the first time criomed runs?

### Re-statement

Criomed boots with an empty sema. What does it assert before
accepting user input?

### Options

**(A) Seed-only genesis.** Criomed bakes in a small set of seed
records — the schema-of-schema (StructSchema, EnumSchema, and
their sub-records describing themselves), the seed rule set, the
seed Kind registry for the well-known record kinds (`Fn`,
`Struct`, `Enum`, etc.), and whatever is needed for schema
validation to be meaningful on first assert. On empty-sema
detection, criomed asserts these into Revision 0. After that, sema
is literally empty of user content; Li (or an LLM agent) writes
the first `(Assert (Fn …))` and sema grows from there.

**(B) Seed + engine-source genesis.** Option (A), plus the engine
binary ships with a pre-authored `opus nexus-schema`, `opus
criomed`, etc. as seed records too — so on empty-sema detection,
sema is populated with the engine's own code as records. No
ingestion step; criomed just asserts records it carries in its
own binary.

**(C) Seed + genesis from a cold-start nexus script.** On empty-
sema detection, criomed looks for a `genesis.nexus` file (or a
convention location) and replays it. The script is a long
`(Assert ...)` stream authored by a human. This is (B) with the
seed content stored as nexus text on disk rather than baked into
the binary.

### Lean

**(A) for the current phase, with (B) as an option once the
engine is self-hosted.** Today, the seed content is genuinely
small: schema-of-schema (maybe 50 records), seed rule set
(currently empty — rules are Phase 2 per report 013), kind
registry (a couple dozen entries). That fits comfortably in a
baked-in seed table inside criomed's binary, which is how report
033 Part 4 already describes it.

Option (B) becomes attractive *after* the engine has been fully
re-authored in nexus: at that point, "the engine's own code as
records" is a stable artifact (a set of `Opus` records), and
baking it into the binary is no worse than today's cargo
publishing the source. But it's a post-self-host concern; for
the transition, seed-only is simpler.

Option (C) is tempting but adds a moving piece (a file on disk
that criomed parses at startup) whose failure modes need to be
reasoned about (what if it's missing? corrupt? contradicts the
baked schema?). Rule out as the default; consider only if
interactive "seed-from-dump" utilities become a frequent need.

### Tensions

- **How small is "small"?** If the Opus/Derivation/OpusDep/
  RustToolchainPin family counts as seed, the seed grows to
  include enough to describe the engine's own opus. That is
  already bigger than "schema-of-schema." Decision: seed
  includes (i) schema-of-schema, (ii) the KindDecl / record-kind
  registry for every kind the system recognises at boot, (iii)
  seed rules (presently empty), (iv) nothing else. The Opus of
  the engine itself is authored by Li via nexus; it is *not*
  in the seed for (A).
- **What's in the "KindDecl registry"?** Every kind listed in
  report 033 Part 2 (core code records, Opus family,
  schema-of-schema, rules, history, plans, outcomes, analyses,
  subscriptions, capabilities, store refs) plus the seed-slot
  reservations per report 050 (`[0, 1024)`). The registry is
  baked in; user records get allocated from slot 1024 onward.

---

## Q3 — How does self-hosting actually close under no-ingester?

### Re-statement

Option-A path (from Q1): user writes nexus messages that describe
criomed's resolver function. Records accumulate in sema.
`(Compile criomed)` fires; rsc projects records → `.rs`; cargo
builds; new criomed binary exists. Materialise-kill-restart; new
criomed runs against the same sema. Loop.

What does this look like in the *first* iteration, when sema
holds almost nothing of criomed's code? Is self-hosting closed
only after the engine is fully re-authored?

### Options

**(α) Closure happens crate-by-crate.** Self-hosting is not a
single event; it's a gradient over time. A crate is
"self-hosted" when its `.rs` is fully regenerable from records
and the produced binary is functionally identical to the
hand-written version. The engine is "self-hosting" when every
crate in the dependency chain of criomed is self-hosted in this
sense. Partial states are normal — e.g. `nexus-schema` is
records-authored and self-hosted, but `criomed` is still
hand-written today.

**(β) Closure happens as a single "cut-over".** We re-author the
entire engine's codebase in nexus, then in a single build+swap
we move from hand-written to records-authored. Before the
cut-over: nothing is self-hosted. After: everything is.

**(γ) Closure doesn't happen; hand-written and records-authored
live in parallel.** (This is option (b) from Q1; see the rule-out
there.)

### Lean

**(α).** Incremental closure is the only realistic path. The
engine has several crates with real complexity; cutting them all
over in one shot is the worst kind of big-bang migration. The
natural sequence is:

1. **`nexus-schema`** — the schema vocabulary. Hand-written
   today; re-authored first because it's the smallest and
   because every other crate references it. When `nexus-schema`
   is records-authored, its `.rs` is rsc-generated at compile
   time, the records describe `Fn`, `Struct`, etc. as records
   *of themselves*. This is the first point where sema says
   something about its own contents.
2. **`nota-serde-core`** — the lexer/serde kernel. Second
   because nexusd depends on it. Re-author, regenerate, rebuild.
3. **`rsc`** — the records-to-source projector. Circularly
   depends on `nexus-schema` for the record shapes it projects.
   Third; at this point rsc is itself a records-authored rsc.
4. **`nexusd`** — the messenger. Hand-written for the MVP
   bootstrap; re-author once the upstream crates are
   records-authored.
5. **`criomed`** — the engine. Last, because it owns sema and
   touches everything.
6. **`lojixd`** — the executor. In parallel with criomed, or
   just after.

At each step, the crate under re-authoring is the one whose
records are being added to sema. The newly-built binary of that
crate replaces the hand-written one at cut-over for that crate
only. Other crates continue to run from hand-written `.rs` until
their turn.

### Closure at the theoretical level

The loop closes when the running criomed binary was compiled
from records-in-sema rather than from hand-written `.rs`. That
is a single moment per crate, but the meaningful milestone is
**criomed itself** — because once criomed is records-authored,
sema contains records describing the engine that manages sema,
and editing those records (via nexus) cascades through the
engine via the engine. That's the fixed point report
`architecture.md` §1 calls "the whole point of the design."

### Tensions

- **Bootstrap order is delicate.** `nexus-schema` depends on
  serde (which depends on `nota-serde-core`), so re-authoring
  `nexus-schema` first requires `nota-serde-core` to be
  records-authored *or* hand-written but stable. The order above
  puts `nexus-schema` first on the argument that its record
  shapes are more load-bearing than its serde choices; but in
  practice, `nota-serde-core` may go first simply because it's
  smaller and its interface is narrower.
- **Partial self-host is not a crisp state.** During the
  transition, sema contains records describing some crates but
  not others. Cross-references (a records-authored
  `nexus-schema` referencing the still-hand-written
  `nota-serde-core`) need a bridging mechanism. The natural fit
  is an `ExternOpus` record that names the hand-written crate
  as a nix-derivation-built dependency: records-authored crate
  A says "depends on externally-built opus B"; rsc projects A's
  `.rs` with a normal `use b::…`; cargo links against the
  hand-written B's binary artifact from lojix-store. This reuses
  the existing `OpusDep` / `Derivation` records for external nix
  deps — a records-authored crate depending on a hand-written
  crate looks, to rsc and cargo, like a records-authored crate
  depending on an external nix package.

---

## Q4 — What replaces the "cold start loader" in report 033 Part 4?

### Re-statement

Report 033 Part 4 described cold start as:

1. Criomed boots with empty sema.
2. Loader fires; asserts seed schema + rules.
3. **Ingester tool runs; parses `.rs` to records; streams Assert
   verbs to criomed.**
4. Criomed wraps it in Revision-1. From that moment on, text is
   never parsed again.

Under the correction, step 3 is gone. What fills it?

### Answer

**Nothing fills it.** Cold start is just steps 1–2 and a
commit. Sema after cold-start contains schema + kind registry +
any seed rules, and is otherwise empty. User/LLM activity writes
the first `(Assert (Fn …))` via nexus messages; sema grows from
there.

The revised cold-start sequence (Part 4 of 033 correctly
re-drafted):

1. Criomed process starts.
2. Criomed opens the redb holding sema (or creates an empty one
   if the path is fresh).
3. Criomed checks a well-known marker record (e.g. a
   `SemaGenesis` record at a reserved slot); if absent, the
   seed loader asserts the baked-in seed records into
   Revision 0. Otherwise, it verifies that the seed records on
   disk match the seeds this binary expects (fail-hard on
   mismatch, as report 033 Part 5 flags — "schema-crate
   self-referential hazard").
4. Criomed starts the subscription-mux and commit-writer actors;
   starts the name-index (per report 042 §P0.1 dual-mode, though
   see the note below); opens the nexusd and lojixd connections;
   becomes ready for requests.
5. Criomed waits for `Assert` / `Mutate` / `Query` / `Compile`
   verbs to arrive.

**No ingester runs. Ever.** Not at cold start, not on LLM-driven
edits, not on reopening a workspace. The only path into sema is
nexus-over-nexusd.

### Re-draft the name-index subsystem

Report 042 §P0.1 designed a name-index inside criomed to
canonicalise names → hashes at commit time. Under "dual-mode with
hash-only storage," this name-index was supposed to be fed by the
ingester during initial population. Now the ingester is gone, so:

- The name-index is populated *by the first assert of every
  named record*. When a user asserts `(Assert (Fn (Name "resolve")
  (Signature …) (Body …)))`, criomed allocates a slot, mints a
  `SlotBinding` with `display_name: "resolve"`, and the name-index
  gets an entry. The name-index was always going to grow this
  way at warm-edit time; the change is just that there is no
  cold-start batch fill.
- The composite-name rule (report 050 §1 sub-Q 2) — "ingester
  computes `shapeOuterCircle` composite" — needs re-assigning.
  Since there is no ingester, **the composite name comes from
  the nexus message**. When the user writes `(Assert (Fn shape
  "outerCircle" …))` (or however the grammar expresses module +
  item names), nexusd parses that and the compound name lands in
  the `SlotBinding.display_name`. Criomed is still the component
  that stores the name; nexus is the component that produces it;
  the original "ingester owns composite name creation"
  recommendation is void.

### Tensions

- **Does report 050's five-decision block need rewriting?**
  Partially: decision 2 ("ingester computes initial name;
  criomed handles subsequent renames") becomes "nexusd forwards
  the name as written; criomed handles storage and rename." The
  substance is unchanged (the name is computed upstream of
  criomed); the responsible component shifts from a notional
  ingester to the nexus author.
- **Does report 042 §P0.3 (ingester scope) need retracting?**
  Yes, in full. The entire `syn`-vs-r-a-vs-rustc-driver
  decision matrix was about a component that does not exist.
  This report supersedes it by removing the question.

---

## Q5 — What is the status of the existing `.rs` files in our repos?

### Re-statement

`nota-serde-core`, `nexus-schema`, `sema`, `nexusd`, `nexus-cli`,
`rsc`, `lojix` — all have hand-written `.rs`. Under the
correction, are these:

- Scaffolding to be replaced by nexus-authored records?
- A parallel track that produces the binary via cargo while
  records-version is built independently?
- Permanent text-authored ground truth with records as derived?

### Lean

**Scaffolding, to be replaced, crate by crate, over the
bootstrap window.** (Option (a) from Q1 applied at the repo
level.) Concretely:

- **Today**: each repo's `.rs` is the only artifact; cargo builds
  it; the produced binary is what runs.
- **During transition**: the repo's `.rs` continues to be the
  source-of-truth for that crate's binary. In parallel, records
  describing the crate accumulate in sema via nexus messages.
  When the records-version produces a functionally-equivalent
  binary, the crate flips: the repo's `.rs` becomes a
  rsc-emitted, Git-tracked-or-ignored scratch artifact
  (probably Git-ignored, since it's regenerable from sema +
  rsc).
- **Post-transition**: the repo becomes almost empty — maybe a
  `flake.nix`, a `Cargo.toml` that cargo uses to build from the
  rsc-emitted tree, and a `README.md`. The code lives in sema.

**Very important detail**: this does not mean Git stops mattering.
Sema itself is backed by files on disk (redb in a directory), and
that directory is versioned — whether by jj+Git, by arbor (when
it arrives), or by a combination. But *the `.rs` files in repos*
are no longer the versioned source. The versioned source is the
redb contents (or the `Assertion` log within them).

### What `.rs` files exist at steady state?

At the asymptote:

- `flake.nix` / `Cargo.toml` / `rust-toolchain.toml` in each
  repo — these are *configuration*, not code, and are the kinds
  of thing that live at the "Opus" / "Derivation" level in sema
  eventually (per report 033 Part 2 — `Opus`, `Derivation`,
  `RustToolchainPin`, `FlakeRef` are already sema record
  kinds). Migrating these out of plain text into sema is a
  post-steady-state refinement.
- Bootstrap scripts — tiny — that `nix run` criomed with a fresh
  sema pointed at a location. Possibly a `bin/seed-sema` that
  injects the seed records if someone's re-creating sema from
  scratch. These are essentially shell tooling and don't count
  as "source" in the sense of "the engine's logic."
- rsc-emitted `.rs` when cargo runs — lives in `target/` or a
  scratch workdir; gitignored; regenerable. Not in the repo's
  tracked tree.

### Tensions

- **What's the role of `rsc` itself once it emits its own `.rs`?**
  rsc is just a normal records-authored crate. Its records are in
  sema; rsc emits `.rs` for its own binary the same way it does
  for any other; cargo builds it; the binary runs. Nothing
  circular: any given rsc binary was built at time T from
  records-in-sema at time T, which were edited by a criomed
  compiled from earlier records. Standard self-hosting
  diagonalisation; same shape as any compiler bootstrap.
- **What if a record-authored crate subtly diverges from the
  hand-written version?** Diverges in behaviour, I mean, not in
  `.rs` shape. The only defence is testing: the records-authored
  crate's produced binary must pass the same tests as the
  hand-written one. Since tests are themselves nexus (a Test
  record kind is implied by the overall direction), tests are
  records too, and flow through sema. Until that's stood up,
  the bootstrap developer (Li) runs hand-written tests against
  both binaries and confirms.

---

## What "self-hosting" now means

*(plain, one paragraph)*

Self-hosting is the state where the running criomed was compiled
from records in sema, rather than from hand-written Rust text.
Getting there is gradient, not binary: each engine-crate
independently reaches self-host when its records compile (via
rsc+cargo) to a binary that replaces the hand-written one.
Closure at the system level happens when every crate criomed
links against is records-authored — at that point, editing the
engine means asserting and mutating records in sema, rsc
projects the changes to `.rs`, cargo rebuilds, and the new
binary runs the engine that manages the sema that holds its own
records. The loop is tight because nothing round-trips through
text for its own sake; text is emitted only when rustc needs
bytes.

## What the cold-start sequence is

1. Criomed process starts.
2. Criomed opens the redb directory that holds sema (creating
   it if empty).
3. If the `SemaGenesis` marker is absent, criomed asserts the
   baked-in seed records (schema-of-schema, kind registry,
   seed rules, reserved slots) as Revision 0. If the marker is
   present, criomed verifies the seed records on disk match the
   seeds the binary expects; hard-fails on mismatch.
4. Criomed starts its internal actors (commit-writer,
   subscription-mux, name-index reader) and opens IPC channels
   to nexusd and lojixd.
5. Criomed becomes ready; it waits for nexus-mediated requests.
   The first `(Assert (Fn …))` arrives from a human or LLM
   client; criomed allocates a slot, mints a `SlotBinding`,
   writes a per-kind `ChangeLogEntry`, and commits.
6. No ingester runs. No `.rs` is parsed. Ever.

## What the transition from hand-written to records-authored engine looks like

1. **Phase 0 — baseline.** The current state: criomed, nexusd,
   rsc, nexus-schema, nota-serde-core all built from
   hand-written `.rs` via cargo. Sema is whatever Li + agents
   start to author into it, tentatively.
2. **Phase 1 — seed the mechanism.** Ensure the hand-written
   criomed can accept nexus messages that assert records
   describing *any* Rust item. Verify end-to-end: assert a
   trivial `Fn`; compile via `(Compile …)` to lojixd; produce
   a binary; the binary runs. No crate is records-authored
   yet; the mechanism is exercised.
3. **Phase 2 — first crate re-authored.** Candidate:
   `nota-serde-core` (smallest, narrow interface) or
   `nexus-schema` (most load-bearing for records). Li + agents
   author every item in the crate as records; compile; verify
   the produced binary matches the hand-written one's behaviour
   (tests, golden outputs). When verified, delete the crate's
   `.rs` from Git; commit the records-backed crate as its
   canonical form. Its Opus record in sema is now the source of
   truth.
4. **Phase 3 — propagate.** Repeat for each upstream crate of
   criomed. Each crate flip is independent; cross-crate
   dependencies are expressed as `OpusDep` records; the
   still-hand-written crates look like `ExternOpus`
   dependencies to the records-authored ones.
5. **Phase 4 — criomed itself.** Re-author criomed. This is the
   point at which the engine's own logic lives as records in the
   sema the engine manages. Compile, verify, swap. Self-hosting
   is now literal.
6. **Phase 5 — lojixd; extras.** Re-author lojixd; re-author any
   remaining adjacent binaries (nexus-cli, ingester — wait,
   there is no ingester — just the CLI). Sema's state is stable
   modulo user edits.
7. **Phase 6 — maintenance.** Fixes to the engine arrive as
   `(Mutate …)` nexus messages; cascades run; subscribers see
   it; `(Compile criomed)` rebuilds; materialise + restart.
   This is the steady state described in `architecture.md` §6
   ("Self-host close").

## What open questions remain

- **What happens to the 20–40 KLOC of existing hand-written
  `.rs` during re-authoring?** Does the hand-written version get
  edits during the transition window, or is it frozen? If frozen,
  bugs get fixed in records and rsc regenerates — but we can't
  use rsc until rsc itself is records-backed. For the
  transition, edits to `.rs` are allowed but must be mirrored in
  records; practical discipline, not an architectural
  guarantee.
- **Does the existing `.rs` serve any role in authoring the
  records version?** Li may use it as a reference (as a
  well-formed spec of what the records should produce) but the
  engine does not consume it. An LLM agent can read the
  hand-written `.rs` as context to help author the records.
  This is orthogonal to the architectural rule: the engine
  itself never reads it.
- **Report 042 §P0.3 (ingester research) is void.** The whole
  decision matrix (`syn` vs r-a vs rustc-driver) disappears
  because there is no component that does ingesting. The other
  P0 decisions (P0.1 hash-vs-name refs, P0.2 SCC hashing) are
  affected only in that "canonicalisation happens at commit
  time by the ingester" becomes "canonicalisation happens at
  commit time by criomed's mutation handler, on the record tree
  delivered by nexusd." The SCC detection is still real
  (mutual-recursive fns still hash-cycle), but it runs in
  criomed at assert time, not in a separate ingester.
- **Name resolution at the nexus surface.** When a user writes
  `(Mutate (Fn resolve { body: (Call g …) }))`, `g` is a
  name. Nexusd parses this to a record tree with a name-ref
  placeholder; criomed's mutation handler resolves it against
  the current name-index and rejects the mutation if `g` is
  unknown. This is the same logic report 042 §P0.1 described
  for the ingester, now running in criomed. Where exactly it
  sits — criomed's commit-writer actor or a preflight
  validator — is a detail for the commit-pipeline design; no
  new research needed.
- **How is the existing hand-written `nexus-schema` repo
  treated during Phase 2?** If `nexus-schema` is the crate being
  re-authored first, criomed itself is still hand-written and
  runs against a `nexus-schema` version that might disagree
  with the records-authored one. Report 033 Part 5
  ("Schema-crate self-referential hazard") flagged this:
  criomed hard-fails if the seed schema records disagree with
  the crate it's compiled against. So the re-authoring of
  `nexus-schema` has to proceed such that the records always
  agree with the crate the currently-running criomed was built
  against, or criomed won't open sema. Practical pattern: author
  records; build a *new* criomed pinning the new
  `nexus-schema`; re-open sema with the new criomed.
- **How does the LLM agent workflow look in practice?** The
  correction makes it operational: an LLM working on the engine
  interacts with nexusd, sends `(Mutate …)` / `(Query …)` / etc.,
  and never sees `.rs` as input. For LLMs that were trained to
  read Rust, a reference projection to `.rs` via rsc is
  available as a "view" — they read rsc's output, then author
  changes as nexus messages. The LLM's writing interface is
  nexus; its reading interface may be either nexus or `.rs`
  (projection).
- **Does report 046's P0 decision synthesis need revision?**
  §P0.3 (ingester scope) should be struck. §P0.1 (hash-vs-name
  refs) and §P0.2 (SCC hashing) are unchanged in substance —
  both remain real decisions, just with criomed (not a
  separate ingester) as the owner of commit-time
  canonicalisation.

---

## Things the architecture docs currently say that contradict the correction

Flagging these so they can be fixed in the next pass:

- **`docs/architecture.md` §6** — the `data flow` diagram
  implicitly matches the correction (no ingest arrow) but says
  "The MVP target is self-hosting: the engine's own source lives
  as records in sema." — the word "source" is now subtly wrong
  if it implies a source-like artifact. Suggest: "the engine's
  own code lives as records in sema."
- **`docs/architecture.md` §9 reading order** — item 10 points
  at report 033, which contains the now-wrong ingester
  narrative in Part 4. Point the reading order at this report
  (051) and mark 033 Part 4 as superseded.
- **Report 026 §3** — "ingester (bootstrap-only) — text →
  records. Runs once at cold start; may be invoked later for
  external-code ingest." This component does not exist.
  Redraft.
- **Report 033 Part 4** — the cold-start sequence includes the
  ingester as step after seed assertion. Strike step 3; stop at
  seed assertion.
- **Report 042 §P0.3** — the entire section. The component
  whose scope is being researched does not exist. Mark
  superseded; point at this report.
- **Report 046's §P0 synthesis** — drop the §P0.3
  recommendation; update §P0.1 to say "criomed performs
  commit-time canonicalisation" rather than "ingester performs
  initial canonicalisation, criomed handles subsequent renames."
- **Report 050 §1 ("Ingester owns composite names")** — reassign
  to "nexus author produces the composite name; nexusd forwards;
  criomed stores." Substance is preserved.

One architectural line that does *not* contradict the correction
and deserves reaffirming: **"Schema is the documentation.
Patterns and types resolve against sema; hallucinated names are
rejected early."** (`docs/architecture.md` §8.) Under the
correction, this becomes literal: nexus messages carrying
unknown names are rejected at criomed's mutation handler; there
is no earlier phase that could catch them (nexusd only validates
syntax, not references). The hallucination wall sits at criomed.

---

*End report 051.*
