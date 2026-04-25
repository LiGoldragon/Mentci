# ARCHITECTURE — mentci

The development environment for building [criome](https://github.com/LiGoldragon/criome).
Holds the workspace conventions, design corpus (`reports/`),
agent rules, and tooling integrations; symlinks every canonical
sema-ecosystem repo under `repos/` for unified navigation.

> **Read this file first.** Then read [criome's
> ARCHITECTURE.md](https://github.com/LiGoldragon/criome/blob/main/ARCHITECTURE.md)
> for the project being built.

## What this repo is, today

A development environment. Its concrete responsibilities:

- **Workspace orchestration.** [`devshell.nix`](devshell.nix)'s
  `linkedRepos` symlinks every canonical sema-ecosystem repo
  into [`repos/`](repos/) on `nix develop` / direnv entry.
  Agents working in mentci see the entire ecosystem at one
  path.
- **Design corpus.** [`reports/`](reports/) holds the evolving
  decision-trail (currently 6 reports, soft cap at ~12 per
  [AGENTS.md](AGENTS.md) "Report rollover").
- **Workspace manifest.** [`docs/workspace-manifest.md`](docs/workspace-manifest.md)
  tracks every repo in `~/git/` with its status (CANON,
  TRANSITIONAL, CANON-MISSING, RETIRED, ARCHIVED, SHELVED,
  OFF-SCOPE). `devshell.nix`'s `linkedRepos` mirrors the
  CANON + TRANSITIONAL entries.
- **Agent conventions.** [`AGENTS.md`](AGENTS.md) is the
  source of truth for: per-repo `ARCHITECTURE.md` discipline,
  AGENTS.md/CLAUDE.md shim, restate-to-refute rule, report
  rollover at the soft cap, jj + always-push workflow,
  documentation-layers separation.
- **Tooling integration.** `bd` (issue tracker) state lives
  here; jj is the version-control surface; nix flakes provide
  reproducible toolchains.

## What this repo is meant to become

mentci's name evokes *mind* — the surface where thinking
happens. Today, that surface is for **agents and Li, building
criome**. Long-term:

When criome becomes the substrate for the world's data and
messaging — typed, content-addressed, validated, queryable,
no-hallucination — the legacy software stack of fragmented UIs
loses its reason to exist. **mentci is meant to replace it.**
The interaction surface for working with criome's database
becomes the interaction surface for everything: code, data,
communication, knowledge, attention.

This is distant. Today mentci is a workshop. The patterns that
make it a good workshop for humans + agents (clear
conventions, deletable reports, skeleton-as-design,
trim-aggressively) are the same patterns that, scaled, make a
good universal UI. Build well now; the path forward is
continuous, not a discontinuous reinvention.

## Layout

```
mentci/                        # local dir today is mentci-next/;
                               # github repo is renamed to mentci
├── ARCHITECTURE.md            ← this file
├── AGENTS.md                  ← agent conventions (source of truth)
├── CLAUDE.md                  ← Claude Code shim → AGENTS.md
├── README.md
├── devshell.nix               ← workspace symlinks + tooling
├── flake.nix
├── docs/
│   └── workspace-manifest.md  ← every repo's status
├── reports/                   ← decision-trail (~6, soft cap 12)
├── repos/                     ← symlinks to canonical repos
└── .beads/                    ← bd issue tracker state
```

The local directory is `mentci-next/` for now; the github
repo is `mentci`. The local directory rename is deferred (would
break editor cwd state mid-session); Li will rename it when no
agent is running.

## How agents work here

Per [AGENTS.md](AGENTS.md):

1. **Read this file** for the dev environment shape.
2. **Read [criome's
   ARCHITECTURE.md](https://github.com/LiGoldragon/criome/blob/main/ARCHITECTURE.md)**
   for the project's design.
3. Each canonical repo carries its own `ARCHITECTURE.md` at
   root (matklad pattern). Open the relevant one when working
   inside a specific repo.
4. Decision history lives in `reports/`. Trim aggressively;
   delete don't banner.

## Conventions

(Full list in [AGENTS.md](AGENTS.md). The most load-bearing:)

- **Per-repo `ARCHITECTURE.md`** at root in every canonical
  repo. Points at criome's ARCHITECTURE.md for cross-cutting
  context; does not duplicate.
- **AGENTS.md / CLAUDE.md shim** so Codex and Claude Code
  converge on one source of truth.
- **Report rollover at ~12 soft cap.** When the count tips
  above, run a rollover pass: roll into successor / implement
  and delete / delete.
- **restate-to-refute prohibition.** State positively; rejected
  framings live once, in criome's §10.
- **jj + always-push.** Every change ships immediately;
  conversation history is not durable.

## Status

**Active dev environment.** Long-term direction: universal UI.
Migration path is co-determined by criome's progress and the
maturation of LLM tooling against typed data; no fixed
schedule.
