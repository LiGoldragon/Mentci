# 056 — nexus grammar under the request-only lens

*Claude Opus 4.7 / 2026-04-24 · re-evaluates the delimiter-family
grammar of [reports/013](013-nexus-syntax-proposal.md) against
the three ratified invariants of
[reports/054](054-request-based-editing-and-no-ingester.md) —
particularly Invariant B, "nexus is a request language, not a
record format." Complements 013 (syntax) and 054 (framing);
references 033 (record-kind catalogue) and `docs/architecture.md`
§7 (grammar shape). Does not revise 013 — asks "does it still
hold when every top-level expression is a request to criomed?"
and answers "mostly yes, with two sharpenings and one deferral."*

---

## Orientation

Report 013 designed nexus grammar as *the text form of nota-plus-
query-operators*. That design predates Invariant B. Under 054,
nexus is not "the textual rendering of records" — there are no
"nexus records" to render. Nexus is **the wire format for
requests** a client sends to criomed through nexusd. The request
may embed record *constructions* as payloads, but the top-level
shape is always a verb.

This report works through eight questions about what that lens
changes, then collects the deltas. Settled 013 decisions (no
pipeline operator; zero new sigils; operators are Pascal-named
records; `<| |>` stream; `{|| ||}` atomic txn; `[|| ||]` rules)
all survive; what changes is how we describe the grammar, plus
two small additive rules.

---

## 1 · The shape of a nexus request

Under Invariant B, a nexus message is a **request envelope whose
head is a verb**. Paren-form examples (not committed syntax):

```nexus
(Query   (| Fn @name @body |))
(Assert  (Fn :name :double :body (Block …)))
(Mutate  (Fn :name :double) (Patch :body (Block …)))
(Retract (Fn :name :double))
(Compile (Opus :nexusd))
(Subscribe  <| (| Fn @name |) |>)
```

Each fits the 013 matrix as a **bare-record in the `( )` family**
whose head is a Pascal-named verb in `nexus::request::*` — the
same mechanism 013 already uses for aggregation operators in
`nexus::aggregate::*`. Verbs are records too; they're just the
records that mean "do a thing with criomed." No new delimiter
shape is needed.

**Where does the verb live?** At **position 0 of a top-level
`( )`-form**, where a record type name would otherwise live.
Grammar rule:

> A **nexus message** is a top-level `( )`-form whose position-0
> identifier resolves to a verb in `nexus::request::*`. Anything
> else at the top level is a syntax error at parse time (before
> criomed ever sees it).

This is a clean extension of 013's first-token-decidability: the
first token of every valid message is the request verb.

**Subscriptions look special but aren't.** A bare `<| |>` at the
top level is shorthand for `(Subscribe <| |>)`. Accept both:

```nexus
(Subscribe <| (| Order @customer @amount |) |>)   ;; explicit
<| (| Order @customer @amount |) |>               ;; shorthand
```

The shorthand reduces paren density for the commonest read-
stream case. Parser normalises to the explicit form.

**Verdict:** no change to 013's matrix. Verbs ride in `( )` at
position 0.

---

## 2 · Do records appear in nexus text?

Distinction:

- **Record literal** — *this text IS the record* (JSON-style).
- **Record construction** — *this text instructs the engine to
  construct a record* (SQL-INSERT-VALUES-style).

Under Invariant B, nexus text is **construction**, never literal.
`(Assert (Fn :name :double :body (Block (Stmt …))))` says:
"criomed, in executing this Assert, construct a Fn record with
name=:double and body=…". Criomed validates against the Fn
schema, resolves references, mints a `RecordId` by hashing the
canonical rkyv encoding, and stores.

**Implication for grammar**: none. Construction expressions and
record literals are textually identical. The lexer/parser yields
a uniform `RecordCtor { kind, fields, children }` AST node
either way; only criomed's interpretation differs.

