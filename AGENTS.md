# Agent instructions — mentci

You **MUST** read AGENTS.md at `github:ligoldragon/lore` — the
workspace contract. The rules below are mentci-specific
carve-outs only.

## Repo role

This repo is the **dev environment + meta-deploy aggregator**.
The project being built is **criome** (the engine).

mentci hosts:
- [`docs/workspace-manifest.md`](docs/workspace-manifest.md) —
  every repo under `~/git/` with its CANON / TRANSITIONAL /
  SHELVED status. `devshell.nix`'s `linkedRepos` mirrors the
  CANON + TRANSITIONAL entries.
- [`reports/`](reports/) — decision records and design syntheses.
- The `repos/` symlink directory created on `nix develop` /
  direnv entry, exposing every workspace repo as a sibling for
  cross-repo reading + editing.

For implementation detail of mentci itself: see
[`ARCHITECTURE.md`](ARCHITECTURE.md) at this repo's root.

---

## Reports — hygiene

When a frame has been **decisively rejected** (criome
ARCHITECTURE.md §10 "Rejected framings", a bd memory, or a chat
correction): do not re-present it as a candidate in subsequent
reports just to refute it. State only the correct frame.

When a previous report's premise is **wrong**: delete it and
write a clean successor that states only the correct view. Do
not append corrections, do not banner, do not restate-to-refute.

The rejected-framings list in
[criome/ARCHITECTURE.md §10](https://github.com/LiGoldragon/criome/blob/main/ARCHITECTURE.md)
is the *only* place wrong frames are named, and only as one-line
entries. Forensic narratives ("here's how this contamination
crept in") are not reports — their lessons land in §10 as
one-liners and in bd memories; the forensic narrative itself
goes too.

---

## Reports — rollover at the soft cap

**Soft cap: ~12 active reports** in [`reports/`](reports/). When
the count exceeds this, run a rollover pass before adding the
next report. For each existing report, decide one of:

1. **Roll into a new consolidated report.** Multiple reports
   covering the same evolving thread fold into a single
   forward-pointing successor. The successor supersedes the old
   reports; the old ones are deleted (no banner).
2. **Implement.** If the report's substance can be expressed as
   architecture (criome's ARCHITECTURE.md, a per-repo
   ARCHITECTURE.md, skeleton-as-design code, or an AGENTS.md
   rule), move it to the right home and delete the report.
3. **Delete.** If the report's content is already absorbed
   elsewhere or its premise has been refuted, delete it.

The choice is made by reading each report against the author's
intent — no mechanical rule. When unclear, ask Li.

The cap is **soft** in that it triggers a rollover pass, not an
instant rejection; it is **firm** in that the pass must run
before the next new report lands. Default to deletion; extract
only when the rationale has no other home.
