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

A rule about Nix naming does not appear in RUST_PATTERNS.md.
A rule about error types does not appear in COZO_PATTERNS.md.