**Implication for prose**: scrub 013 (and downstream docs) of
"record literal" — prefer "construction expression" or "record
form." Same syntax, clearer semantics aligned with Invariant B.

**Constructions nest arbitrarily.** A `Block` construction
contains `Stmt` constructions which contain `Expr` constructions,
etc. Grammar imposes no depth limit; criomed validates well-
formedness at apply time.

**Patch is a sub-sublanguage.** `(Mutate … (Patch …))` embeds a
`Patch` sub-grammar describing *what to change* in the target.
Patch's inner Pascal-named records (ReplaceField, AddField,
RemoveField, AppendChild, …) live in `nexus::patch::*`. Same
grammatical mechanism as everywhere else; different module.

**Verdict:** 013's grammar is correct; its prose needs
"construction" instead of "literal."

---

## 3 · Does the grammar need a request/verb distinction?

Yes, but cheap — one top-level rule:

> **Top-level rule**: A nexus message is exactly one of:
> (a) a `( )`-form whose head is a `nexus::request::*` verb;
> (b) a `<| |>`-form (shorthand for `(Subscribe …)`);
> (c) a `{|| ||}`-form (shorthand for `(Atomic …)` — §6).

Bare `(Fn :name :X)` at top level is not a request; parser
rejects. Bare `(Sum @x)` is not a request — `Sum` is in
`::aggregate`, not `::request`.

**Where does this check run?** At **nexusd's parse time**, not
criomed's apply time. Malformed requests get syntax errors
immediately without a round-trip. This matters for LLM agents
learning grammar: faster feedback, less load, criomed never sees
nonsense.

**Verb registry** lives in `nexus-schema` (parallel to
`::aggregate` and `::query`). A new `nexus::request::*` module
enumerates verbs and their payload shapes:

- `Assert(rec)`
- `Mutate(target, patch)`
- `Retract(ref)`
- `Query(pattern, …operators)`
- `Compile(opusRef)`
- `Subscribe(stream)`
- `Atomic(…mutations)`
- *(Phase 2)* `RegisterRule`, `RetractRule`, `WatermarkAck`, …

nexusd validates the top-level verb via this registry; criomed
dispatches via the same registry. One source of truth.

**Grammar delta**: a one-line rule added to 013 §4.2.

---

## 4 · Query language shape

Queries carry the most grammar pressure: patterns, projections,
aggregations, pagination, Phase-2 temporal scoping. 013 already
worked the query-body grammar out:

- Body is a pattern (`(| … |)`) or constrain block (`{| … |}`).
- Optional projection/aggregation shape (`{ }`).
- Optional zero-or-more operator records (`Limit`, `OrderBy`, …)
  juxtaposed.

Under the request lens, all of this becomes the **payload of a
`Query` verb**:

```nexus
(Query
  (| Order @customer @amount |)
  (|| Customer @customer @tier ||)
  { @customer @tier (Sum @amount) (Count) }
  (OrderBy (Desc (Sum @amount)))
  (Limit 50))
```

No change to query-body syntax. What changes: patterns and
PatternExpr are **request-level**, not query-only. They are
shared across Query, Subscribe, Retract, and (Phase 2)
RegisterRule.

**PatternExpr home**: `nexus-schema::pattern`, not
`nexus-schema::query`. A relocation from where 013/015
implicitly placed it. Not a grammar change, but a module
organisation fix.

**Verdict:** no change to query body; pattern module moves.

---

## 5 · Permission gate — authz-layer or grammar-layer?

**Authz-layer, not grammar.** Permissioning (Invariant B)
depends on:

- the principal (capability token / BLS-quorum signature per
  reports/035),
- the target records,
- the current policy (CapabilityPolicy records that themselves
  change).

None are statically derivable from text. A grammar-level
permission gate would bake RBAC into the grammar — category
error.

**Distinguishing privileged vs routine verbs at the grammar
layer?** Marginally useful. An admin-grade verb (`DropOpus`,
`FormatSema`, `RetractRule`) could get a distinct delimiter, but
criomed will reject unauthorised calls either way. The
visual-hint value isn't load-bearing.

