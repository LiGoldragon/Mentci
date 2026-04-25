# 073 — rkyv derives, criome-types, and unit tests

*Claude Opus 4.7 · 2026-04-25 · synthesis of three parallel
audits (rkyv-derive landing strategy, speculative
criome-types creation, nearest-demonstrable-progress).
Three tracks identified. Track-A lands today (no Li input);
Tracks B + C await one short Li nod each.*

---

## 1 · Where this fits

Tracks 1 + 2 (subset) of [reports/072](repos/mentci-next/reports/072-multi-angle-audit-and-path-forward.md)
are landed: corpus cleanup applied; `lojix-store` has real
bodies for hex + layout utilities; `nexusd::client_msg`
has `RequestId::fresh` + `WirePath` newtype.

The remaining work splits into three new tracks.

---

## 2 · Track A — unit tests (lands today)

The bodies that just landed are real implementations of leaf
utilities. Each one is testable now, no new dependencies, no
Li input. Nine tests across two repos.

### 2.1 · `lojix-store` tests

- **`hash::roundtrip_preserves_identity`** — `StoreEntryHash`
  through `to_hex` / `from_hex` is the identity. ~10 LoC.
- **`hash::from_hex_rejects_wrong_length`** — short / long
  inputs return `HashParseError::WrongLength`. ~5 LoC.
- **`hash::from_hex_rejects_non_hex_chars`** — non-hex bytes
  return `HashParseError::InvalidHex`. ~5 LoC.
- **`hash::from_hex_accepts_mixed_case`** — uppercase hex
  decodes to the same bytes as lowercase. ~5 LoC.
- **`layout::default_path_ends_with_store_dir`** — path always
  ends with `.lojix/store` regardless of `$HOME`. ~5 LoC.
- **`layout::entry_tree_appends_hex`** — `entry_tree(hash)`
  is `root.join(hash.to_hex())`. ~7 LoC.
- **`layout::index_db_path_is_inside_root`** — index path is
  `<root>/index.redb`. ~5 LoC.

### 2.2 · `nexusd` tests

- **`client_msg::frame::fresh_ids_are_unique`** — 100
  sequential `RequestId::fresh()` calls produce 100 unique
  IDs (UUID v7 contains a monotonic counter). ~10 LoC.
- **`client_msg::path::from_path_round_trip`** — `WirePath`
  round-trips a `Path`, including non-UTF8 byte sequences
  (Unix-only test). ~10 LoC.

Total: ~60 LoC of test code; zero new Cargo deps.

---

## 3 · Track B — rkyv derives across protocol types

This unlocks `Frame::encode` / `Frame::decode` real bodies and
makes wire-format round-trip testable. Per audit-A:

### 3.1 · Cargo additions to `nexusd`

Match `nexus-schema`'s rkyv config exactly so archived types
interop:

```toml
[dependencies]
rkyv = { version = "0.8", default-features = false, features = [
    "std", "bytecheck", "little_endian",
    "pointer_width_32", "unaligned"
] }
```

### 3.2 · Per-type derives

Add `#[derive(Archive, RkyvSerialize, RkyvDeserialize)]` to:

- `Frame`, `Body`, `RequestId`, `Request`, `Reply`,
  `WorkingStage`, `FallbackSpec`, `FallbackFormat`, `WirePath`

No custom attributes needed; rkyv 0.8 derives correctly for
mixed-variant enums, `Vec<T>`, `String`, primitives, and
nested types. `Archived<u128>` is 16 bytes (pinned little-
endian by features).

### 3.3 · `Frame::encode` / `Frame::decode` bodies

```rust
pub fn encode(&self) -> Vec<u8> {
    rkyv::to_bytes::<rkyv::rancor::Error>(self)
        .expect("rkyv serialisation never fails for owned data")
        .to_vec()
}

pub fn decode(bytes: &[u8]) -> Result<Self, FrameDecodeError> {
    let archived = rkyv::access::<ArchivedFrame, rkyv::rancor::Error>(bytes)
        .map_err(|_| FrameDecodeError::BadArchive)?;
    rkyv::deserialize::<Self, rkyv::rancor::Error>(archived)
        .map_err(|_| FrameDecodeError::BadArchive)
}
```

