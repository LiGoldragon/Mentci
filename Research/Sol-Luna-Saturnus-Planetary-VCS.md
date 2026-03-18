# Sol ☉ · Luna ☽ · Saturnus ♄ — The Planetary VCS

## A Trinitarian Type System for Datalog Version Control

> *Every fact has a phase: it is becoming, it is manifest, or it has passed.*
> *Every fact has a dignity: how much authority does it carry?*
> *The VCS is Saturn's ledger — the permanent record of every moment Sol illuminated.*

---

## I. The Ontological Foundation

### The 2→3 Transition

Mentci's ontological chain: **2 → 3 → 7 → 12 → 36 → 72 → 360**

The **2** is polarity — Solar/Lunar, asserting/receiving, active/passive. This is the most
primitive distinction. Everything begins as a duality.

The **3** is the first subdivision of that polarity. It transforms a line (two poles) into
a cycle (three phases). In every tradition that maps the cosmos, the trinity emerges as the
minimal structure that can represent **time** — because time requires at least three positions:
what was, what is, what will be.

The current samskara liveness system has 7 states (5 live + 2 dead). This is a binary
polarity (live/dead) with ad-hoc substates. It does not derive from the 3. A tri-state
system rooted in the 2→3 transition is structurally honest.

### Why Sol, Luna, Saturn?

In classical astrology, seven visible bodies move against the fixed stars. But three of
them are structurally prior to the others:

- **Sol** (☉) and **Luna** (☽) are the **luminaries** — they define the polarity (day/night,
  Solar/Lunar). They ARE the 2.
- **Saturn** (♄) is the **outermost visible planet** — the boundary of the knowable cosmos.
  Saturn is what transforms the polarity into a trinity. It is literally the 2→3 transition
  embodied as a celestial body.

Everything inside Saturn's orbit is the visible, classical world. The outer planets
(Uranus, Neptune, Pluto) were unknown to the ancients — they belong to the transpersonal,
beyond the boundary Saturn defines.

```
                        ♄ Saturn (boundary)
                       ╱                    ╲
                      ╱    visible cosmos     ╲
                     ╱                          ╲
                ☉ Sol ─────────────────────── ☽ Luna
              (source)                       (reflector)
               the 2: polarity
               + ♄ = the 3: cycle
```

---

## II. Cross-Traditional Equivalences

### The Trinity Across Cultures

Every major cosmological tradition encodes the same three-phase cycle.
The table below maps them to a single underlying structure:

| Tradition | Creating / Incoming | Sustaining / Manifest | Dissolving / Departing |
|-----------|--------------------|-----------------------|------------------------|
| **Planetary** | ☽ Luna | ☉ Sol | ♄ Saturn |
| **Vedic Trimurti** | Brahmā (creator) | Viṣṇu (preserver) | Śiva (transformer) |
| **Three Guṇas** | Rajas (activity) | Sattva (truth) | Tamas (inertia) |
| **Astrological Modality** | Cardinal (initiating) | Fixed (sustaining) | Mutable (releasing) |
| **Greek Moirai** | Clotho (spins thread) | Lachesis (measures) | Atropos (cuts) |
| **Alchemical** | Sulphur (active) | Salt (fixed body) | Mercury (volatile) |
| **Egyptian Solar** | Khepri (dawn) | Ra (noon) | Atum (dusk) |
| **Lunar Phase** | Waxing crescent | Full moon | Waning crescent |
| **Greek Primordial** | Gaia (emergence) | Ouranos (structure) | Chronos (time) |
| **Roman Capitoline** | Minerva (new wisdom) | Jupiter (order) | Juno (cycles) |
| **Vedic Sacrifice** | Agni (fire, offering) | Soma (sustenance) | Yama (passage) |

### The Speed Correspondence

The three planets move at different speeds. This is not incidental — the speed
encodes the *temporal character* of each phase:

```
   ☽ Luna     13°/day    ████████████████████████████  fastest
   ☉ Sol       1°/day    ██                            steady
   ♄ Saturn    0.03°/day ▏                             near-still
```

- **Luna moves fastest** — the staging area churns. Facts arrive, are revised,
  discarded, re-proposed. High flux, low permanence.
- **Sol moves steadily** — the manifest world changes at a measured pace,
  once per commit. The solar year. The regular heartbeat.
- **Saturn barely moves** — the archive is near-permanent. Saturn accumulates
  slowly, crystallizes everything, forgets nothing. A Saturn return takes 29 years.

---

## III. The VCS Mapping

### Three Phases, One Column