**Recommendation**: **no grammatical admin marker** for Phase 1.
Verbs live uniformly in `nexus::request::*`; criomed gates with
CapabilityPolicy. If misuse shows up in practice, revisit — the
fix is additive (a spare matrix slot is available).

**Verdict:** no grammar change.

---

## 6 · Read-only vs write verbs

Two semantic classes:

| Class | Verbs | Reply shape |
|---|---|---|
| **Read** | Query, Subscribe, Resolve | Data or stream |
| **Write** | Assert, Mutate, Retract, Compile, Atomic, RegisterRule, … | Ack + revision hash, or error |

**Syntactic distinction needed?** No — the verb name already
carries it. Duplicating read/write-ness in delimiter choice
would be redundant.

**Atomic-transaction shorthand is the one exception.** `{|| m1
m2 m3 ||}` is shorthand for `(Atomic m1 m2 m3)`. 013's two-pipe
brace shape exists because transactions need an explicit
boundary for rollback-and-error atomicity (013 §3.4). The
shorthand resolves cleanly to a verb: top-level `{|| ||}` parses
as an Atomic request with a sequence of write-payloads inside.

**Verdict:** no grammar change beyond 013. Class of verb is
carried by the verb name.

---

## 7 · Stream responses — one-shot vs continuous

A user knows reply shape because **the verb determines it**:

- `Query` → one-shot reply with the result set.
- `Assert` / `Mutate` / `Retract` / `Atomic` → one-shot ack +
  new-revision hash, or error.
- `Compile` → one-shot reply with `CompiledBinary` reference +
  diagnostics, or error.
- `Subscribe` → **open channel**; server pushes `SubSnapshot` →
  `SubAssert` / `SubMutate` / `SubRetract` until close.

No grammar machinery needed. The verb is the contract. Wire
framing (criome-msg) carries stream semantics; nexus text just
expresses requests.

**`<| |>` as a visual cue** remains valuable — it tells the
author "you're asking for a stream." That's worth the shorthand
even under the request lens.

**Long-poll / paginated query** isn't a separate verb. A `Query`
with `(Limit N) (After @cursor)` operators returns N rows plus a
continuation cursor; resubmit with the new cursor. No new
grammar.

**Verdict:** no grammar change. Verbs are reply-shape-typed; `<|
|>` shorthand covers the stream ergonomic.

---

## 8 · Formatting for humans — paren walls

