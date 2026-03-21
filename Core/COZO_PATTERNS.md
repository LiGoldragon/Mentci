# CozoScript Patterns

CozoDB (via CozoScript / Datalog) is the first-version authority for Mentci.
Relations are the source of truth. Rust, Cap'n Proto, and all other formats
are derived from relations.

Datalog has this authority because it is the closest modern system to the
Vedic grammatical model — declarative, self-referencing, deterministic.
Pāṇini's grammar generates all valid Saṃskṛta forms from roots through
rules. CozoScript generates all valid world states from relations through
queries. Both are precision languages for lossless transmission of meaning.

| Saṃskṛta | CozoScript | Role |
|-----------|-----------|------|
| dhātu (root) | stored relation | The fundamental unit of meaning |
| pratyaya (suffix/rule) | query rule (`:=`) | The transformation applied |
| pada (word/output) | query result | The generated output |
| sandhi (junction) | join across relations | Composition of units |
| vibhakti (case ending) | key/value `=>` | The role a unit plays in context |
| samāsa (compound) | nested/chained query | Combining units into larger wholes |

This document defines how to write CozoScript for the Criome.

---

## Relation Naming

### The Capitalization Rule

| Casing | Meaning | CozoDB role | Rust output |
|--------|---------|-------------|-------------|
| `PascalCase` | Categorical type | Registered in `Enum`, rows = variants | `enum Phase { Manifest, Becoming, Retired }` |
| `snake_case` | Data / instance relation | Key + value columns, rows = instances | `struct Thought { id, kind, ... }` |

PascalCase in a relation name means "this is a category." The same word in
lowercase is a variable or column — an instance of that category. `Phase`
(the relation) defines what phases exist. `phase` (a column) holds which
phase a specific fact is in.

This is the number **2** from the subdivision chain — the most primitive
distinction. Type/instance. Category/particular. Universal/individual. The
casing makes the 2 visible in syntax.

### The Enum Registry

The `Enum` relation is the authoritative registry of all categorical types.
It is self-registering — `Enum` lists itself as an entry:

```cozo
:create Enum {
  name: String =>
  description: String
}

?[name, description] <- [
  ["Enum",       "Registry of all categorical type relations"],
  ["Phase",      "Lifecycle tri-state: manifest/becoming/retired"],
  ["Dignity",    "Epistemological trust hierarchy"],
  ["CommitType", "Jujutsu commit classification"],
  ["Action",     "Commit transformation verb"],
  ["Verdict",    "Commit context judgment"]
]
:put Enum { name => description }
```

A relation is an enum if and only if:
1. Its name is PascalCase (the convention — fast visual signal)
2. It appears in the `Enum` registry (the authority — data signal)

When the `Enum` registry exists, it is authoritative. PascalCase alone is
the fallback for bootstrapping (before the registry is populated).

The self-registration is the **genesis bootstrap pattern**: Sema specifies
itself, `Enum` registers itself, the Pyramid encodes its own proportions.
Self-reference is the mechanism by which a system becomes self-sufficient.

### Enum Values

All enum values are lowercase in CozoDB. The codegen converts to PascalCase
for Rust and camelCase for Cap'n Proto automatically.

```cozo
# Values stored lowercase in CozoDB
?[name] <- [["manifest"], ["becoming"], ["retired"]]
:put Phase { name => ... }

# Codegen produces: enum Phase { Manifest, Becoming, Retired }
# Cap'n Proto:      enum Phase { manifest @0; becoming @1; retired @2; }
```

### Reserved Conventions

- Dot-namespaced names (`component.relation`) are reserved for future
  multi-component disambiguation. Not used currently.
- `ALL_CAPS` relation names are reserved for supreme-law constants.

---

## Schema Definition

### The `:create` Statement

Each `:create` defines one relation. Columns before `=>` are **keys**
(composite primary key). Columns after `=>` are **values**.

```cozo
:create relation_name {
  key_col_1: Type,
  key_col_2: Type =>
  val_col_1: Type,
  val_col_2: Type
}
```

The `=>` separator is the number **2** again: the left side is identity
(what distinguishes this row — Solar, asserting, defining), the right side
is quality (what characterizes it — Lunar, describing, receiving). Every
relation is a polarity between what a thing IS (key) and what it CARRIES
(value).

