# Sema CozoScript Patterns

CozoDB (via CozoScript / Datalog) is the first-version authority for Mentci.
Relations are the source of truth. Rust, Cap'n Proto, and all other formats
are derived from relations. This document defines how to write CozoScript
that conforms to the Sema object style.

---

## Relation Naming

### The Capitalization Rule

| Casing | Meaning | CozoDB role | Rust output |
|--------|---------|-------------|-------------|
| `PascalCase` | Categorical type / enum | Single String key, rows = variants | `enum Phase { Sol, Luna, Saturnus }` |
| `snake_case` | Data / instance relation | Key + value columns, rows = instances | `struct Thought { id, kind, ... }` |

This is enforced by `samskara-codegen`: PascalCase relations with a single
String key are detected as enums. Everything else becomes a struct.

An enum value that is itself categorical (will have its own subtypes) should
be PascalCase in the data: `"Sol"`, `"Luna"`, `"Saturnus"`. Terminal values
that don't expand stay lowercase: `"eternal"`, `"proven"`, `"seen"`.

```cozo
# Enum: PascalCase, single String key
:create Phase {
  name: String =>
  glyph: String,
  in_world_hash: Bool,
  description: String
}

# Struct: snake_case, key => value columns
:create thought {
  id: String =>
  kind: String,
  scope: String,
  phase: String,
  dignity: String
}
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

Key-only relations (no value columns) omit the `=>`:

```cozo
:create thought_tag {
  thought_id: String,
  tag: String
}
```

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
?[id, title] := *thought{id, title, phase}, phase == "sol"

# Inequality
?[id, title] := *thought{id, title, phase}, phase != "saturnus"

# Multiple conditions (comma = AND)
?[id, title] := *thought{id, title, phase, dignity},
  phase == "sol", dignity == "eternal"
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
?[id, kind, phase, dignity] <- [["t-1", "observation", "luna", "seen"]]
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

In Rust, the pattern for promoting `phase` from `"luna"` to `"sol"`:

```rust
// Query all luna rows with all columns
let query = format!(
    "?[{col_list}] := *{rel}{{{col_list}}}, phase == \"luna\""
);
let luna_rows = db.run_script(&query)?;

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

### Phase Values

| Value | Meaning | In world hash |
|-------|---------|---------------|
| `"sol"` | Manifest — committed truth | Yes |
| `"luna"` | Becoming — staged, proposed | No |
| `"saturnus"` | Archived — superseded | No |

Phase values will become PascalCase (`"Sol"`, `"Luna"`, `"Saturnus"`) when
their corresponding enum relations (Sol, Luna, Saturnus with subtypes) are
defined. Currently lowercase.

### Dignity Values

| Value | Saṃskṛta | Rank | Meaning |
|-------|----------|------|---------|
| `"eternal"` | nitya | 0 | Immutable, foundational invariant |
| `"proven"` | siddha | 1 | Verified through trusted source |
| `"seen"` | dṛṣṭa | 2 | Witnessed, observed (default) |
| `"uncertain"` | sandeha | 3 | Unverified claim |
| `"delusion"` | bhrama | 4 | Error, unreliable source |

Dignity values are terminal — they do not expand into subtypes. They stay
lowercase.

### Querying Live State

```cozo
# All manifest facts (in the world hash)
?[id, title] := *thought{id, title, phase}, phase == "sol"

# All visible facts (manifest + staged, hide archived)
?[id, title, phase] := *thought{id, title, phase}, phase != "saturnus"

# Only eternal-dignity principles
?[id, rule] := *principle{id, rule, dignity}, dignity == "eternal"
```

### Default for New Assertions

New facts enter with `phase = "luna"`, `dignity = "seen"`. They become
manifest (`"sol"`) when `commit_world` is called.

---

## The Codegen Pipeline

### How It Works

1. `build.rs` loads schema (`:create`) and seed (`:put`) from their
   authoritative `.cozo` files into an in-memory CozoDB
2. `samskara-codegen` queries the fully populated database
3. PascalCase relations with a single String key → detected as enums
4. Enum rows → Cap'n Proto enumerants, sorted alphabetically
5. All other relations → Cap'n Proto structs, fields ordered by `::columns` index
6. Column names convert: `snake_case` → `camelCase` for Cap'n Proto
7. File ID = blake3 hash of all relation/enum names, high bit set
8. Schema hash = blake3 of the full `.capnp` text
9. `capnpc` compiles `.capnp` → Rust Reader/Builder types

**No data lives in build.rs.** The build script loads the seed file. The
seed file is the single source of truth for enum variants.

### Adding a New Relation

Checklist for adding a versioned relation to samskara:

1. **Schema**: Add `:create` to `Mentci/Core/samskara-world-init.cozo`
   with `phase: String, dignity: String` columns (if versioned).

2. **Copy**: Copy the schema file to `samskara/schema/samskara-world-init.cozo`.

3. **Seed**: Add seed data to `samskara/schema/samskara-world-seed.cozo`.
   PascalCase enums need seed rows for codegen to detect their variants.

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
    [{"Str": "t-1"}, {"Str": "Hello"}, {"Str": "sol"}],
    [{"Str": "t-2"}, {"Str": "World"}, {"Str": "luna"}]
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
