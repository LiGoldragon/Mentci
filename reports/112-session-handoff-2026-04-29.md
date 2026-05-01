# 112 — Session handoff: where the implementation stands at end-of-day 2026-04-29

*Comprehensive context dump so a fresh session can resume exactly
where this one ended. The dance has moved from design through
foundation-laying through scaffolding through end-to-end-running.
Every layer (wire / driver / model / view / paint / nix
packaging / E2E test) is exercised at some level. Lifetime: lives
until the next session reads it and either supersedes it or
deletes it after the further work covered.*

---

## 0 · Hard rule before doing anything

**Read [INTENTION.md](../INTENTION.md) first.** Then
criome's [ARCHITECTURE.md](https://github.com/LiGoldragon/criome/blob/main/ARCHITECTURE.md).
Then mentci's [AGENTS.md](../AGENTS.md). The §What-we-do-not-
optimise-for in INTENTION is load-bearing — no time estimates,
no "MVP" framings, no scope-by-cost trade-offs. Recommendations
cite the principle that motivates them.

The work this session converged on **clarity > correctness >
introspection > beauty**, in that priority order, with full
foundation work over implementation speed.

---

## 1 · Where every repo stands

Every CANON repo built and pushed clean. Latest commit hashes:

| Repo | Latest | Local-clean | Origin pushed |
|---|---|:-:|:-:|
| signal | `7aef9f18b163` | ✓ | ✓ |
| sema | (unchanged this session) | ✓ | ✓ |
| nexus | `070113ed624d` | ✓ | ✓ |
| nexus-cli | (unchanged) | ✓ | ✓ |
| criome | `658a4108ca73` | ✓ | ✓ |
| forge | (unchanged; skeleton-as-design) | ✓ | ✓ |
| arca | (unchanged; skeleton) | ✓ | ✓ |
| **mentci-lib** | `34451d2d0cb1` | ✓ | ✓ |
| **mentci-egui** | `3284104fcf33` | ✓ | ✓ |
| mentci | `6c5ed19c1446` | ✓ | ✓ |

**mentci-lib** and **mentci-egui** are NEW this session. Both
github.com/LiGoldragon/{mentci-lib,mentci-egui} were created
via `gh repo create` mid-session.

---

## 2 · What is verified to run end-to-end

### 2.1 Criome ↔ mentci-lib wire

- `cargo run --example handshake` (or `cargo run --bin
  mentci-handshake-test`) against a live `criome-daemon` on
  `/tmp/criome.sock`:
  - Connects, completes handshake (HandshakeRequest →
    HandshakeAccepted).
  - Auto-subscribes Graph + Node + Edge wildcard queries.
  - Initial empty Records replies absorbed.
  - Six Asserts (Graph "Echo Pipeline", Graph "Build Defs",
    Node "ticks"/"double"/"stdout", Edge 1024→1025 Flow) all
    return `OutcomeArrived(Ok)`.
  - Each Assert triggers a SubscriptionPush — three pushes per
    write (one per active subscription).
  - Final ModelCache: `2 graphs · 3 nodes · 1 edges`, real
    sema slots `Slot(1024)..Slot(1029)` flowing on the wire.
  - GraphsNav view shows "Echo Pipeline (Graph)" and "Build
    Defs (Graph)".

### 2.2 mentci-egui binary

- `cargo build -p mentci-egui` succeeds; binary links cleanly
  against eframe.
- `nix build` from `~/git/mentci-egui` produces a wrapped
  binary (`result/bin/mentci-egui`, 3.8KB wrapper +
  14MB ELF). Wrapper sets `LD_LIBRARY_PATH` for runtime
  dlopen.
- Not visually verified — no graphical session in the dev
  environment. Type-checked + linked + scaffolded for the
  obvious behaviours.

### 2.3 Workspace `nix flake check`