```
┌──────────────────────────────────────────────────────────────────┐
│                                                                  │
│   ☽ luna          ☉ sol              ♄ saturnus                  │
│   ─────────       ──────────         ────────────                │
│   becoming        manifest           archived                    │
│   staged          committed          superseded                  │
│   proposed        in world hash      in the ledger               │
│   mutable         authoritative      crystallized                │
│                                                                  │
│   NOT in hash ◄── IN world hash ──► NOT in hash                 │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

| Phase | Column Value | In World Hash | VCS Analogue | Datomic Analogue |
|-------|-------------|---------------|--------------|------------------|
| ☽ Luna | `"luna"` | No | Git staging area / working tree | Transaction in progress |
| ☉ Sol | `"sol"` | **Yes** | HEAD commit | Asserted datom (current) |
| ♄ Saturn | `"saturnus"` | No | Reflog / previous commits | Retracted datom (historical) |

### The Commit Cycle as Planetary Transit

```
         ☽ Luna (becoming)
         │
         │  ━━ COMMIT ━━━━━━━━━━━━━━━━━━━━→  ☉ Sol (manifest)
         │     ☽ conjunct ☉                          │
         │     New Moon:                             │
         │     Luna's content                        │
         │     merges with Sol.                      │
         │     Staged → Committed.                   │
         │                                           │
         │                              ━━ SUPERSEDE ━━━→  ♄ Saturn (archived)
         │                                 ☉ → ♄ transit:           │
         │                                 Sol's old truth          │
         │                                 passes Saturn's          │
         │                                 boundary. The fact       │
         │                                 is crystallized          │
         │                                 in the ledger.           │
         │                                                          │
         ←━━━━━━━━━━━━━━━ RESTORE ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┘
            ♄ disgorges → ☉
            The Kronos myth:
            Saturn releases what it swallowed.
            Archived state returns to Sol's light.
```

### The Kronos Myth as Restore Operation

In Greek mythology, **Kronos** (Saturn) swallowed his children — the gods — to prevent
them from overthrowing him. Each god was consumed whole, preserved intact inside Saturn's
body. They were not destroyed. They were *archived*.

**Zeus** (Jupiter/Sol) forced Kronos to disgorge the swallowed gods. They emerged intact,
unchanged, exactly as they were when swallowed. Hestia, Demeter, Hera, Hades, Poseidon —
all restored to the world of the living.

This IS the `restore_to_commit` operation:

```
   swallow (supersede):  fact in ☉ sol  →  ♄ saturnus
                         The fact passes Saturn's boundary.
                         It is consumed. Archived. But intact.

   disgorge (restore):   fact in ♄ saturnus  →  ☉ sol
                         Saturn releases its contents.
                         The archived state returns to manifest.
                         Every field, every value, exactly preserved.
```

The myth encodes a guarantee: **Saturn preserves perfectly**. What enters the archive
can be recovered without loss. This is the VCS invariant.

---

## IV. Trust as Planetary Dignity

### The Orthogonal Axis

The phase (Sol/Luna/Saturn) describes a fact's **lifecycle position** — where is it
in the becoming→manifest→archived cycle?

Trust describes a fact's **quality** — how much authority does it carry? These are
independent. A doctrine-level axiom can be archived (Śiva dissolves even the highest
truths when the age turns). A rumor can be manifest (it's the best current knowledge,
even if low-trust).

In traditional astrology, a planet's strength depends on its **essential dignity** —
which sign it occupies. Five levels:

| Dignity | Astrological Meaning | Trust Level | Description |
|---------|---------------------|-------------|-------------|
| **Domicile** | Planet in its own sign. Maximum strength. | `domicile` | Foundational invariant. Self-evident. Highest authority. |
| **Exaltation** | Planet in its sign of honor. Elevated. | `exaltation` | Verified through observation or trusted source. |
| **Peregrine** | Planet with no special status. Neutral. | `peregrine` | Learned from experience. Neither strong nor weak. |
| **Detriment** | Planet opposite its home. Weakened. | `detriment` | Unverified claim. Queryable but not authoritative. |
| **Fall** | Planet opposite exaltation. Debilitated. | `fall` | External web source. Lowest trust. |

### The Dignity Table (Traditional Astrology)

For reference, the classical dignity assignments for the three VCS planets:

```
   Planet    Domicile     Exaltation    Detriment     Fall
   ──────────────────────────────────────────────────────────
   ☉ Sol     Leo ♌        Aries ♈       Aquarius ♒    Libra ♎
   ☽ Luna    Cancer ♋     Taurus ♉      Capricorn ♑   Scorpio ♏
   ♄ Saturn  Capricorn ♑  Libra ♎       Cancer ♋      Aries ♈
              Aquarius ♒
