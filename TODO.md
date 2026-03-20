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

## Next Steps

- [ ] Commit samskara's dirty worktree (18 changes from reconciliation)
- [ ] Design the Lojix DSL grammar
- [ ] Update `criome-cozo` with phase-aware query helpers
- [ ] Self-referencing capnp file ID (hash schema with zeroed ID, use hash as ID)
- [ ] Hard-coded phase/dignity string literals → constants or enum queries
- [ ] Write `.capnp` schema for WorldSnapshot / WorldDelta (currently JSON+zstd+base64)