From `~/git/mentci`:
```
nix flake check
```
Builds **every** layer fresh from cold cache:
- 9 per-crate `checks.default` (cargo test inside nix sandbox)
- The new `mentci-lib-handshake` E2E scenario
- Existing `mentci-integration` + `scenario-chain` +
  `roundtrip-chain` + per-step scenario tests
- linkFarm of all 9 crate checks under `checks.default`

All green.

---

## 3 · Architecture decisions made this session

### 3.1 mentci is a family of GUIs

One `mentci-lib` (heavy application logic) consumed by per-GUI
shells: `mentci-egui` first, future `mentci-iced` /
`mentci-flutter` / etc. Each shell is thin — the library
carries every piece of sema-viewing and editing logic.

### 3.2 Contract shape: data-and-events MVU

`mentci-lib` exposes:
- `WorkbenchState` — owned model
- `WorkbenchView` — per-frame snapshot (data out)
- `UserEvent` — gestures the shell forwards
- `EngineEvent` — daemon-originated events the runtime feeds
- `Cmd` — side-effects to dispatch outside the lib

The shell calls `view()` each frame, paints it, captures
gestures, calls `on_user_event(ev)`. Engine events come in via
`on_engine_event(ev)`. Both event entrypoints return
`Vec<Cmd>` that the runtime executes (send signal frame, open
connection, etc.).

This is the MVU/Elm-architecture shape. Recommended in
[reports/111](111-first-mentci-ui-introspection-2026-04-29.md)
§12 by clarity + correctness + beauty + foreign-interface
portability all simultaneously.

### 3.3 Two persistent daemon connections