Report 052 flagged "wall of parens" as an authoring pain point.
The request lens doesn't change that — `(Assert (Fn :name :X
:body (Block (Stmt …))))` is deep regardless.

**What helps:**

1. **rsc pretty-prints** records back to nexus text for human
   reading. Lisp-style indentation: each sub-construction that
   won't fit on one line opens a new indented block. Display
   surface, not parse surface.
2. **Paredit-style editors** — S-expressions are cheap to edit
   structurally (slurp, barf, raise, splice). Phase-1 TUI /
   structural-editor tooling (per 052) ships with this.
3. **Patch requests for small edits**: `(Mutate (Fn :name :X)
   (Patch :body (Block …)))` is shorter than reasserting the
   whole Fn.
4. **`;;` comments** are first-class today and survive.

**Grammar additions for formatting**: none. Pretty-printing is a
formatter property; whitespace inside any delimiter pair is
already insignificant. Rejected non-goals: significant-whitespace
layout (breaks first-token decidability), multi-character
operators (013 §7), two-syntax-for-one-thing (teaching burden).

**Verdict:** no grammar change. Tool-layer (pretty-printer,
paredit, TUI) handles it.

---

## 9 · What changes in report 013's grammar

Five changes, all additive or clarifying:

**(A) Top-level verb rule (NEW).** Add to §4.2:

> Every top-level nexus expression is a **request**: either (1) a
> `( )`-form whose position-0 identifier is a verb in
> `nexus::request::*`, (2) a `<| … |>` shorthand for `(Subscribe
> …)`, or (3) a `{|| … ||}` shorthand for `(Atomic …)`. Anything
> else at top level is a parse-time syntax error.

**(B) `nexus-schema::request` module (NEW).** Parallel to the
already-planned `::query` and `::aggregate`. Phase-1 verbs:
Assert, Mutate, Retract, Query, Subscribe, Compile, Atomic.
Phase-2: RegisterRule, RetractRule, temporal variants. One
record-kind per verb; verbs carry their payload as typed fields.

**(C) `nexus-schema::patch` module (NEW).** Patch sub-language
for `Mutate`: ReplaceField, AddField, RemoveField, AppendChild,
RemoveChild, …

**(D) PatternExpr lives at `nexus-schema::pattern`.** Not
`::query`. Patterns are shared across Query, Subscribe, Retract,
and Phase-2 RegisterRule. Relocation, not a grammar change.

**(E) Prose scrub: "literal" → "construction".** In 013 and
downstream, wherever nexus text is called "a record literal,"
say "construction expression" or "record form." AST is identical;
wording aligns with Invariant B.

That's it. The delimiter-family matrix stands unchanged.

---

## 10 · What stays unchanged

Explicit list so future sessions don't reopen:

1. The 4×3 delimiter-family matrix (outer char picks family,
   pipe count picks abstraction level).
2. Zero new sigils — budget stays `;;`, `#`, `~`, `@`, `!`, `=`.
3. No pipeline operator; juxtaposition suffices.
4. Operators as Pascal-named records — `Limit`, `OrderBy`,
   `Sum`, `GroupBy`, etc.; no reserved words.
5. `<| |>` = stream family; reserved `<|| ||>` = windowed.
6. `{|| ||}` = atomic transaction; rollback-and-error default;
   partial-success reserved for hypothetical `{# #}`.
7. `(|| ||)` = optional pattern (LEFT-JOIN).
8. `[|| ||]` reserved for Phase-2 rules.
9. Default time = current state; temporal scoping (Phase 2) is a
   prefix `TimeAt` / `TimeBetween` / `TimeAll` record.
10. Text only crosses nexusd; internal wire is rkyv.
11. First-token decidability holds — the first token is the
    request verb (or a shorthand opener).

None threatened by the request lens.

---

## 11 · Tension the request lens surfaces

The one place the lens creates friction is **Phase-2 rules**,
`[|| head body ||]`.

**Under 013**: rules are a top-level construct with dedicated
syntax.

**Under the request lens**: rules are records. Registering a
rule is a write. Idiomatic form:

```nexus
(Assert (Rule
          :head (RuleHead Ancestor (| @a @c |))
          :body (RuleBody {| (| Parent @a @b |)
                             (| Ancestor @b @c |) |})))
```

A normal Assert of a Rule record; no special delimiter needed.

**Does `[|| ||]` still earn its keep?**

- **Option 1** — keep it as shorthand for `(Assert (Rule …))`,
  parallel to how `<| |>` is shorthand for Subscribe and `{||
  ||}` for Atomic.
- **Option 2** — drop it; rules are Asserts like any other
  record. The `[ ]` family's two-pipe slot stays unused.

**Leaning: keep as shorthand, Phase 2.** Rules will be common
enough in post-Phase-2 authoring that saving the wrapper is
worth a matrix slot; the shorthand preserves the property that
rules are *visually distinctive* at the top level (a rule ought
to look like a rule for code-review ergonomics). This is a
Phase-2 decision and need not be settled now — reserve the slot
and revisit when rules are implemented.

---

## 12 · Emergent pattern: two-pipe slots as verb shortcuts

Worth naming:

