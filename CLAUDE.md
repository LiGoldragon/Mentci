# CLAUDE.md

This file provides guidance to Claude Code when working in this repository.

## Overview

This is the **VersionOne workspace** — a Nix flake that ties together the
micro-repo ecosystem for Mentci v1. It does not contain application code.
It provides the dev shell, flake inputs, and architecture documentation for
the two-agent system: Samskara + Lojix.

## Architecture

Mentci v1 is built on two agents communicating through datalog relations only:

- **Samskara** is a pure datalog agent. It ONLY sees relations — never files,
  code, or the OS. Its ontology is rooted in astrological category theory
  (Solar/Lunar polarity, the 2-3-7-12-36-72-360 subdivision chain).

- **Lojix** is a transpiler agent. It reads live DSL from its CozoDB, transpiles
  to TypeScript (phase 1, debug) and Rust (phase 2, production), and translates
  execution results back into datalog relations.

Each agent owns its own CozoDB instance (Sema data ownership principle). Agents
never share a database — they communicate exclusively through shared contract
relations defined in the samskara-lojix-contract repo.

**criome-cozo** provides the shared CozoDB wrapper crate used by both agents.

## Repos

| Repo | Purpose |
|---|---|
| `samskara-lojix-contract` | Shared datalog relation schemas between agents |
| `criome-cozo` | CozoDB wrapper crate |
| `samskara` | Pure datalog agent |
| `lojix` | DSL transpiler (TS phase 1, Rust phase 2) |
| `Mentci` | This workspace (flake + dev shell + docs) |

## VCS

Jujutsu (`jj`) is mandatory. Git is the backend only — do not use git
commands directly. Use `jj` for all version control operations.

## Language Policy

- **Rust** only for application logic.
- **Nix** only for builds and dev shells.
- No other languages in production paths.

## Micro-repo Style

Each concern lives in its own repository. Contracts between components are
also their own repos. This workspace aggregates them via Nix flake inputs.

## Build

```
nix develop          # enter dev shell
# Individual components are built in their own repos
```