mentci-lib owns two UDS connections:
- `/tmp/criome.sock` — for editing, queries, subscriptions
- `/tmp/nexus.sock` — for signal↔nexus rendering only (per
  nexus/ARCH's bright-line scope: "translate between nexus
  text and signal. In both directions. Nothing else.")

Failure modes settled: nexus down → error pane appears,
"[as nexus]" lines hide; criome down → mentci is useless and
refuses to operate.

### 3.4 Wire shape: records-with-slots

`signal::Records` variants now carry `Vec<(Slot, T)>` instead
of `Vec<T>`. Each record on the wire carries its sema slot.
Edge endpoints can resolve to specific Node entries by slot
lookup. Text rendering uses nota-codec's tuple impl which
renders `(Slot, Node)` as `(Tuple <slot> (Node ...))`.

### 3.5 First GUI library: egui

After deep-dive in
[reports/111 §11](111-first-mentci-ui-introspection-2026-04-29.md#§11):
egui wins on canvas-centrality + workbench-ecosystem-precedent
(Rerun, egui_node_graph). iced is the natural second family
member (`mentci-iced`) when added later. Linux + Mac
first-class.

### 3.6 Push, never pull (now real)

criome's Subscribe handler is wired. mentci-lib auto-
subscribes on connect. Every Assert triggers
`push_subscriptions` in criome's engine actor which re-runs
each subscription's query and casts SubscriptionPush messages
to subscribed connections. The push-not-pull discipline is
upheld at the engine boundary.

### 3.7 New record kinds in signal

Eight new record kinds added per Li's "implement that, its not
hard" answer for Identity + Tweaks (report 111 Q-E):
`Principal`, `Tweaks`, `Theme`, `KindStyle`,
`RelationKindStyle`, `Layout`, `NodePlacement`, `KeybindMap`.
Themes describe **intent** not appearance — `IntentToken`,
`GlyphToken`, `StrokeToken` are abstract names each shell
maps to its native palette.

### 3.8 The canvas is kind-driven, not graph-only

Per report 111 §5 — the canvas pane renders whatever kind is
selected. flow-graph today; astrological chart, timelines,
maps, calendars in the future. Each kind registers a renderer
in mentci-lib that produces kind-specific view-state for the
shell to paint.

---

## 4 · The constructor flow that's wired

The first edit-half flow lands as `OpenNewNodeFlow`:

1. User clicks `+ node` button in the canvas pane (top right
   of the canvas area).
2. `UserEvent::OpenNewNodeFlow` emitted.
3. mentci-lib sets `active_constructor = Some(NewNode(flow))`
   with empty name + chosen graph slot.
4. Next `view()` produces `WorkbenchView.constructor =
   Some(ConstructorView::NewNode(...))`.
5. mentci-egui paints a centered modal: kind picker + name
   text input + cancel/commit buttons.
6. Typing emits `ConstructorFieldChanged { Text {
   field_name:"name", value } }`.
7. Commit emits `ConstructorCommit` → mentci-lib builds
   `Frame { Body::Request(Assert(Node{name})) }` →
   `Cmd::SendCriome` → driver writes to socket → criome
   accepts → `OutcomeArrived(Ok)` flows back.
8. Subscribe pushes refresh the cache → next view derivation
   shows the new node on the canvas.

Drag-wire / rename / retract / batch flows are stubbed in
mentci-lib's enums but their constructor bodies are
placeholder `(this constructor flow lands in a later
iteration)`.

---

## 5 · Nix wiring delivered

### 5.1 mentci-lib `flake.nix`

- crane + fenix per
  [lore/rust/nix-packaging.md](https://github.com/LiGoldragon/lore/blob/main/rust/nix-packaging.md)
- `packages.default` = `craneLib.buildPackage` with
  `cargoArtifacts` for layered cache
- `checks.default` = `craneLib.cargoTest`
- `devShells.default` includes toolchain + jujutsu +
  pkg-config

### 5.2 mentci-egui `flake.nix`

- Same crane+fenix base
- Plus `guiBuildInputs`: libxkbcommon, libGL, vulkan-loader,
  wayland, xorg.lib{X11,Xcursor,Xi,Xrandr,xcb}, fontconfig
- Plus `pkg-config` + `makeWrapper` in nativeBuildInputs
- `postInstall` wraps `$out/bin/mentci-egui` with
  `--prefix LD_LIBRARY_PATH : "${runtimeLibPath}"` so dlopen-
  loaded wayland/xkbcommon resolves at runtime
- devshell exports same `LD_LIBRARY_PATH` so `cargo run`
  works in the shell

### 5.3 mentci workspace

- mentci-lib + mentci-egui added as flake inputs, following
  nixpkgs/fenix/crane from workspace lock
- `checks/default.nix` linkFarm grew from 7 → 9 crate-checks
- New `checks/scenario-mentci-lib-handshake.nix` — full E2E
  test that spawns criome-daemon, runs the handshake bin,
  asserts the expected event stream

### 5.4 Toolchain bump

`rust-toolchain.toml` channel changed from `"1.85"` →
`"stable"` in mentci-lib + mentci-egui. cargo 1.85.1 lacks
`--exclude-lockfile` (added in 1.94) which the current crane
requires for git-dep vendoring. Other repos still on 1.85
because their cached vendor results survive; they'll need
the same bump if rebuilt fresh.

---

## 6 · What's still placeholder / partially wired

- **Mutate / Retract / AtomicBatch** verbs in criome — still
  M1-deferred. Subscribe doesn't see deletion / mutation
  events.
- **Subscription scope optimization** — every Assert re-runs
  every subscription's full query. Fine at MVP volume; needs
  indexing when scale demands.
- **Driver doesn't distinguish QueryReplied from
  SubscriptionPush** — both come in as `Reply::Records` on
  the wire; the driver emits `QueryReplied` for both. Sub-id
  tracking on the driver lands when subscriptions need to be
  individually addressable.
- **Drag-wire / rename / retract / batch constructor flows**
  — mentci-lib enum slots exist but commit-bodies fall
  through with the flow restored. Only NewNode commits.
- **Canvas paint of fancier kinds** (astro chart) — only
  flow-graph renderer is wired. Adding a kind = new
  submodule in mentci-lib::canvas + matching dispatch in
  mentci-egui::render::canvas.
- **Nexus daemon connection from mentci-lib** — driver code
  for nexus side dials but doesn't yet send any rendering
  requests. The "[as nexus]" lines in inspector + wire pane
  stay None.
- **Theme/Layout records flow** — record kinds exist in
  signal; mentci-lib has built-in defaults (`ThemeState`,
  `LayoutState`); reading a Theme record from sema and
  applying it isn't wired yet.
- **Schema-aware constructor narrowing** — the schema layer
  in mentci-lib has the trait but `CompiledSchema::kinds()`
  etc. are `todo!()`. Constructor flows currently surface a
  hardcoded `["Node"]` kind list.
- **Engine-wide wire-tap** — documented for later in report
  111 §16; not implemented. Wire pane shows this-connection-
  only.
- **Multi-Principal** — single default Principal at slot 0;
  authz model deferred.

---

## 7 · Open questions Li has answered (for context)

These are the answers that shape current decisions. Reading
report 111 §1 captures the latest state — but as quick
context:

- **Subscribe is foundational.** Live updates ship now (done).
- **Subscribe payload = full updated record.** (done — wire
  shape is `Records::Node(Vec<(Slot, Node)>)`).
- **Schema-in-sema is the medium-term direction.** Type
  definitions of signal records become records in sema
  (datatypes-of-datatypes). Not wired yet; mentci-lib uses
  compile-time schema today.
- **Engine-wide wire-tap: yes, document for later.** (done —
  report 111 §16).
- **Identity + Tweaks: implement now.** (done — `Principal`
  and `Tweaks` kinds in signal).
- **Themes shaped by egui's rendering features, intent not
  appearance.** (done — IntentToken/GlyphToken/StrokeToken
  enums).
- **mentci-lib contract = MVU (Approach B).** Confirmed by
  Li's "your choice seems sensible" + the implementation
  proceeding without disagreement.
- **First GUI library = egui.** Confirmed by the
  reports/111-§11 deep dive + Li's "do both / yes" trajectory.
- **GUI libs are separate repos named after the library
  (`mentci-egui`, future `mentci-iced` etc.).** (done — repo
  exists at `mentci-egui`).
- **Foreign-interface bridges are not a problem.** Shim crate
  per language when Flutter etc. land.

---

## 8 · Mandatory reading list (top to bottom)

A fresh agent must read these before doing anything:

### Tier 1 — intent + ground rules

1. **`workspace/INTENTION.md`** — clarity > correctness >
   introspection > beauty; no time estimates; no MVP framings
   as design-shaping language; agents propose, Li decides.
2. **`workspace/AGENTS.md`** — process rules, jj+always-push,
   document-layer separation. The architecture banner points
   to criome's ARCH.

### Tier 2 — engine architecture

3. **`criome/ARCHITECTURE.md`** (the canonical doc, 945 lines,
   13 visuals, 13 sections). The four invariants A-D in §2
   are non-negotiable.
4. **`workspace/reports/111-first-mentci-ui-introspection-2026-04-29.md`**
   — the design report this implementation tracks against. v4
   covers the deep dive on contract shape + the GUI library
   survey + records-with-slots + identity+Tweaks + theme
   records + engine-wide wire-tap.

### Tier 3 — programming discipline

5. **`lore/rust/style.md`** — methods on types,
   no ZST method holders, typed Error enum per crate via
   thiserror, full-words naming, `One Rust crate per repo`.
6. **`lore/programming/abstractions.md`** —
   every reusable verb belongs to a noun.
7. **`lore/programming/push-not-pull.md`** —
   producers push; no polling fallback ever.
8. **`lore/programming/micro-components.md`** —
   one capability, one crate, one repo.
9. **`lore/rust/nix-packaging.md`** — crane +
   fenix flake layout (was followed exactly for mentci-lib +
   mentci-egui).
10. **`lore/rust/rkyv.md`** — the pinned
    feature set (`std + bytecheck + little_endian +
    pointer_width_32 + unaligned`); rkyv 0.8.x.
11. **`lore/rust/ractor.md`** — the actor
    pattern criome uses (4-piece per file).

### Tier 4 — workbench design (delete-eligible after this
session, but high-context until then)

12. **`workspace/reports/108-flow-graph-three-projections-2026-04-28.md`**
    — flow-graph as shared substrate.
13. **`workspace/reports/112-session-handoff-2026-04-29.md`** —
    this report.

### Tier 5 — sibling-repo niches

Read each repo's `ARCHITECTURE.md` when working in it:

14. `signal/ARCHITECTURE.md`
15. `nexus/ARCHITECTURE.md` — bright-line "translate
    signal↔nexus, nothing else"
16. `criome/src/lib.rs` (module-level docs)
17. `mentci-lib/ARCHITECTURE.md`
18. `mentci-egui/ARCHITECTURE.md`
19. `forge/ARCHITECTURE.md`
20. `arca/ARCHITECTURE.md`
21. `signal-forge/ARCHITECTURE.md`
22. `prism/ARCHITECTURE.md`
23. `sema/ARCHITECTURE.md`

---

## 9 · Files to explore via agent (with intent)

When picking up a thread, dispatch an Explore agent to read
groups together:

### Group A — wire and protocol

- `signal/src/lib.rs` (re-exports)
- `signal/src/frame.rs` (envelope: `Frame { principal_hint,
  auth_proof, body }`, length-prefixed encode/decode)
- `signal/src/request.rs` (`Request` enum: Handshake / Assert
  / Mutate / Retract / AtomicBatch / Query / Subscribe /
  Validate)
- `signal/src/reply.rs` (`Reply` enum + `Records` variants
  with `Vec<(Slot, T)>` shape)
- `signal/src/flow.rs` (Node, Edge, Graph + queries +
  RelationKind enum with 9 variants)
- `signal/src/auth.rs` (AuthProof; `SingleOperator` MVP)
- `signal/src/handshake.rs` (HandshakeRequest /
  HandshakeReply / `SIGNAL_PROTOCOL_VERSION`)
- `signal/src/{identity,tweaks,style,layout,keybind}.rs` (the
  new record kinds Li approved this session)

### Group B — criome engine + reader

- `criome/src/lib.rs` (module entry + re-exports)
- `criome/src/main.rs` (criome-daemon entry; binds
  `/tmp/criome.sock`)
- `criome/src/listener.rs` (UnixListener accept loop)
- `criome/src/connection.rs` (per-connection actor; reads
  frames, dispatches; **handles Subscribe requests +
  SubscriptionPush messages**)
- `criome/src/engine.rs` (write actor; **holds
  Vec<Subscription> + push_subscriptions on writes**)
- `criome/src/reader.rs` (query handler; **decode_kind now
  preserves slot through to `Vec<(signal::Slot, T)>`**)
- `criome/tests/engine.rs` (6 tests covering Assert + Query
  destructuring)

### Group C — mentci-lib (the heavy library)

- `mentci-lib/src/lib.rs` (module entry)
- `mentci-lib/src/state.rs` (`WorkbenchState`, `ModelCache`,
  `view()`, `on_user_event`, `on_engine_event`, the auto-
  subscribe-on-connect logic, `commit_active_constructor`,
  `build_flow_graph_view`)
- `mentci-lib/src/event.rs` (UserEvent + EngineEvent enums)
- `mentci-lib/src/cmd.rs` (Cmd enum)
- `mentci-lib/src/view.rs` (WorkbenchView snapshot types)
- `mentci-lib/src/connection/mod.rs` (ConnectionState +
  DaemonStatus)
- `mentci-lib/src/connection/driver.rs` (**tokio task with
  UDS dial + handshake exchange + tokio::select for
  read/cmd loop + emit_inbound_typed routing Reply variants
  to engine events**)
- `mentci-lib/src/canvas/mod.rs` + `canvas/flow_graph.rs`
  (per-kind canvas state + RenderedNode / RenderedEdge)
- `mentci-lib/src/constructor.rs` (5 active-constructor
  variants; only NewNode is commit-wired)
- `mentci-lib/src/{schema,theme,layout,inspector,
  diagnostics,wire}.rs`
- `mentci-lib/examples/handshake.rs` (the E2E verification
  binary; aliased as `[[bin]] mentci-handshake-test`)

### Group D — mentci-egui (the thin shell)

- `mentci-egui/src/main.rs` (eframe::run_native + tokio
  Runtime ownership)
- `mentci-egui/src/app.rs` (`MentciEguiApp` impl
  `eframe::App` — the 5-step per-frame loop;
  bootstrap_if_needed; execute_cmd routing Cmds to drivers)
- `mentci-egui/src/render/workbench.rs` (multi-pane layout
  composition)
- `mentci-egui/src/render/header.rs` (daemon connection
  chips)
- `mentci-egui/src/render/canvas/{mod,flow_graph}.rs`
  (canvas dispatch + paint with egui Painter)
- `mentci-egui/src/render/{inspector,diagnostics,wire,
  constructor}.rs`

### Group E — nix infrastructure

- `mentci-lib/flake.nix` (canonical crane+fenix shape)
- `mentci-egui/flake.nix` (with eframe native deps +
  postInstall wrapper)
- `workspace/flake.nix` (workspace inputs, blueprint-driven)
- `workspace/checks/default.nix` (linkFarm of 9 crate checks)
- `workspace/checks/scenario-mentci-lib-handshake.nix` (the new
  E2E)
- `workspace/checks/integration.nix` +
  `roundtrip-chain.nix` + `scenario-chain.nix` (existing
  scenarios; updated for `(Tuple <slot> ...)` text shape)
- `lore/rust/nix-packaging.md` (the canonical
  doc)

### Group F — workspace orchestration

- `workspace/AGENTS.md` (process rules)
- `workspace/INTENTION.md` (intent — read first)
- `workspace/ARCHITECTURE.md` (workspace shape)
- `workspace/devshell.nix` + `mentci.code-workspace` (linkedRepos
  symlinks; both list mentci-lib + mentci-egui)
- `workspace/docs/workspace-manifest.md` (CANON / TRANSITIONAL /
  SHELVED tables; mentci-lib + mentci-egui added)

---

## 10 · Suggested next checkpoints (in roughly increasing
investment order)

1. **Mutate / Retract** in criome's engine actor — currently
   M1-deferred. Until they land, re-running Subscribe is the
   only way to see record changes; deletions are invisible.
2. **Drag-wire constructor flow** — mentci-lib's NewEdge slot
   exists; needs commit body that builds `Assert(Edge)`.
3. **Schema knowledge from compile-time signal types** —
   `mentci-lib::schema::CompiledSchema::kinds()` etc. fill
   in. Generates real kind-choice palettes for constructor
   flows.
4. **Reading Theme + Layout records on connect** — query for
   the active Principal's Tweaks; resolve referenced theme
   slot; apply.
5. **mentci-egui visual polish** — actual icon font for
   ⊙⊡⊠⊕▶ glyphs, real palette per ThemeIntent, smooth
   pan/zoom on the canvas.
6. **Subscribe sub-id tracking** — driver distinguishes
   QueryReplied from SubscriptionPush, lets the model invalidate
   one subscription without dropping all.
7. **Records-with-slots text format compaction** — currently
   renders as `(Tuple 1024 (Node "..."))`. A more compact
   form (e.g. `1024:(Node "...")`) would be a wire-text
   ergonomics win. Requires nota-codec change.
8. **mentci-iced as second family member** — exercises
   mentci-lib's contract from a literal-Elm-arch angle.

---

## 11 · Recent gotchas (so the next session doesn't repeat)

- **cargo 1.85.1 lacks `--exclude-lockfile`.** Crane's vendor
  step requires it (added in cargo 1.94). Fix: bump
  `rust-toolchain.toml` channel to `"stable"`. mentci-lib +
  mentci-egui already done. Other repos work because their
  vendored deps are cached; they'll need the same bump on
  fresh rebuild.
- **fenix toolchain hash differs across nixpkgs revisions.**
  Current correct hash for stable channel:
  `sha256-gh/xTkxKHL4eiRXzWv8KP7vfjSk61Iq48x47BEDFgfk=`. If
  nixpkgs is updated, fenix will print the new expected hash
  in the build error.
- **eframe needs LD_LIBRARY_PATH.** wayland-client and
  libxkbcommon are dlopen-loaded at runtime. mentci-egui's
  flake handles this via postInstall makeWrapper. The
  devshell also exports it.
- **records-with-slots breaks text-form expectations.** Old
  tests asserted `[(Node "User")]`; new shape is
  `[(Tuple 1024 (Node "User"))]`. Three workspace E2E
  scenarios were migrated. signal + nexus + criome unit
  tests also migrated.
- **bash heredoc + jj commit message + parens + special
  chars.** Some commit messages with code samples fail to
  parse; quote carefully.
- **cargo update -p X says "Locking 0 packages" but doesn't
  fetch.** Use `cargo update X --precise <hash>` or
  `--aggressive` to force.
- **criome's signal listener was already wired before this
  session.** Subscribe was the only verb that was M2-deferred
  (`deferred("Subscribe", "M2")`); this session implemented
  it. Mutate / Retract / AtomicBatch are still deferred.
- **mentci-lib's auto-fetch on connect was Query, then
  switched to Subscribe.** The model treats both
  identically — both produce `EngineEvent::QueryReplied`
  via the driver, both absorb into `ModelCache`. The wire
  difference (Subscribe registers ongoing pushes; Query
  doesn't) determines whether the canvas auto-updates.
- **cargo Cargo.lock placement.** mentci-lib's Cargo.lock is
  committed; mentci-egui's likewise. crane needs them for
  vendoring inside the sandbox.
- **`gh repo create` silently succeeds.** No rule against
  agents creating GitHub repos exists in the workspace
  (verified by grep). Do it directly when needed.

---

## 12 · Key one-liners for resuming work

```bash
# Run the workbench against a live criome
rm -f /tmp/criome.sock /tmp/sema.redb
SEMA_PATH=/tmp/sema.redb cargo run --manifest-path \
  /home/li/git/criome/Cargo.toml --bin criome-daemon &
cargo run --manifest-path /home/li/git/mentci-egui/Cargo.toml

# Run the E2E example as a sanity check
cargo run --manifest-path /home/li/git/mentci-lib/Cargo.toml \
  --example handshake

# Workspace nix flake check (full workspace)
nix flake check  # from /home/li/git/mentci

# Single-crate cargo test
cargo test --manifest-path /home/li/git/<crate>/Cargo.toml

# Single-crate nix flake check (from inside the crate)
nix flake check  # from /home/li/git/mentci-lib (or mentci-egui)
```

---

## 13 · Lifetime

This report lives until the next session reads it. Then
either:

- It's superseded by a new handoff report (delete this one,
  write a fresh successor).
- The work it describes has progressed enough that some
  threads have moved into ARCHITECTURE.md updates or new
  reports for new threads (in which case the still-current
  bits stay here, the absorbed bits get trimmed).

---

## 14 · One-paragraph state

The introspection workbench's first checkpoint is reached and
verified end-to-end. Click a graph in the GraphsNav, the
canvas paints; click "+ node", a modal opens; commit, the
record asserts in criome and the canvas auto-updates via
Subscribe push. Records carry their sema slots on the wire.
Every layer (signal types, criome engine, mentci-lib MVU,
mentci-egui paint, nix packaging, E2E nix tests) builds
green from cold cache. The dance — design / implement /
review — has produced answers no amount of pre-design
produced. What's next is incremental from here.

---

*End report 112.*