Key-only relations (no value columns) omit the `=>`:

```cozo
:create thought_tag {
  thought_id: String,
  tag: String
}
```

A key-only relation is pure identity with no qualities — a bare assertion
of association. `thought_tag` says "this thought HAS this tag" without
saying anything more about the relationship.

### Column Types

| CozoDB Type | Meaning | Cap'n Proto | Rust |
|-------------|---------|-------------|------|
| `String` | UTF-8 text | `Text` | `String` |
| `Int` | 64-bit integer | `Int64` | `i64` |
| `Float` | 64-bit float | `Float64` | `f64` |
| `Bool` | Boolean | `Bool` | `bool` |
| `Bytes` | Raw bytes | `Data` | `Vec<u8>` |

`Json` and `List` exist in CozoDB but map to `Text`/`Data` in Cap'n Proto.
Prefer `String` with structured content over `Json`.

### Column Naming

Always `snake_case`. Dots do not work in column names.

```cozo
# Good
created_ts: String
agent_id: String
in_world_hash: Bool

# Bad
createdTs: String     # camelCase — reserved for Cap'n Proto output
AgentId: String       # PascalCase — reserved for types
```

---

## Multi-Statement Files

CozoDB requires certain statements (`:create`, `:replace`, `:put`, `:rm`)
to execute as standalone queries. In `.cozo` files, separate statements
with **blank lines**:

```cozo
:create Phase {
  name: String =>
  description: String
}

:create Dignity {
  name: String =>
  rank: Int
}
```

The `split_cozo_statements()` function in `criome-cozo` splits on blank-line
boundaries. Each segment is executed independently.

### Comments

CozoScript uses `#` for comments. The `//` token on its own line separates
comment blocks (convention, not syntax).

```cozo
#── Section heading ─────────────────────────────
#Description of what follows.
//
#Additional context separated by //.

:create relation { ... }
```

Comment-only blocks (lines that are all `#` comments or `//`) must be
filtered out before execution. The `is_comment_only()` helper handles this.

---

## Queries

### Variable Binding

CozoDB auto-binds variables that match column names. This eliminates
repetition — the variable IS the column name:

```cozo
# Variables match column names — clean, no repetition
?[id, title, phase] := *thought{id, title, phase}
```

The explicit `{column: Variable}` syntax is only needed when they differ:

```cozo
# Renaming — only when necessary
?[thought_id, thought_title] :=
  *thought{id: thought_id, title: thought_title}
```

### Filtering

```cozo
# Equality
?[id, title] := *thought{id, title, phase}, phase == "manifest"

# Inequality
?[id, title] := *thought{id, title, phase}, phase != "retired"

# Multiple conditions (comma = AND)
?[id, title] := *thought{id, title, phase, dignity},
  phase == "manifest", dignity == "eternal"
```

**Important**: Binding a column to a literal makes it a constant, not a
head variable:

```cozo
# WRONG — "id" is unbound in the head
?[id] := *thought{id: "t-user-1"}

# RIGHT — bind to variable, then filter
?[id] := *thought{id}, id == "t-user-1"

# RIGHT — use a derived head variable
?[found] := *thought{id: "t-user-1"}, found = true
```

### Inline Data

```cozo
?[name, rank] <- [
  ["eternal", 0],
  ["proven", 1],
  ["seen", 2]
]
```

Use `<-` to inject literal data. Rows are arrays. Types are inferred.

### Ordering and Limiting

```cozo
?[id, ts] := *world_commit{id, ts}
  :order -ts
  :limit 1
```

`:order -col` sorts descending. `:limit N` caps results.

---

## Mutations

### `:put` — Insert or Update

```cozo
?[id, kind, phase, dignity] <- [["t-1", "observation", "becoming", "seen"]]
:put thought {id => kind, phase, dignity}
```

The `:put` clause must specify key/value separation with `=>`. If the key
already exists, the row is replaced. If not, it is inserted.

**All columns must appear in the head.** If the relation has 10 columns,
all 10 must be in `?[...]` and in the `:put` clause.

### `:rm` — Delete

```cozo
?[id, kind, scope, status, title, body, created_ts, updated_ts, phase, dignity] :=
  *thought{id, kind, scope, status, title, body, created_ts, updated_ts, phase, dignity}
:rm thought {id => kind, scope, status, title, body, created_ts, updated_ts, phase, dignity}
```

