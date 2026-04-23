# Report 009 — binds and pattern matching: a conceptual guide

A reference for the whole field that `Bind` is a single element of:
patterns, matching, unification, logic variables, and the lineage from
Robinson's 1965 paper to modern record-query languages. Written to
inform design decisions on nexus's query layer.

---

## 1. What a bind is, in one sentence

A **bind** (alias: **logic variable**, **hole**, **metavariable**) is a
named placeholder inside a *pattern* that, when the pattern is matched
against ground data, gets filled with a concrete value. In nexus:
`@h` in `(| Point horizontal=@h vertical=@v |)` is a bind.

---

## 2. Core theory

### Patterns vs values

A **value** is concrete: `(Point horizontal=3.0 vertical=4.0)`. A
**pattern** is a template that may contain both concrete parts and
holes: `(| Point horizontal=@h vertical=@v |)`. A pattern describes a
class of values.

### Matching vs unification

- **Matching** is *one-sided*: pattern on one side, ground value on
  the other. Deterministic. "Does this value fit this template, and
  if so, what do the holes bind to?" This is what SQL, SPARQL,
  datalog, ML, Rust `match`, regex all do. **nexus uses matching.**
- **Unification** is *bidirectional*: both sides may contain holes.
  Algorithm finds the **most general unifier (MGU)** — the
  least-committed variable assignment making both sides identical.
  Prolog, miniKanren, Coq's term-rewrite engine use full unification.
  nexus does not need this (matching is enough for queries).

### Binding and bindings

The **verb** "to bind" = "assign a hole to a value during match."
The **noun** "a binding" = the pair `(@h → 3.0)` that resulted.
The **plural** "bindings" = the dictionary-like result of a successful
match. A pattern applied to N records yields N sets of bindings (a
stream).

### Scope

In nexus, binds are scoped to a **single message** (one
pattern/constraint block). Across messages, `@h` in one has no
relation to `@h` in another. Within a message, same name =
same variable.

### Linearity

- **Linear** patterns: each variable appears at most once (ML, Rust
  `match`, Haskell). Avoids non-local equality constraints; simpler.
- **Non-linear** patterns: same variable may appear multiple times,
  and those occurrences are forced to unify (Prolog, datalog,
  SPARQL, Cypher, miniKanren). **nexus is non-linear:**
  `(| Pair a=@x b=@x |)` matches only pairs where both fields are
  equal.

---

## 3. Historical arc (compressed)

| Year | System | Contribution |
|---|---|---|
| 1965 | Robinson's resolution paper | First-order unification algorithm; MGU |
| 1972 | Prolog | First mainstream language built on logic variables + Horn clauses; SLD resolution engine |
| ~1977 | ML | Syntactic pattern matching in function args / `case`. Linear by convention |
| ~1981 | Datalog | Prolog minus function symbols; bottom-up semi-naive evaluation; conjunctive queries |
| 2008 | SPARQL | W3C query language for RDF; `?v` bind syntax; pattern matching over triples |
| 2009 | miniKanren | Minimal logic programming embedded in Scheme; streams of substitutions; `==` as unification |
| 2015 | Cypher | Graph queries on Neo4j; `(node:Label {field: $v})` syntax |
| various | Datomic, Soufflé, etc. | Modern datalog with indexing / incremental evaluation |
| 2010+ | Rust, Scala, Elixir, Python 3.10+ | ML-style pattern matching becoming mainstream |

For nexus's purposes the direct ancestors are **datalog** (for
non-linear bind semantics + conjunctive queries) and **SPARQL** (for
the `?v` / `@v` sigil convention).

---

## 4. Nexus specifically

### Patterns

```nexus
(| Point horizontal=@h vertical=@v |)
```

Matcher walks records of type `Point`, binds `@h` and `@v` for each
match. Result: stream of `{h: …, v: …}` bindings.

### Conjunction

```nexus
{|
  (| Point horizontal=@h vertical=@v |)
  (| Positive @h |)
|}
```

Find records where *both* patterns hold, with the same binding for
`@h`. Joins occur on repeated bind names. Datalog solves this
bottom-up; Prolog backtracks; nexus-internal engine TBD.

### Shape

```nexus
(| Point horizontal=@h vertical=@v |) { horizontal }
```

After matching, project only the `horizontal` field of each matched
record. Shape filters what is *returned*, not what is *matched*.
(There's a subtlety here: does `{ horizontal }` project fields of the
record, or bindings? nexus spec says fields of the record. Bindings
are available under their `@` names.)

### Mutate

```nexus
~(| Point horizontal=@h vertical=@v |) { horizontal=0.0 }
```

For each match, overwrite `horizontal` with `0.0`. Binds on the LHS
are *read* from the match; values on the RHS of shape's `=` are the
new field values. (In the spec I wrote, this uses `=` for the shape's
new-values — your `=` decision affects this syntax too.)

### Negate