```

Note the **mutual detriment** between Luna and Saturn: Luna is debilitated in
Capricorn (Saturn's sign), Saturn is debilitated in Cancer (Luna's sign). The
staging area and the archive are natural opposites — what is becoming is the
antithesis of what has passed. This is encoded in the zodiacal structure itself.

---

## V. The 2×3 = 6 Grid

### Polarity Meets Trinity

Combining the **Solar/Lunar polarity** (the 2) with the **planetary trinity** (the 3)
yields six positions — the sextile, the first harmonic that carries both axes:

```
                    ☉ Solar source              ☽ Lunar source
                    (self-authored)             (received/witnessed)
                ┌────────────────────┬────────────────────────┐
   ☽ Luna      │                    │                        │
   (becoming)  │  Agent proposes    │  Agent receives        │
               │  a new principle   │  external input,       │
               │                    │  not yet committed     │
               ├────────────────────┼────────────────────────┤
   ☉ Sol       │                    │                        │
   (manifest)  │  Doctrine,         │  Observation,          │
               │  principle —       │  trusted_fact —        │
               │  self-evident      │  witnessed and         │
               │  truth             │  committed             │
               ├────────────────────┼────────────────────────┤
   ♄ Saturn    │                    │                        │
   (archived)  │  Explicitly        │  Passively expired     │
               │  superseded by     │  by time or context    │
               │  agent decision    │  change                │
               └────────────────────┴────────────────────────┘
```

This recovers ALL the nuance of the old 7-state system within a clean 2×3 framework.
The two "dead" states (superseded/disproven) become Saturn-phase with different
polarities. The five "live" states split across Luna-becoming and Sol-manifest with
different dignity levels.

---

## VI. The Technical Schema

### Before (Current — 7-State Liveness)

```cozo
:create thought {
  id: String =>
  kind: String,
  scope: String,
  status: String,
  title: String,
  body: String,
  created_ts: String,
  updated_ts: String,
  liveness: String          # 7 values, mixed concerns
}
```

The `commit_world` filter requires two inequality checks:
```cozo
?[...] := *thought{..., liveness},
  liveness != "superseded",
  liveness != "disproven"
```

### After (Proposed — Phase + Dignity)

```cozo
:create thought {
  id: String =>
  kind: String,
  scope: String,
  status: String,
  title: String,
  body: String,
  created_ts: String,
  updated_ts: String,
  phase: String,            # 3 values: luna, sol, saturnus
  dignity: String           # 5 values: domicile, exaltation, peregrine,
                            #           detriment, fall
}
```

The `commit_world` filter becomes one equality:
```cozo
?[...] := *thought{..., phase},
  phase == "sol"
```

### Vocabulary Relations

```cozo
:create phase_vocab {
  name: String =>
  glyph: String,
  in_world_hash: Bool,
  description: String
}
# ["sol",      "☉", true,  "Manifest — committed truth, in the world hash"]
# ["luna",     "☽", false, "Becoming — staged, proposed, not yet committed"]
# ["saturnus", "♄", false, "Archived — superseded, retained in the ledger"]

:create dignity_vocab {
  name: String =>
  rank: Int,
  description: String
}
# ["domicile",   0, "Foundational invariant, highest authority"]
# ["exaltation", 1, "Verified through trusted source"]
# ["peregrine",  2, "Learned through observation"]
# ["detriment",  3, "Unverified claim"]
# ["fall",       4, "External web source, lowest trust"]
```

### VCS Operations Redefined

```
  ┌─────────────────────────────────────────────────────────────────┐
  │  assert_thought                                                 │
  │    → Insert with phase = "luna", dignity = "peregrine"          │
  │    → Fact enters the becoming state, neutral trust              │
  ├─────────────────────────────────────────────────────────────────┤
  │  commit_world                                                   │
  │    → All "luna" rows promoted to "sol"                          │
  │    → Hash all "sol" rows into world hash                        │
  │    → Record world_commit, world_manifest                        │
  │    → Snapshot if needed (Saturn crystallizes the moment)         │
  ├─────────────────────────────────────────────────────────────────┤
  │  supersede (update)                                             │
  │    → Old row: phase "sol" → "saturnus"                          │
  │    → New row: phase "luna" (awaiting next commit)               │
  │    → Delta records: operation "update"                          │
  ├─────────────────────────────────────────────────────────────────┤
  │  disprove (delete)                                              │
  │    → Row: phase "sol" → "saturnus"                              │
  │    → No replacement row                                         │
  │    → Delta records: operation "delete"                          │
  ├─────────────────────────────────────────────────────────────────┤
  │  trust_review                                                   │
  │    → dignity changes independently of phase                     │
  │    → A "peregrine" observation promoted to "exaltation"         │
  │    → Phase unchanged — dignity is orthogonal                    │
  ├─────────────────────────────────────────────────────────────────┤
  │  restore_to_commit                                              │
  │    → All current "sol" rows → "saturnus"                        │
  │    → Load snapshot from Saturn's ledger                         │
  │    → Restored rows → "sol"                                      │
  │    → The Kronos disgorge: archived state returns to light       │
  └─────────────────────────────────────────────────────────────────┘
