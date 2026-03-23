# Samskara DB Access Test — Claude Cloud Environment

Date: 2026-03-23

## Result: Not Accessible

The samskara database (world.db) cannot be read in the Claude Cloud
(web sandbox) environment.

## Findings

| Check                              | Status                                          |
|------------------------------------|-------------------------------------------------|
| `world.db` on disk                 | Not found anywhere on filesystem                |
| `samskara-mcp` binary              | Not installed / not on PATH                     |
| MCP servers in `.mcp.json`         | Declared but binaries absent                    |
| Nix toolchain                      | Not available (no `/nix` store)                 |
| CozoDB CLI                         | Not available                                   |

## Explanation

`.mcp.json` declares three MCP servers (`samskara-mcp`, `criome-stored-mcp`,
`annas-archive-mcp`), all Nix-built Rust binaries. The Claude Cloud sandbox
does not have Nix installed, so the dev shell cannot be entered and the MCP
servers cannot be built or run. The `world.db` file itself lives in the
samskara micro-repo, which is not vendored into this aggregator repo.

## Available Fallbacks

- Static graph exports: `samskara-world.{svg,png,dot}`, `samskara-relations.{svg,dot}`
- Core/*.md projection files (may drift from DB truth)
