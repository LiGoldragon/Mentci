# CLAUDE.md

Mentci VersionOne workspace — Nix flake aggregating the micro-repo ecosystem
for the two-agent system (Samskara + Lojix). No application code lives here.

## Source of Truth

The authoritative rules, patterns, and references live in samskara's `rule`
and `source` relations (world.db). If the `samskara-reader` MCP server is
available, query it directly. Otherwise, read Core/*.md as a fallback — those
files are DB-superseded projections and may drift.

## VCS

Jujutsu (`jj`) is mandatory. Git is the backend only — do not use git
commands directly. Use `jj` for all version control operations.

## Commit Messages

Commit messages are CozoScript tuple-of-three-tuples (Sol/Luna/Saturnus).

## Language Policy

- **Rust** only for application logic.
- **Nix** only for builds and dev shells.

## Build

```
nix develop          # enter dev shell
```
