# Report 010 — nota/nexus third-round review

Third review after the bare-identifier string form landed. Earlier
rounds: [reports/008](008-nota-nexus-review.md) and
[009](009-nota-nexus-second-review.md). An agent-assisted review
found one critical bug and three small spec gaps — all fixed this
session.

---

## 1. Verdict

**Healthy after fixes.** 218 tests pass across both crates
(149 nota-serde, 69 nexus-serde), clippy clean, `nix flake check`
green on both. No remaining blockers for horizon-rs to become the
first real consumer.

---

## 2. Critical bug found and fixed

### `char` round-trip failure

**Symptom:** a Rust `char` field would serialize but not
deserialize.

**Trace:** `serialize_char` routes through `write_str_literal`
(treats `'a'` as a one-char string). After the bare-string
change, `'a'` emits as bare `a` (matches `is_bare_string_eligible`).
But `deserialize_char` only accepted `Token::Str`, not
`Token::Ident` — so the bare form failed with
`expected string for char, got Ident("a")`.

**Fix** ([nota-serde/src/de.rs](../repos/nota-serde/src/de.rs),
[nexus-serde/src/de.rs](../repos/nexus-serde/src/de.rs)):
`deserialize_char` now accepts both tokens, extracting the first
char from either. Two tests verify round-trip: `char_single_roundtrip`
and `char_in_struct`.

---

## 3. Spec gaps found and fixed

Agent review identified three documentation holes:

1. **Canonical-form section didn't mention bare strings.** The
   §Bare-identifier strings section described the rule, but the
   later §Canonical form still listed only `[...]` and `[| |]`.
   **Fix:** §Canonical form's "Strings" bullet now names bare
   form as the default when the content is eligible.

2. **ASCII-only restriction undocumented.** The `is_bare_string_eligible`
   check uses `is_ascii_alphabetic` / `is_ascii_alphanumeric`, so
   `café` with `é` stays bracketed. Behaviour was correct but
   unspecified. **Fix:** spec now states "Bare form is ASCII-only"
   with the Unicode examples.

3. **Path separator `:` and bare strings ambiguous.** The lexer
   emits `:` as its own token; a bare string cannot contain it.
   Users wanting `"foo:bar"` as a String must bracket. **Fix:**
   spec now calls this out explicitly in the bare-string section.

All three changes live in [nota/README.md](../repos/nota/README.md).

---

## 4. Non-issues (agent flagged, reviewed)

The agent raised several concerns I verified as non-issues:

- **Hex-bytes vs bare-string collision** (`"a1b2c3"` as a string
  vs `#a1b2c3` as bytes). The `#` sigil disambiguates at lex
  time — `#` produces `Token::Bytes` regardless of what follows.
  No collision path.
- **Struct-type-name vs bare-string-content collision** (e.g.
  a `String` field holding `"Point"` next to a `struct Point {}`).
  Record form requires `(TypeName ...)`; bare `Point` is a value,
  not a record. Schema disambiguates.
- **Enum-variant vs bare-string in same schema.** Same mechanism:
  schema routes to the correct visitor. Already covered by tests
  in `bare_strings::` module.
- **Map-key sort stability under bare/bracketed mixing.** Sort is
  by *serialised bytes*, and serialisation is deterministic — so
  sort is deterministic too. The lexicographic order is
  per-content by definition.

---

## 5. Test coverage — what's now covered

Bare-string battery (9 tests in [nota-serde/tests/edge_cases.rs](../repos/nota-serde/tests/edge_cases.rs)'s
`bare_strings` module):

- canonical emission (ident-shaped → bare)
- bracketed-fallback for non-eligible content
- parse-from-bare
- bracketed-form-still-accepted (backward compat)
- Vec<String> with bare elements
- struct field with bare string
- `Option<String>` sentinel interaction with bare/bracketed `None`
- plain `String` with bare `None` (canonical emits `[None]`)
- mixed reserved / space / ident in a single Vec

Plus this session's additions:
- `char_single_roundtrip` — catches the bug we just fixed
- `char_in_struct` — same, but in a composite

Nexus side: bind-validator boundaries (4 tests in `nexus_wrappers.rs`)
plus a `char_roundtrip_nexus` regression guard.

---

## 6. Minor test coverage gaps (not blockers)

Still unwritten, low priority:

- **Non-ASCII bracket confirmation.** Unicode strings round-trip
  (tested) but there's no explicit "output must bracket" check.
- **Colon-in-string bracket confirmation.** Similar — works, but
  no explicit assertion that `"foo:bar"` emits bracketed.
- **String value equal to a type name** (e.g. field holding
  `"Point"` next to `struct Point`). Works by construction; no
  test documents the invariant.

Each is ~5 lines to add. Worth doing next time tests get touched.

---

## 7. Readability + dogfood readiness

Real configs now read well:

```nota
;; before
<([tools-documentation] [nota] [nexus])>
(Config [server] 8080 <[debug] [verbose]>)

;; after
<tools-documentation nota nexus>
(Config server 8080 <debug verbose>)
```

The ecosystem is **ready for horizon-rs adoption** as the first
real consumer. No blocking bugs. The `char` issue would have
bitten any consumer using `char` fields; it's fixed.

One caveat worth mentioning: canonical form's output shape
depends on content (bare vs bracketed is a content decision).
For content-addressing, this is deterministic (same bytes in →
same bytes out) but it means the *shape* of a serialised record
changes based on the values inside. This is documented in the
spec (§Canonical-form assumptions) but worth keeping in mind for
hash-stability debugging.

---

## 8. Agent findings I'm skipping

The agent suggested two post-MVP items; I don't think either is
worth attention now:

- **`StringStyle` enum** for `Bare` / `Bracketed` / `Canonical`
  output modes. Configurable styles for human readers. Not
  needed for MVP; YAGNI.
- **Lint warnings for ambiguous bare strings.** Would require
  a separate tool / linter pass. Premature — we don't have
  ambiguity problems yet.

Both are reasonable if user demand emerges; neither is a real
concern now.

---

## 9. Remaining work (unchanged from report 009)

Deferred or in-flight:

- `~90%` code duplication between nota-serde and nexus-serde —
  bd-tracked.
- Pattern / Constrain / Shape wrapper-type design in nexus-serde
  — deferred until nexusd / nexus-cli surface a concrete need.
- `nota-n3a` — file-inclusion notation research — deferred.
- Real `.nota` config file inside this workspace — explicitly
  skipped (horizon-rs is the intended first consumer).

---

## 10. Summary of changes this session

Applied, tested, pushed:

- **`char` fix** in both [nota-serde](../repos/nota-serde/src/de.rs)
  and [nexus-serde](../repos/nexus-serde/src/de.rs)
- **Spec clarifications** in
  [nota/README.md](../repos/nota/README.md): canonical-form bullet
  for bare strings, ASCII-only note, path-separator clarification

What's not applied (low-priority test additions):

- Non-ASCII bracket assertion
- Colon-in-string bracket assertion
- Type-name collision documentation test

Pending your decision: whether to add those now or fold into
next pass.