```nexus
!(Active)               ;; retract the fact that Active is asserted
(| Point horizontal=!0.0 vertical=@v |)
                         ;; match Points where horizontal ≠ 0.0
```

Two uses of `!`: retraction at message level, non-match at pattern
level. This is "negation as failure" — a closed-world assumption
common in datalog.

---

## 5. Key theoretical distinctions to know the names of

- **Logic variable**: name for a hole before it's bound. Lives in the
  pattern.
- **Value variable**: name for a location holding a value (imperative
  style). Post-binding binds act like these.
- **Ground term**: no variables, fully concrete. All asserted records
  are ground.
- **Most general unifier (MGU)**: the canonical least-committed
  result of unification when multiple are possible. Matters if nexus
  ever adds bidirectional patterns.
- **Horn clause**: `head :- body1, body2, …`. The natural structure
  of datalog rules; nexus's `{| |}` is isomorphic to a body.
- **SLD resolution**: Prolog's top-down + backtracking search.
  Not recommended for nexus — datalog-style semi-naive eval is
  typically the right engine.
- **Semi-naive evaluation**: iterative datalog algorithm that
  computes "new" facts each round using only facts that became true
  last round. Efficient for conjunctive queries.
- **Non-linear / linear patterns**: repeat-same-name-forces-equality
  (non-linear) vs each-name-once (linear).
- **Occurs-check**: unification safety check preventing
  `X = f(X)` infinite expansion. Only relevant if nexus does full
  unification.
- **Negation as failure / closed-world assumption**: `!pattern`
  means "no record matches" — assumes the world-store is complete.
  Standard in datalog.

---

## 6. Practical concerns for nexus

| Concern | Decision needed |
|---|---|
| **Scoping** | Per-message seems right. |
| **Re-use** | Non-linear (match my text). Force equality on repeated bind names. |
| **Anonymous binds** | `@_` for "match-but-don't-bind." Simple to add. |
| **Bind types** | Implicit from the schema (serde derives). Records carry types; binds inherit. |
| **Result order** | Observations are *sets*, not ordered tuples. Matches datalog. Rust-side: HashMap / BTreeMap. |
| **Bind-to-bind binding** | Should `@h = @v` (two binds forced equal without a field anchor) be allowed? Datalog allows it, treated as unification. Probably not needed MVP. |

---

## 7. Engineering concerns

- **Pattern indexing.** To answer `(| Point … |)` you need a
  type-indexed record store. To answer
  `(| Point horizontal=0.0 … |)` you need a field-value index.
  Start with type-indexed (scan) and add field indexes when profiles
  say so.
- **Occurs-check** only if you grow to full unification. Matching
  doesn't need it.
- **Backtracking.** Matching against a world-store is typically
  *not* a search; it's a scan + filter. Prolog-style backtracking is
  overkill for most nexus queries. Datalog's bottom-up join model
  is more appropriate.
- **Bound-before-use order.** In a conjunction
  `{| (| Positive @h |) (| Point horizontal=@h |) |}`, the engine
  can solve either first. Order shouldn't matter semantically.
  Implementation will have a preferred order for performance
  (smallest index first).
- **Streams vs sets.** Observations can be consumed incrementally
  (pull one match at a time) or in bulk. miniKanren's stream model
  is lazy. For network RPC, batching is simpler.

---

## 8. Further reading

- Robinson, J. A. (1965). "A Machine-Oriented Logic Based on the
  Resolution Principle." *JACM* 12(1). — the origin.
- Clocksin & Mellish. *Programming in Prolog*. Springer, 5th ed.
  — a classic Prolog text; chapters on unification and matching.
- Abiteboul, Hull, Vianu. *Foundations of Databases*. Addison-Wesley
  1995. — comprehensive formal treatment of the relational
  model, Datalog, conjunctive queries.
- Friedman, Byrd, Kiselyov. *The Reasoned Schemer*. MIT Press.
  — pattern-matching and unification from a functional-programming
  angle via miniKanren.
- The [SPARQL 1.1 spec](https://www.w3.org/TR/sparql11-query/) and
  the [Datomic query
  docs](https://docs.datomic.com/pro/query/query.html) — modern
  production uses of the same model.

---

## 9. Summary

**Binds are the datalog concept** — logic variables that appear in
patterns and get assigned values when those patterns match records.
The surrounding field is **pattern matching + non-linear bind
semantics + conjunctive queries**, with ~60 years of well-understood
theory.

For nexus, the MVP-relevant points are:

1. **Non-linear** (repeat names = equality constraint).
2. **Matching**, not full unification (one-sided: pattern vs ground
   record).
3. **Scope per message**.
4. **Observations are sets of bindings** (not ordered, not
   stream-mandated).
5. Engine will look like datalog semi-naive eval, not Prolog
   backtracking.

Nothing in nexus's spec needs theoretical invention — the model is
mature and well-understood. Implementation will need to choose an
engine, index strategy, and evaluation order, but those are
engineering choices within a settled theory.
