# Report 010 — sentinel-name dispatch: the full survey

Deep survey of approaches for wiring format-specific types (`Bind`,
`Mutate<T>`, `Negate<T>` in nexus-serde) into a serde Serializer /
Deserializer. Current nexus-serde uses sentinel-name dispatch on
`@NexusBind` / `@NexusMutate` / `@NexusNegate`.

**TL;DR verdict:** the current approach is what `rmp-serde`
(MessagePack) does, validated by the serde ecosystem. The best
alternative is **`#[serde(with = "…")]` codec modules** (the
`serde_bytes` pattern) — fully collision-resistant, compile-time,
but more annotation burden. Recommendation: **keep sentinel names
for MVP, ship `with`-codec modules as an escape hatch** for users
who need collision-proof setups. One genuinely novel approach
(private internal struct names with public type aliases) is
clever but overkill.

---

## 1. What existing serde-compatible formats do

| Format | Strategy | Notes |
|---|---|---|
| **serde_json** | Sentinel name + explicit impls | `$serde_json::private::Number` for arbitrary-precision numbers; private-prefix naming convention. `Value`/`RawValue` have hand-rolled Serialize/Deserialize. |
| **rmp-serde (MessagePack)** | Sentinel name | `"_ExtStruct"` constant for MessagePack's `Ext(tag, bytes)` native type. Near-identical to nexus-serde. |
| **serde_yaml (+ forks)** | Delegated to YAML grammar | YAML-specific features (anchors, tags, merge keys) handled in the parser, not via type dispatch. Not applicable — nota/nexus grammar must be schema-driven. |
| **toml-rs** | `#[serde(with = "...")]` | Datetime types use `deserialize_with` / `serialize_with` attribute helpers on user fields. No sentinel names. |
| **postcard / bincode** | Punt | No format-specific types at all. Users compose via serde primitives. |
| **ron** | Punt (like postcard) | No format-specific types. Everything is serde's standard data model. |
| **bson** | Mixed | Native types (ObjectId, Binary) have direct Serialize/Deserialize impls. Optional `with`-attribute converter modules (`serde_helpers::object_id::AsHexString`, etc.) for alternative encodings. |
| **rkyv** | Not serde | Generic trait specialization; compile-time. Different trait ecosystem — not applicable. |
| **serde_bytes** | `#[serde(with)]` pattern | The gold standard: ship codec modules, users opt in per field. No runtime dispatch, no collision risk. |

**Consensus:** two patterns dominate —

1. **Sentinel-name dispatch** (serde_json Number, rmp-serde Ext).
   Pragmatic; string match at runtime; collision-prone but
   mitigated by private-looking prefixes (`$…`, `_…`, `@…`).
2. **Compile-time codec modules** (serde_bytes, toml datetime, bson
   helpers). Zero runtime dispatch; user opts in via
   `#[serde(with = "…")]`; no collision risk; extra annotation per
   field.

No silver bullet. Everyone picks one of these two, or ships both.

---

## 2. Options surveyed — ranked

For each: mechanism, pros, cons, derive-support, collision-risk.

### Tier 1 — recommended

#### A. Sentinel-name dispatch (current)

```rust
#[serde(rename = "@NexusBind")]
pub struct Bind(pub String);
```

Serializer matches on `name: &'static str`.

- **Pros**: zero-config for users, derive-compatible, proven
  (rmp-serde), symmetric ser/de, linear scaling.
- **Cons**: runtime string match; collision possible if user writes
  `#[serde(rename = "@NexusBind")]` on an unrelated type.
- **Collision risk**: moderate. `@Nexus…` prefix makes accidental
  collision very unlikely; deliberate collision is self-sabotage.
- **Migration cost**: zero (status quo).

#### B. `#[serde(with = "…")]` codec modules

```rust
// nexus-serde ships:
pub mod bind_codec {
    pub fn serialize<S: Serializer>(v: &str, s: S) -> Result<S::Ok, S::Error> { … }
    pub fn deserialize<'de, D: Deserializer<'de>>(d: D) -> Result<String, D::Error> { … }
}

// user writes:
struct Query {
    #[serde(with = "nexus_serde::bind_codec")]
    who: String,    // serializes as @who
}
```

- **Pros**: compile-time dispatch; zero collision risk; standard
  serde idiom (`serde_bytes` style); composable with other attrs.
- **Cons**: per-field annotation; users who want `Bind` as a
  standalone type still get it, but users who want inline
  `String`-as-bind semantics need annotations.
- **Collision risk**: zero.
- **Migration cost**: low — pure addition. Ship next to sentinel
  names; both work.

**My recommendation: ship A now, add B as an escape hatch.**

### Tier 2 — viable but worse

#### C. Combined A + B (document both, users choose)

Exactly what tier-1 recommends together. Not really a separate
option — it's the default once both modules exist.

#### D. Config-driven name registration

