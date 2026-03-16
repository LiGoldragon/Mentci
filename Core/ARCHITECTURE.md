# Mentci VersionOne Architecture

## Two-Agent Model

Mentci v1 consists of exactly two agents that never interact directly.
All communication flows through shared datalog relations defined in the
samskara-lojix-contract repo.

```
+---------------------+                        +---------------------+
|      SAMSKARA       |                        |       LOJIX         |
|  (pure datalog)     |                        |  (DSL transpiler)   |
|                     |                        |                     |
|  Ontology:          |                        |  Reads: live DSL    |
|  Category theory    |   contract relations   |  Emits: TS or Rust  |
|  Solar/Lunar poles  | <--------------------> |  Returns: datalog   |
|  2->3->7->12->36    |   (shared schemas in   |                     |
|  ->72->360           |   samskara-lojix-      |  Phase 1: TS target |
|                     |    contract repo)      |  Phase 2: Rust self |
|  [CozoDB instance]  |                        |  [CozoDB instance]  |
+---------------------+                        +---------------------+
         |                                               |
         |              +------------------+             |
         +----------->> | criome-cozo      | <<----------+
                        | (CozoDB wrapper) |
                        +------------------+
```

## Samskara — Pure Datalog Agent

Samskara is a pure datalog agent. It sees ONLY relations. It has no
awareness of files, code, the operating system, or any imperative
execution context.

Its ontology is rooted in astrological category theory:

- **Solar/Lunar polarity** — the fundamental binary distinction
- **2 -> 3 -> 7 -> 12 -> 36 -> 72 -> 360** — the subdivision chain
  that structures all relation categories

Samskara owns its CozoDB instance. No other agent reads from or writes
to this database.

## Lojix — DSL Transpiler

Lojix is a Rust-capabilities-matching datalog DSL transpiler. It:

1. Reads "live" DSL relations from its own CozoDB
2. Transpiles them to executable code
3. Executes the transpiled code
4. Translates results back into datalog relations
5. Writes output relations to the shared contract surface

Lojix owns its CozoDB instance. No other agent reads from or writes
to this database.

### The "live" Boolean

Every DSL relation carries a `live` boolean column. When `live = true`,
the relation represents active code that Lojix will transpile and execute.
When `live = false`, the relation is historical — it remains in the DB for
audit and replay but is not part of the current execution surface.

## Data Ownership (Sema Principle)

Each agent owns its own database exclusively:

- Samskara's CozoDB: only Samskara reads/writes
- Lojix's CozoDB: only Lojix reads/writes

Agents communicate by writing to and reading from the shared contract
relation schemas. The contract repo defines what these relations look like;
each agent materializes its side in its own DB.

## Communication Protocol

Agents communicate ONLY through shared contract relations. There is no
RPC, no message passing, no shared memory. The contract relations are the
sole interface.

The `samskara-lojix-contract` repo is the single source of truth for
which relations exist, their column types, and their semantics.

## Phases

### Phase 1 — Rust Binary Transpiler + TypeScript Target

- Lojix is a compiled Rust binary
- It transpiles DSL relations to TypeScript
- TypeScript is executed for debugging and rapid iteration
- Samskara operates as pure datalog

### Phase 2 — Self-Hosting Transpiler + Rust Target

- Lojix transpiles DSL relations to Rust
- The transpiler itself is expressed in its own DSL (self-hosting)
- TypeScript target remains available for debugging
- Full production path is pure Rust end-to-end

## Technology Stack

| Layer | Technology |
|---|---|
| Application logic | Rust |
| Build system | Nix |
| Database | CozoDB (via criome-cozo) |
| VCS | Jujutsu (jj) |
| Debug target | TypeScript (phase 1) |
| Production target | Rust (phase 2) |
