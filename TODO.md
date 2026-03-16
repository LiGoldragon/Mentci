# Mentci v1 — Open Items

## To Be Determined

- **Cross-agent commits**: When Lojix writes `eval_result` to the contract
  surface and Samskara reads it — does that auto-trigger a samskara-vcs
  commit? Or only explicit commits? Depends on how the contract surface
  matures and what the agent loop looks like.

## Next Steps

- [ ] Wire samskara-world schema into the samskara crate (replace old `AI-init.cozo`)
- [ ] Implement genesis bootstrap in Rust (create relations → seed → hash → first commit)
- [ ] Add `capnp` + `capnpc` + `blake3` + `zstd` to samskara's `Cargo.toml`
- [ ] Write `.capnp` schema for WorldSnapshot / WorldDelta
- [ ] Design the Lojix DSL grammar
- [ ] Propagate `liveness: String` to existing relations in samskara + lojix + contract
- [ ] Update `criome-cozo` with liveness-aware query helpers