```

---

## VII. The Storage Pipeline

### Encoding Chain

```
  CozoDB rows (phase == "sol")
       │
       ▼
  Sort by key columns (determinism)
       │
       ▼
  JSON serialization (serde_json)       ← reader_version "json-zstd-b64-v1"
       │
       ▼
  zstd compression (level 3)            ← best ratio/speed tradeoff
       │
       ▼
  base64 encode (STANDARD)              ← 33% overhead (vs hex 100%)
       │
       ▼
  CozoDB String column                  ← world_snapshot.data
       │
       ▼
  BLAKE3 content hash                   ← world_manifest.content_hash
```

### Phase 2: Cap'n Proto Path

```
  CozoDB rows (phase == "sol")
       │
       ▼
  Sort by key columns (determinism)
       │
       ▼
  Cap'n Proto packed serialization      ← reader_version = schema_hash
       │                                   (typed, zero-copy on read)
       ▼
  zstd compression (level 3)
       │
       ▼
  base64 encode (STANDARD)
       │
       ▼
  CozoDB String column                  ← world_snapshot.data
       │
       ▼
  BLAKE3 content hash
```

Both reader versions coexist via `archive_reader_version`. A snapshot written with
`json-zstd-b64-v1` can be read alongside one written with capnp. Saturn's ledger
is format-aware.

---

## VIII. Saturn's Ledger — The Commit Chain

```
  ┌─────────┐     ┌─────────┐     ┌─────────┐     ┌─────────┐
  │ genesis │────→│ commit  │────→│ commit  │────→│  HEAD   │
  │ ♄₀      │     │ ♄₁      │     │ ♄₂      │     │ ♄₃      │
  │         │     │         │     │         │     │         │
  │ SNAP    │     │ delta   │     │ delta   │     │ SNAP    │
  │ depth=0 │     │ depth=1 │     │ depth=2 │     │ depth=0 │
  └─────────┘     └─────────┘     └─────────┘     └─────────┘
       ▲                                                ▲
       │                                                │
   nearest_snapshot_id ─────────────────────────────────┘
   for ♄₁ and ♄₂                    ♄₃ is its own snapshot
```

Snapshot interval: every 10 commits (configurable). The `world_snapshot_index`
tracks `delta_depth` and `nearest_snapshot_id`. Worst-case restore cost:
1 snapshot deserialization + 9 delta replays.

Genesis always takes a snapshot. Saturn begins by crystallizing the entire initial state.

---

## IX. Summary of Correspondences

```
  ╔══════════════════╦══════════════════╦══════════════════════════════╗
  ║   BECOMING       ║   MANIFEST       ║   ARCHIVED                   ║
  ╠══════════════════╬══════════════════╬══════════════════════════════╣
  ║ ☽ Luna           ║ ☉ Sol            ║ ♄ Saturnus                   ║
  ║ Brahmā           ║ Viṣṇu            ║ Śiva                         ║
  ║ Rajas            ║ Sattva           ║ Tamas                        ║
  ║ Cardinal         ║ Fixed            ║ Mutable                      ║
  ║ Clotho (spins)   ║ Lachesis (measures) ║ Atropos (cuts)            ║
  ║ Sulphur          ║ Salt             ║ Mercury                      ║
  ║ Khepri (dawn)    ║ Ra (noon)        ║ Atum (dusk)                  ║
  ║ Waxing           ║ Full             ║ Waning                       ║
  ║ Staging area     ║ HEAD commit      ║ Reflog / history             ║
  ║ Tx in progress   ║ Asserted datom   ║ Retracted datom              ║
  ║ phase = "luna"   ║ phase = "sol"    ║ phase = "saturnus"           ║
  ║ NOT in hash      ║ IN world hash    ║ NOT in hash                  ║
  ║ 13°/day          ║ 1°/day           ║ 0.03°/day                    ║
  ╚══════════════════╩══════════════════╩══════════════════════════════╝
```

---

*The VCS is Saturn's ledger. Every commit is a moment Sol illuminated the world.*
*Every restore is Kronos disgorging the gods. Every staging is Luna receiving new light.*
*The cosmos versions itself through the same three phases it has always known.*