| Shorthand | Expands to | Class |
|---|---|---|
| `{\|\| … \|\|}` | `(Atomic …)` | write (transaction) |
| `<\| … \|>` | `(Subscribe …)` | read (stream) |
| `[\|\| … \|\|]` *(Phase 2)* | `(Assert (Rule …))` | write (rule reg.) |
| `(\|\| … \|\|)` | optional pattern in a query | **payload-level, not verb** |
| `<\|\| … \|\|>` *(Phase 2 reserved)* | `(Subscribe (Windowed …))` | read (windowed) |

Four of five two-pipe slots are, or could be, request-verb
shortcuts. One (`(|| ||)` optional pattern) is a payload-level
operator.

**Pattern**: the two-pipe slot in each family is, by default,
where request-verb ergonomics live when a verb is common enough
to deserve shorthand. Not a hard rule (optional-pattern proves
the exception), but a strong default. Next time a common write-
class operation wants top-level syntax, check the matrix first.
The `{# #}` slot (reserved for partial-success) remains
available.

---

## 13 · Action items

1. **Link from 013 forward to 056** for the top-level
   clarification. Don't rewrite 013 — it's a decision-journey
   record.
2. **Draft `nexus-schema::request` module** — Phase-1 verbs as
   record-kinds with typed payloads.
3. **Draft `nexus-schema::patch` module** — Patch sublanguage.
4. **Relocate PatternExpr** to `nexus-schema::pattern` (bd item
   in nexus-schema).
5. **Addendum to `docs/architecture.md` §7**: "A nexus message
   is a request. Top-level shape is a verb from
   `nexus::request::*` or one of two/three shorthands. See
   reports/013 and reports/056."
6. **Prose scrub** — "literal" → "construction" via a cross-
   reference notice at the top of 013 pointing here. 013 stays
   frozen per house rule.
7. **Bd items** in nexus-schema: (a) request module, (b) patch
   module, (c) pattern relocation.

None of this blocks Phase-0 MVP (which ships with current
grammar, no Tier-1). Items apply to Phase-1 Tier-1 design.

---

## 14 · Residual open questions

Surfaced but not blocking:

- **Batched requests.** Can one message carry multiple
  independent (non-atomic) verbs? Obvious answer: a `(Batch v1
  v2 v3)` verb. Deferred; not Phase-1.
- **Response grammar.** This report covers requests. Replies
  (criomed → nexusd → text) presumably reuse the delimiter
  families but don't require the verb-at-position-0 rule.
  Worth an explicit note when reply envelopes are designed.
- **Stream termination.** How does Subscribe gracefully end
  when its subject is retracted or the subscription cancelled?
  Wire-format concern, not grammar. Flagged in 013 §8.1.
- **Verb-discoverability for LLMs.** The agent harness
  advertises the verb list in the system prompt; otherwise the
  LLM guesses. Tooling-layer, not grammar.
- **Rule-shorthand vs explicit Assert.** §11 leaves Phase-2
  open. Revisit when rules land.

---

## 15 · Summary

Report 013's grammar was designed before Invariant B was
explicit. Re-examined under the request lens, it survives with
five small clarifying changes — chiefly a top-level rule that
every nexus message begins with a verb from `nexus::request::*`,
plus module organisation (`::request`, `::patch`, `::pattern` as
distinct from `::query` and `::aggregate`). The delimiter-family
matrix stands. The sigil budget stays closed. Operator-as-record
extends cleanly to verbs.

The one tension — whether `[|| ||]` rule syntax is still
"idiomatic" when rules are records — resolves as: keep it as
Phase-2 shorthand for `(Assert (Rule …))`, parallel to `{|| ||}`
→ `(Atomic …)` and `<| |>` → `(Subscribe …)`. An emergent
pattern: **two-pipe matrix slots tend to host verb-class
shortcuts**, with one payload-level exception.

No grammatical change is required for Phase-0 MVP. The items
here apply to Phase-1 Tier-1 design and are additive and
non-breaking to 013.

---

*End report 056.*
