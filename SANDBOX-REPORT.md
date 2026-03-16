# Claude-Web Sandbox Capabilities Report

**Date**: 2026-03-16
**Environment**: Claude Code on the web (Firecracker microVM)

---

## 1. Hardware & OS

| Resource | Value |
|---|---|
| Kernel | Linux 6.18.5 x86_64 (Firecracker microVM) |
| OS | Ubuntu 24.04.3 LTS (Noble Numbat) |
| CPUs | 4 cores |
| RAM | 16 GiB |
| Disk | 252 GiB (31 GiB free of effective partition) |
| User | root (uid=0) |
| Init | `/process_api --firecracker-init` (not systemd) |

## 2. Available Tools

### Present and Working

| Tool | Version | Notes |
|---|---|---|
| **rustc** | 1.93.1 (2026-02-11) | Latest stable, edition 2024 supported |
| **cargo** | 1.93.1 | Full crate registry access via proxy |
| **rustup** | 1.28.2 | Target: x86_64-unknown-linux-gnu |
| **git** | 2.43.0 | Backend-only per project policy |
| **gcc/g++** | 13.3.0 | Needed for native C deps (sqlite3-sys, etc.) |
| **cmake** | 3.28.3 | Available for native builds |
| **make** | 4.3 | Available |
| **pkg-config** | 1.8.1 | Available |
| **node** | 22.22.0 | Could serve Lojix Phase 1 (TS target) |
| **python3** | 3.11.14 | Available for scripting |
| **curl/wget** | 8.5.0 / 1.21.4 | Outbound HTTP works (via proxy at 21.0.0.89:15004) |
| **docker** (client) | 29.2.1 | Installed but **daemon not running** |
| **apt** | — | 687 packages installed, full `apt install` available |

### System Libraries

- `libsqlite3` — present (required by cozo-ce storage-sqlite)
- `libssl3` — present (OpenSSL 3.0.13)
- No RocksDB (not needed — we use sqlite backend)

### Missing (Not Installed)

| Tool | Status | Installable? |
|---|---|---|
| **Nix** | Not installed, `/nix` dir creatable | Yes — single-user install likely works (root, no systemd required for single-user) |
| **jj (Jujutsu)** | Not installed | Yes — `cargo install jj-cli` (v0.39.0 available, ~5min compile) |
| **gh (GitHub CLI)** | Not installed | Yes — via apt or binary download |
| **Docker daemon** | Client present, no daemon | No — Firecracker doesn't run nested virtualization; socket missing |

## 3. Network

