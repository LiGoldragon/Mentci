# Mentci v1 — Open Items

## To Be Determined

- **Cross-agent commits**: When Lojix writes `eval_result` to the contract
  surface and Samskara reads it — does that auto-trigger a samskara-vcs
  commit? Or only explicit commits? Depends on how the contract surface
  matures and what the agent loop looks like.

## Done

- [x] Wire samskara-world schema into the samskara crate (build.rs loads schema + seed)
- [x] Implement genesis bootstrap in Rust (VCS commit/restore with blake3 content hashing)
- [x] Add `capnp` + `capnpc` + `blake3` + `zstd` to samskara's `Cargo.toml`
- [x] Propagate phase/dignity to existing relations in samskara (replaced `live: Bool`)
- [x] Schema consolidation — `samskara/schema/` is single authority
- [x] Sema refactor — WorldVcs struct, JjMirror struct, methods not free functions
- [x] Commit samskara's dirty worktree (18 changes from reconciliation)
- [x] Phase rename: sol→manifest, luna→becoming, saturnus→retired
- [x] Durable SQLite backend + idempotent boot (world.db in samskara repo)
- [x] world_schema self-description + dynamic VERSIONED_RELATIONS
- [x] CozoScript codegen (to_cozo_init_text + to_cozo_seed_text + to_capnp_text)
- [x] Lojix type dependency on samskara::schema capnp types
- [x] Two-way roundtrip test (seed→DB→seed losslessness proof)
- [x] latina + samskrta equivalence relations seeded
- [x] Execution plan + migration map stored in samskara world.db

## Next Steps

- [ ] Ownership model on relations (agent registry gates mutations)
- [ ] CozoDB triggers for invariant enforcement
- [ ] Review gates for phase transitions (becoming→manifest, manifest→retired)
- [ ] DB-defined MCP tools (handler_script in tool relation)
- [ ] Design the Lojix DSL grammar
- [ ] Self-referencing capnp file ID
- [ ] Write `.capnp` schema for WorldSnapshot / WorldDelta
- [ ] Core/ docs → eventually live as relations in DB (stopgap medium)