`:rm` requires the full column list in the head, bound from the relation.

### Simulating UPDATE

CozoDB has no `UPDATE` statement. To change a column value:

1. Query the full row with all columns
2. Construct new values (modify the target column)
3. `:put` the modified row (replaces by key)

In Rust, the pattern for promoting `phase` from `"becoming"` to `"manifest"`:

```rust
// Query all becoming rows with all columns
let query = format!(
    "?[{col_list}] := *{rel}{{{col_list}}}, phase == \"becoming\""
);
let becoming_rows = db.run_script(&query)?;

// For each row, replace the phase column and :put back
for row in luna_rows {
    // ... modify phase value at phase_idx ...
    let put = format!(
        "?[{col_list}] <- [[{val_list}]] :put {rel} {{{key_cols} => {val_cols}}}"
    );
    db.run_script(&put)?;
}
```

---

## Introspection

### `::relations` — List All Relations

```cozo
::relations
```

Returns: `rows` array, each row has relation name, column count, type, etc.

**DataValue wrapping**: CozoDB serializes values as tagged JSON:

```json
{"Str": "thought"}       // not plain "thought"
{"Bool": true}            // not plain true
{"Num": {"Int": 42}}      // not plain 42
```

Use `datavalue::as_str()`, `datavalue::as_bool()`, `datavalue::as_i64()`
helpers from `samskara-codegen` to unwrap.

### `::columns <relation>` — Describe a Relation

```cozo
::columns thought
```

Returns rows with headers: `["column", "is_key", "index", "type",
"has_default", "default_expr"]`. All wrapped in DataValue tags.

The `column_info::from_columns_result()` function parses this into
`Vec<ColumnInfo>`.

---

## Escaping

CozoScript strings use `"..."` with backslash escaping:

```cozo
"simple string"
"string with \"quotes\""
"string with \\backslash"
```

When embedding CozoScript in Rust `format!` strings:

```rust
let esc = |s: &str| s.replace('\\', "\\\\").replace('"', "\\\"");

let script = format!(
    r#"?[id, title] <- [["{}","{}"]]
    :put thought {{id => title}}"#,
    esc(&id), esc(&title),
);
```

**Braces**: `{{` and `}}` produce literal `{` and `}` in Rust `format!`.
CozoScript binding also uses `{}`. Double braces in Rust → single braces
in CozoScript.

**Binary data in String columns**: Use base64 encoding to avoid escaping
issues with complex JSON or binary content.

---

## Phase and Dignity Columns

Every versioned relation carries `phase: String` and `dignity: String`.
These are the numbers **3** and **5** from the subdivision chain.

**Phase** is the number 3 — awareness of time. Three phases create the
minimal lifecycle: what is becoming (luna), what is manifest (sol), what has
passed (saturnus). Without 3, there is no time, no VCS, no history.

**Dignity** is the number 5 — awareness of quality. Five levels distinguish
how much trust a fact carries. Without 5, all facts are equal and the
system cannot reason about its own reliability.

### Phase Values

| Value | Meaning | In world hash |
|-------|---------|---------------|
| `"manifest"` | Active — committed truth | Yes |
| `"becoming"` | Staged — proposed, not yet committed | No |
| `"retired"` | Archived — superseded | No |

### Dignity Values

| Value | Saṃskṛta | Rank | Meaning |
|-------|----------|------|---------|
| `"eternal"` | nitya | 0 | Immutable, foundational invariant |
| `"proven"` | siddha | 1 | Verified through trusted source |
| `"seen"` | dṛṣṭa | 2 | Witnessed, observed (default) |
| `"uncertain"` | sandeha | 3 | Unverified claim |
| `"delusion"` | bhrama | 4 | Error, unreliable source |

### Querying Live State

```cozo
# All manifest facts (in the world hash)
?[id, title] := *thought{id, title, phase}, phase == "manifest"

# All visible facts (manifest + becoming, hide retired)
?[id, title, phase] := *thought{id, title, phase}, phase != "retired"

# Only eternal-dignity principles
?[id, rule] := *principle{id, rule, dignity}, dignity == "eternal"
```

### Default for New Assertions

New facts enter with `phase = "becoming"`, `dignity = "seen"`. They become
active (`"manifest"`) when `commit_world` is called.

---