- **Outbound HTTPS**: Working (proxied through 21.0.0.89:15004)
- **GitHub API**: Accessible (public repos clone fine)
- **crates.io**: Accessible (cargo fetches/builds work)
- **nixos.org cache**: Accessible
- **ICMP (ping)**: Not available (binary missing)
- **Private repos**: Not accessible without auth token (samskara repo returns 404 — it's private)

## 4. Repo Accessibility

| Repo | Public? | Cloneable? |
|---|---|---|
| `LiGoldragon/Mentci` | Yes | Already present at /home/user/Mentci |
| `LiGoldragon/criome-cozo` | Yes | Cloned and builds successfully |
| `LiGoldragon/samskara-lojix-contract` | Yes | Cloned and builds successfully |
| `LiGoldragon/samskara` | **Private** | Cannot clone without auth token |
| `LiGoldragon/lojix` | Empty | Clones but empty; `sajban/lojix` also clones but empty |

## 5. What Was Proven Working

A test binary was built and executed that demonstrates:

1. **CozoDB in-memory**: Opens, `is_live = true`
2. **Contract relations**: `samskara_lojix_contract::init()` creates `transpiler_version`, `eval_request`, `eval_result`
3. **World-init schema**: All 20 relations from `Core/samskara-world-init.cozo` created successfully:
   - Knowledge layer: `thought`, `thought_link`, `thought_tag`, `trust_review`
   - Agent layer: `agent`, `agent_session`
   - World layer: `repo`, `repo_state`, `principle`, `liveness_vocab`
   - VCS layer: `world_commit`, `world_manifest`, `world_delta`, `world_snapshot`, `world_snapshot_index`, `world_commit_ref`
   - Archive layer: `archive_reader_version`
4. **Seed data**: Agents, repos, and principles inserted and queried via Datalog
5. **SQLite persistence**: `CriomeDb::open_sqlite()` works at `/tmp/test-samskara.db`
6. **Full Rust compilation**: cozo-ce v0.7.13-alpha.3 with storage-sqlite compiles in ~65s

## 6. What It Takes to Run Samskara in This Harness

### Blockers

1. **`samskara` repo is private** — the repo at `LiGoldragon/samskara` returns HTTP 404 (requires auth). Without access, the actual samskara binary cannot be cloned or built here.

2. **No `jj` installed** — the project mandates Jujutsu for VCS. The `samskara` crate's jj-mirror module depends on shelling out to `jj` for commit/diff operations. Fixable: `cargo install jj-cli` (~5 min compile).

3. **No Nix** — the canonical build path (`nix flake check`) doesn't work. Fixable: single-user Nix install, then `nix develop` to get the full dev shell.

### What Works Today (Without Blockers)

Even without the samskara binary, this sandbox **can** run the Samskara database layer right now:

- `criome-cozo` compiles and works (in-memory and SQLite)
- `samskara-lojix-contract` compiles and initializes
- The full `samskara-world-init.cozo` schema loads and accepts data
- The `samskara-world-seed.cozo` seed data can be loaded
- Datalog queries against all relations work correctly

This means **a Claude Code agent session can act as the Samskara agent** by:
1. Opening a CozoDB instance (memory or SQLite-backed)
2. Loading the contract + world-init schemas
3. Seeding it with ecosystem data
4. Running Datalog queries to reason about relations
5. Writing results to contract surface relations

### Concrete Path to Full Agent Loop

| Step | Effort | Dependency |
|---|---|---|
| 1. Install `jj-cli` via cargo | ~5 min | None |
| 2. Install Nix (single-user) | ~5 min | None |
| 3. Get auth token for private repos | User action | GitHub PAT or deploy key |
| 4. Clone + build `samskara` | ~3 min | Steps 1-3 |
| 5. Run `samskara` CLI (opens DB, loads schemas) | Immediate | Step 4 |
| 6. Implement agent loop (read contract → reason → write contract) | Design work | Step 5 |
| 7. Build + run `lojix` (currently stubs) | Future | lojix repo needs content |

### Alternative: Agent-in-Session (No Binary Required)

The most pragmatic path for this sandbox is to **skip building the samskara binary** and instead have Claude Code itself act as the Samskara reasoning layer:

1. The sandbox test already proved we can open CozoDB, load all schemas, and seed data
2. Claude Code can write Rust code that performs the Datalog queries Samskara would make
3. The contract relations (`eval_request`, `eval_result`, `transpiler_version`) are initialized and ready
4. The world model relations (thoughts, principles, repos, agents) accept and return data

This "agent-in-session" approach treats the Claude Code session as the Samskara process — it reasons in natural language but stores/retrieves all state as Datalog relations in CozoDB. The DB is the ground truth; the agent is the reasoner.

## 7. Session Limitations

| Limitation | Impact |
|---|---|
| **Ephemeral** — VM state lost on session end | SQLite DBs in /tmp won't persist. Would need to serialize world state to a commit before session ends. |
| **No Docker daemon** | Can't run containerized services (irrelevant for this architecture). |
| **Private repo access** | Samskara and possibly future repos need GitHub auth. |
| **No systemd** | Long-running services must be background processes, not systemd units. |
| **Proxy-filtered network** | Some endpoints may be blocked; GitHub and crates.io work. |
