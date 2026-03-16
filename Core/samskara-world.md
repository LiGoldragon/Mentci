# samskara-world — Agent World Model

## Design Principles

1. **Everything is a relation** — Samskara only sees relations, never files
2. **Supersession over mutation** — correct beliefs by asserting new + linking old, never deleting
3. **`live` boolean** — same pattern as existing relations: `live = true` is current, `false` is historical
4. **Typed edges are just relations** — no special graph layer, joins are free in datalog
5. **Namespaced by kind** — not filesystem directories, just a `kind` column

## Relational Graph

```
                          ┌──────────────┐
                          │    thought    │  ← atomic unit of knowledge
                          │──────────────│
                          │ id (key)     │
                          │ kind         │  user | feedback | project | reference | observation
                          │ scope        │  repo name or "global"
                          │ status       │  draft | proposed | approved | tombstoned
                          │ title        │
                          │ body         │
                          │ created_ts   │
                          │ updated_ts   │
                          │ live         │
                          └──────┬───────┘
                                 │
              ┌──────────────────┼──────────────────┐
              │                  │                   │
              ▼                  ▼                   ▼
    ┌─────────────────┐  ┌──────────────┐  ┌────────────────┐
    │  thought_link   │  │ trust_review │  │  thought_tag   │
    │─────────────────│  │──────────────│  │────────────────│
    │ from_id (key)   │  │ thought_id   │  │ thought_id     │
    │ to_id   (key)   │  │ reviewer     │  │ tag            │
    │ rel_type        │  │ verdict      │  └────────────────┘
    │  supersedes     │  │ reason       │
    │  depends_on     │  │ ts           │
    │  references     │  └──────────────┘
    │  contradicts    │
    │  refines        │
    └─────────────────┘

    ┌─────────────────┐          ┌──────────────────┐
    │     agent       │          │   agent_session   │
    │─────────────────│          │──────────────────│
    │ id (key)        │          │ session_id (key) │
    │ name            │          │ agent_id         │
    │ role            │          │ started_ts       │
    │ email           │          │ ended_ts         │
    │ live            │          │ repo_scope       │
    └─────────────────┘          │ summary          │
                                 │ live             │
                                 └──────────────────┘

    ┌─────────────────┐          ┌──────────────────┐
    │      repo       │          │   repo_state     │
    │─────────────────│          │──────────────────│
    │ name (key)      │          │ name (key)       │
    │ github          │          │ bookmark         │
    │ purpose         │          │ build_status     │
    │ depends_on      │          │ last_checked_ts  │
    │ live            │          │ notes            │
    └─────────────────┘          │ live             │
                                 └──────────────────┘

    ┌──────────────────┐
    │    principle     │
    │──────────────────│
    │ id (key)         │
    │ domain           │  architecture | vcs | language | data-ownership
    │ rule             │
    │ reason           │
    │ live             │
    └──────────────────┘
```

## Query Patterns

**Recall approved thoughts in scope:**
```
?[id, title, body] := *thought{id, kind, scope, status, title, body, live},
                       status = "approved", live = true,
                       scope = "samskara"  // or "global"
```

**Follow supersession chain:**
```
?[current, original] := *thought_link{from_id: current, to_id: original, rel_type: "supersedes"}
?[current, original] := *thought_link{from_id: current, to_id: mid, rel_type: "supersedes"},
                         ?[mid, original]  // recursive
```

**Find all feedback for a repo:**
```
?[id, title, body] := *thought{id, kind, scope, title, body, status, live},
                       kind = "feedback", scope = "lojix",
                       status = "approved", live = true
```

**Thoughts with trust gate:**
```
?[id, title, verdict] := *thought{id, title, status, live},
                          *trust_review{thought_id: id, verdict, ..},
                          status = "proposed", live = true
```

## Lifecycle

```
 draft ──propose──► proposed ──approve──► approved
                        │                     │
                        ├──reject──► tombstoned│
                        │                     │
                        └─────────────────────┘
                                              │
                                         supersede
                                              │
                                              ▼
                                     new thought (approved)
                                     + link(new, old, "supersedes")
                                     + old.live = false
```

## Supersession Protocol

When correcting a belief:
1. Assert new `thought` with `status = "approved", live = true`
2. Assert `thought_link{from_id: new, to_id: old, rel_type: "supersedes"}`
3. Update old thought: `live = false`
4. Old thought remains in DB — full lineage preserved, never deleted

## Thought Kinds

| Kind | What it stores | Analogous to |
|---|---|---|
| `user` | Who the human is, their preferences, expertise | FAVA user profile |
| `feedback` | Corrections to agent behavior, with why + how | FAVA preferences |
| `project` | Ongoing work, goals, deadlines, decisions | FAVA observations |
| `reference` | Pointers to external systems (Linear, Grafana, etc.) | FAVA references |
| `observation` | Learned facts about the codebase or ecosystem | FAVA observations |

## Seed Data

The initial world state for this ecosystem would include:
- **agent**: Claude Code agents working across the Mentci repos
- **repos**: criome-cozo, samskara-lojix-contract, samskara, lojix, Mentci
- **principles**: the 6 non-negotiable rules from HANDOVER.md
- **user**: Li, mail@ligoldragon.com, project owner