## Commit Message Format

For commit message format, see [VCS_PATTERNS.md](VCS_PATTERNS.md).

The `CommitType`, `Action`, and `Verdict` enum relations defined in the
world seed are the authoritative source for commit message values.

---

## Contract Relations

A **contract relation** is a relation whose schema is shared between two
components, each with its own CozoDB instance. The contract is the
two-pointed arrow — the shared interface through which components
communicate asynchronously.

Contract relations are defined in their own repo (e.g.,
`samskara-lojix-contract`). Both components depend on this repo and
create the same relation schema in their respective databases.

In CozoScript, a contract relation looks identical to an internal
relation — there is no syntactic distinction. The distinction is
organizational:

- **Internal relations** are defined in the component's own schema
  file (e.g., `samskara-world-init.cozo`)
- **Contract relations** are defined in the contract repo's schema
  file and loaded by both components at startup

Data in a contract relation is the ONLY coupling between components.
No shared state, no function calls, no imports cross the contract
boundary. This enforces async/actor/agent architecture by construction.

---

## The Codegen Pipeline

### How It Works

1. `build.rs` loads schema (`:create`) and seed (`:put`) from their
   authoritative `.cozo` files into an in-memory CozoDB
2. `samskara-codegen` queries the `Enum` registry (authoritative) and
   checks PascalCase naming (convention)
3. In registry → enum. PascalCase without registry → fallback enum
4. Enum rows → Cap'n Proto enumerants (lowercased), sorted alphabetically
5. All other relations → Cap'n Proto structs, fields by `::columns` index
6. Column names convert: `snake_case` → `camelCase` for Cap'n Proto
7. File ID = blake3 hash of all relation/enum names, high bit set
8. Schema hash = blake3 of the full `.capnp` text
9. `capnpc` compiles `.capnp` → Rust Reader/Builder types

**No data lives in build.rs.** The build script loads the seed file. The
seed file is the single source of truth for enum variants.

This pipeline IS the Sema genesis bootstrap: the system's relational
specification generates its own binary encoding (Cap'n Proto v1), which
is then archived in `archive_reader_version` — Kronos logs the schema
hash, the segment table, and the full capnp text. The first Sema is
specified by the capnp output of its own specification. Then Sema uses
itself to define its next version. Each version is preserved by Saturn.

### Adding a New Relation

Checklist for adding a versioned relation to samskara:

1. **Schema**: Add `:create` to `samskara/schema/samskara-world-init.cozo`
   with `phase: String, dignity: String` columns (if versioned).

2. **Seed**: Add seed data to `samskara/schema/samskara-world-seed.cozo`.

3. **Enum registry**: If adding a PascalCase enum, add a row to the `Enum`
   seed in `samskara/schema/samskara-world-seed.cozo`.

4. **VERSIONED_RELATIONS**: Add the relation name to the constant in
   `samskara/src/vcs/mod.rs`.

5. **has_phase_column**: If the relation carries `phase`/`dignity` columns,
   add it to the `has_phase_column()` match in `samskara/src/vcs/mod.rs`.

6. **Verify**: `cargo test` in both `samskara-codegen` and `samskara`.

---

## The DataValue JSON Format

CozoDB serializes query results as JSON with tagged value types:

```json
{
  "headers": ["id", "title", "phase"],
  "rows": [
    [{"Str": "t-1"}, {"Str": "Hello"}, {"Str": "manifest"}],
    [{"Str": "t-2"}, {"Str": "World"}, {"Str": "becoming"}]
  ]
}
```

### Tag Types

| Tag | JSON | Rust extraction |
|-----|------|-----------------|
| `{"Str": "value"}` | String | `datavalue::as_str(v)` |
| `{"Bool": true}` | Boolean | `datavalue::as_bool(v)` |
| `{"Num": {"Int": 42}}` | Integer | `datavalue::as_i64(v)` |
| `{"Num": {"Float": 3.14}}` | Float | — |
| `"Null"` | Null | — |

### Converting DataValue to CozoScript Literal

The `datavalue_to_cozo_literal()` function in `vcs/restore.rs` handles the
reverse: DataValue JSON → CozoScript string literal for `:put` operations.

```rust
// {"Str": "hello"} → "\"hello\""
// {"Bool": true}   → "true"
// {"Num": {"Int": 42}} → "42"
```
