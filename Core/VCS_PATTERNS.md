<!-- SUPERSEDED: This document is now a read-only projection of samskara
     relations. The authoritative source is the `rule` relation in samskara's
     world.db. To query: ?[id, body, rationale] := *rule{id, body, rationale,
     microtheory: "vcs"} -->

# VCS Patterns

Version control for the Criome. Jujutsu is the interface. Git is the
storage backend. These are operational rules, not stylistic preferences.

---

## Jujutsu Only

All version control operations use `jj`. Git commands are forbidden —
git is storage plumbing, not a user interface. This applies to all repos
in the ecosystem.

Always pass `-m` to `jj describe` and `jj commit`. Never launch an
interactive editor — the agent context is non-interactive, and a silent
editor launch blocks execution indefinitely.

---

## Commit Message Format

A commit message is a CozoScript tuple of three tuples — Sol, Luna,
Saturnus:

```
(("type", "scope"), ("action", "what"), ("verdict", "why"))
```

| Tuple | Role | Planet |
|-------|------|--------|
| **Sol** — identity | What kind of change, where | ☉ The manifest |
| **Luna** — transformation | What action, what transformed | ☽ The becoming |
| **Saturnus** — context | Why the change was needed | ♄ The judgment |

### Sol tuple (type, scope)

The type is a `CommitType` enum value. The scope is the repo or
subsystem name. Scope is optional for single-concern repos.

| Type | When |
|------|------|
| `fix` | Bug fix or correction |
| `feat` | New feature or capability |
| `doctrine` | Foundational invariant change |
| `refactor` | Restructure without behavior change |
| `schema` | Relation schema change |
| `contract` | Cross-component contract change |
| `codegen` | Generated code or build pipeline |
| `prune` | Remove dead code or obsolete content |
| `doc` | Documentation only |
| `nix` | Nix flake or dev shell |
| `test` | Test addition or modification |
| `migrate` | Data or naming migration |

### Luna tuple (action, what)

The action is an `Action` enum value. The "what" is a human-readable
description of what was transformed.

| Action | When |
|--------|------|
| `add` | Introduce something new |
| `remove` | Delete something entirely |
| `rename` | Change a name |
| `rewrite` | Replace content with new version |
| `extract` | Pull out into its own unit |
| `merge` | Combine multiple things |
| `split` | Divide one thing into multiple |
| `move` | Relocate without content change |
| `replace` | Swap one thing for another |
| `fix` | Correct an error |
| `extend` | Add to an existing thing |
| `reduce` | Simplify or shrink |

### Saturnus tuple (verdict, why)

The verdict is a `Verdict` enum value. The "why" is a human-readable
reason. The Saturnus tuple is optional — omit it when the reason is
self-evident from the Sol and Luna tuples.

| Verdict | When |
|---------|------|
| `error` | Something was wrong or broken |
| `evolution` | Natural growth beyond previous form |
| `dependency` | Required by upstream or downstream change |
| `gap` | Missing capability or coverage |
| `redundancy` | Unnecessary duplication or coupling |
| `violation` | Broke an invariant or principle |
| `drift` | Gradual divergence from intended state |
| `staleness` | Content no longer reflects reality |

### Examples

```
(("feat", "samskara"), ("add", "MCP server with 7 tools — query, assert, commit, restore"), ("gap", "no external interface existed for the datalog agent"))

(("fix", "criome-cozo"), ("fix", "SQLite path validation for non-UTF-8"), ("error", "open_sqlite panicked on non-UTF-8 paths"))

(("prune", "Mentci"), ("remove", "HANDOVER.md — bootstrap-only document"), ("staleness", "described superseded state, should have been removed days ago"))
```

---

## Push Behavior

Push to `main` immediately after every change. No feature branches.
No batching. No asking for confirmation — the change is either ready
or it is not committed.

`main` is the only bookmark. The working copy is the staging area.
Jujutsu's immutable commit model means pushed commits cannot be
accidentally modified.