(Exact API surface to verify against rkyv 0.8 source on land.)

### 3.4 · Round-trip test

Construct a `Frame { request_id, body: Request::Send {...} }`
with non-trivial fields including a `WirePath`; encode;
decode; assert structural equality. ~30 LoC.

### 3.5 · What lands

~50 LoC across nexusd (Cargo.toml + 9 derive lines + 2 body
implementations + 30 LoC test). Cargo check + cargo test
pass. Wire format proven end-to-end without nexusd or
criomed running.

---

## 4 · Track C — `criome-types` crate

Per [reports/072 §4](repos/mentci-next/reports/072-multi-angle-audit-and-path-forward.md):
a tiny shared crate (~410 LoC) housing `Slot`, `Revision`,
`Blake3Hash`, `LiteralValue`, `PrimitiveType`, `ChangeOp`,
`Op`, plus eventually `WirePath` (currently in nexusd).

Audit-B argued the case for **proceeding speculatively** —
i.e., creating it now without explicit Li confirmation of
[reports/072 Q1](repos/mentci-next/reports/072-multi-angle-audit-and-path-forward.md):

- **Cost of any Li override**: ~30 minutes of mechanical
  refactor (delete crate + copy types, or move types into
  another crate). The ~410 LoC of leaf-newtype source is not
  wasted in any scenario — it ships in some form.
- **Benefit unlocked**: criome-msg + criome-schema + sema
  scaffolds (~1500–2000 LoC) become parallel-safe.
- **Asymmetry**: low downside × low override probability vs
  high upside × high ratification probability.

The audit recommended proceeding. I'm holding off pending an
explicit Li nod because creating a new repo (gh repo create
under LiGoldragon org, GitHub-visible artifact) is a
different class of action than internal code edits — even
under "always push." Li's call.

---

## 5 · Sequencing

```
Track A — unit tests (TODAY, no Li input)
  └── ~60 LoC; lojix-store + nexusd; ~9 tests
  └── cargo test passes in both repos

Track B — rkyv derives (TODAY-ish, ~30 min)
  └── needs verification of rkyv 0.8 API
  └── ~50 LoC across nexusd
  └── unlocks Frame round-trip testability
  └── confirmed by Li or self-verified against rkyv 0.8 source

Track C — criome-types crate creation
  └── needs Li nod (or self-authorisation per "always push")
  └── ~410 LoC + workspace-manifest + devshell.nix updates
  └── unlocks parallel scaffolding of criome-msg + criome-schema + sema

After all three: Q-α + Q-β unlock criome-schema + criomed
scaffolds.
```

---

## 6 · Two short Li questions

### Q1 · Track B — proceed with rkyv derives now?

Audit-A's API sketch is grounded in the rkyv 0.8 surface but
not verified against actual current source. Two paths:

- (a) Self-verify by reading rkyv 0.8 source/docs, then land.
- (b) Land alongside criome-types so any rkyv usage is in a
  single first-time-rkyv crate that we can pattern-match
  against later crates.

Lean: (a). It's a leaf addition; if the API differs from the
sketch, fix in place.

### Q2 · Track C — proceed speculatively?

Per audit-B's recommendation, create `criome-types` now
without waiting for explicit confirmation of
[reports/072 Q1](repos/mentci-next/reports/072-multi-angle-audit-and-path-forward.md).
Override later costs ~30 min if Li disagrees. Confirm
"yes, go" or "wait."

---

## 7 · Carried forward (still blocking later work)

- Q-α from [reports/067](repos/mentci-next/reports/067-what-to-implement-next.md) — confirm ~15-kind v0.0.1 set
- Q-β from [reports/067](repos/mentci-next/reports/067-what-to-implement-next.md) — genesis principal mechanism
- Q4 from [reports/071](repos/mentci-next/reports/071-cli-protocol-and-implementation-order.md) — cancel-criomed verb in criome-msg
- Items 5–6 from [reports/072 §2](repos/mentci-next/reports/072-multi-angle-audit-and-path-forward.md) (machina in §1 prose; architecture.md timestamp)

---

*End report 073.*
