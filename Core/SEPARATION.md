# Separation of Concern

Every instruction, rule, or specification exists **exactly once**, at the
**highest valid layer**. All other documents link to the authoritative
source. Duplication across documents is forbidden.

When the same rule appears in two places, one of them is wrong — either
now or eventually. The fix is not synchronization. The fix is to delete
the copy and leave a link.

---

## Layer hierarchy

| Layer | Example | Durability |
|-------|---------|------------|
| Repository name | `samskara`, `criome-cozo` | Permanent |
| Directory path | `Core/`, `schema/` | Stable |
| File name | `RUST_PATTERNS.md` | Stable |
| Section heading | `## Error Types` | Mutable |
| Inline text | Prose, examples | Mutable |

Meaning resolves from the outermost layer inward. Inner layers assume
outer context and never restate it. A file inside `Core/` does not
explain that it contains core patterns — the path already says so.

---

## Cross-referencing

When a concept is authoritative in one document but relevant in another,
the second document links:

```markdown
For commit message format, see [VCS_PATTERNS.md](VCS_PATTERNS.md).
```

It does not summarize, excerpt, or restate. The link is the reference.

---

## Read before writing

Before editing any Core/ document, read all essential documents first:

1. `ARCHITECTURE.md` — the system design and component relationships
2. `META_PATTERN.md` — the philosophical and mathematical foundations
3. The document being edited — in full, not just the section

The purpose is not to memorize content but to grasp the author's
intent, vocabulary, and framing. Edits that contradict the existing
voice — using superseded terminology, introducing foreign concepts,
or restating what another document already says — indicate that the
reading step was skipped.

This applies equally to human and agent authors. The documents are
the institutional memory. Editing without reading is editing without
understanding.

---

## Scope boundaries

Each pattern document owns its domain:

| Document | Domain |
|----------|--------|
| `RUST_PATTERNS.md` | Rust code structure, types, errors, naming |
| `COZO_PATTERNS.md` | CozoScript, relation design, datalog conventions |
| `VCS_PATTERNS.md` | Version control, commits, push behavior |
| `NIX_PATTERNS.md` | Nix expressions, flakes, builds |
| `MCP_PATTERNS.md` | MCP server structure, tool handlers |
| `MICRO_REPO_PATTERNS.md` | Repository boundaries, contracts, flake inputs |
| `ARCHITECTURE.md` | System-level design, component relationships |
| `META_PATTERN.md` | Mathematical and philosophical foundations |
| `REFERENCES.md` | Primary sources and bibliography for claims in Core/ |

A rule about Nix naming does not appear in RUST_PATTERNS.md.
A rule about error types does not appear in COZO_PATTERNS.md.

---

## Cascade operations

Renaming a public type in a leaf crate breaks every downstream
consumer. Plan the full dependency graph before starting.

Order: leaf first, then upward through the tree. Each repo must
build against the updated upstream before proceeding to the next.

```
criome-cozo          (leaf — rename here first)
  ↑
samskara-codegen     (depends on criome-cozo)
samskara-lojix-contract  (depends on criome-cozo)
  ↑
samskara             (depends on all above)
  ↑
Mentci workspace     (aggregates all)
```

Never rename a type in one repo and "fix the callers later." The
tree must build at every step.

---

## Repository identity

A rewrite is a new repo, not a force-push to an existing one. Existing
repos have history, branches, and contributors that cannot be discarded.
Create a new repo under the correct owner. If the old repo must be
superseded, archive it — do not overwrite it.

---

## Provenance and dignity on external claims

When documenting external service behavior (APIs, credentials, access
tiers), every claim carries provenance and dignity:

- **proven**: verified against the actual service (tested, observed)
- **seen**: read from primary documentation (official FAQ, account page)
- **uncertain**: from web search, third-party guides, or AI training data
- **delusion**: contradicted by direct observation

If the primary source cannot be accessed (JS-rendered, paywalled),
the claim is `uncertain` at best. Do not present `uncertain` claims
as `proven`.