Consumer configures `Deserializer::new_with_wrappers([…])` at
instantiation. Only registered names dispatch to wrappers.

- **Pros**: explicit; no accidental collision.
- **Cons**: breaks zero-config; asymmetric (no parallel on the
  Serializer); runtime overhead.

#### E. Two-crate pattern / `NexusToken` enum

Ship `Bind`/`Mutate`/`Negate` as variants of a single enum. Users
wrap all nexus values in that enum.

- **Pros**: single dispatch path.
- **Cons**: user writes `NexusToken::Mutate(value)` at every
  call site. Awful ergonomics. Variant-name dispatch still has
  collision risk (just scoped to the enum's own variants).

### Tier 3 — not viable

- **Marker trait** (`trait NexusWrapper`): serde's derive machinery
  doesn't know about custom traits. Dispatch still ends stringly
  typed. Dead end.
- **Proc-macro derive** (`#[derive(nexus_serde::Wrapper)]`): works,
  but requires shipping a proc-macro crate for three types. Scope
  creep unjustified for MVP.
- **String-prefix / bytes-prefix sentinels** (`"\x00NEXUSBIND:h"`):
  conflates data with metadata; breaks `serde_transcode`; only
  works for string/byte-shaped inners. Ugly.
- **`trait NexusSerialize` parallel to `Serialize`**: no derive
  support without a proc-macro. Zero ecosystem fit.
- **Format-specific Serializer trait extension**: users must
  hand-roll `Serialize` — loses derive. Dead on arrival given the
  "zero-config derive" goal.
- **Tagged enum with `Box<dyn Serialize>`**: serde requires
  concrete types; dyn Serialize can't be serialized generically.
  Type error.
- **Visitor extension / downcasting via Any**: runtime reflection
  isn't available; serde types don't implement Any.
- **PhantomData fingerprint**: Rust has no runtime struct-shape
  reflection. Requires proc-macro anyway.

---

## 3. Novel approach: private internal name + public type alias

The one pattern that came up that I hadn't considered:

```rust
// Internal: the struct with a sentinel name, pub(crate) only
#[serde(rename = "$nexus_internal_bind")]
pub(crate) struct _BindInternal(pub String);

// Public: a type alias
pub type Bind = _BindInternal;
```

The serde machinery sees `$nexus_internal_bind` (unguessable to a
user since the struct is crate-private). Users import
`nexus_serde::Bind` and use it transparently.

- **Pros**: genuinely collision-proof. No user-visible string to
  accidentally match.
- **Cons**:
  - Rust doesn't let a `pub type` alias a `pub(crate)` type — the
    private type leaks through the alias. So this doesn't actually
    work as written. Would need the struct to be `pub` but with a
    name starting with `_` / documented as private.
  - The `$` prefix is unusual and visually distracting even in
    internal code.
  - More moving parts than sentinel-name-on-public-struct, for
    marginal additional safety.

**Verdict**: clever but not worth the indirection. The `@Nexus…`
prefix already provides near-complete collision avoidance; the
`with`-codec pattern (tier 1 option B) provides a full escape hatch
for the paranoid.

---

## 4. Concrete plan

Given the above:

1. **Keep current sentinel-name dispatch.** Rename prefix to
   something even more distinctive if you want — my current
   `@Nexus…` is fine, but you could go with `$nexus_…` (lower-case
   camel_snake, `$` prefix) to match serde_json's private
   convention. Either way, document the prefix as reserved in the
   nexus-serde README.
2. **Ship `with`-codec modules** (`nexus_serde::bind_codec`,
   `mutate_codec`, `negate_codec`). Users who want compile-time
   dispatch and zero collision risk opt in per field.
3. **Document the choice** in nexus-serde's README: "The default is
   derive-and-forget (sentinel names). The `with` attribute
   (`#[serde(with = "nexus_serde::bind_codec")]`) is an alternative
   for users who want compile-time dispatch."

Total effort: ~100 LoC of codec modules + README paragraph.

**This is a pure addition**; no breaking change, no migration
needed for anyone using the sentinel-name approach today.

---

## 5. Questions for you

1. **Keep `@Nexus…` prefix or switch to `$nexus_…`?**
   - `@Nexus…` matches your `@` bind sigil aesthetically.
   - `$nexus_…` matches serde_json's private convention and is
     lowercase-snake_case (more conventional for serde rename
     values).
   - Either works. My vote: `@Nexus…` — already shipped, visually
     coherent with the messaging layer's sigils.

2. **Ship the `with`-codec escape hatch now, or defer?**
   - My vote: **defer until a user asks**. It's pure addition
     later; no harm in waiting until we see a real use case. But if
     you want belt-and-suspenders, I'll add it now — ~100 LoC.

3. **Any appetite for the private-internal-name trick?**
   - My vote: **no**. Extra indirection for marginal gain. The
     `@Nexus…` prefix is conservative enough.
