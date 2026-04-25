# Tree-sitter grammars for nota and nexus — research and proposed layout

Date: 2026-04-25
Author: agent (research) for Li

## Question

How should we set up tree-sitter syntax highlighting for **nota** and **nexus** so that all three target editors (emacs / vscodium / vim+neovim) get *as elaborate* a colorisation as `tree-sitter-aski` (the existing reference inside `~/git/aski/`)? Specifically: one central grammar repo + per-editor repos, or a monorepo? And how does VSCode (which has never natively supported tree-sitter) actually deliver the highlighting?

## Findings — how the existing aski setup works

### 1. Central grammar — [`~/git/aski/tree-sitter-aski/`](../../aski/tree-sitter-aski/)

Lives **inside** the `aski` repo as a subdirectory (not a separate sibling repo — this is an aski quirk; see proposal §1 below). Contents:

- `grammar.js` (≈14 KB) defines the syntax.
- `queries/highlights.scm` — **28 distinct `@capture` names**, hierarchically organised: `@type.definition`, `@function.method.call`, `@variable.parameter`, `@module.definition`, etc. — well beyond the standard `@function`/`@keyword`/`@variable` minimum.
- `queries/locals.scm` (variable scoping) and `queries/indents.scm` (indent rules).
- `package.json` declares `scope: "source.aski"` and lists the query files.
- Both a native `.so` (compiled C parser via `tree-sitter generate && cc`) and a `.wasm` (compiled with `wasm32-unknown-wasi-cc` + binaryen) are produced. Native is for emacs/neovim; WASM is for VSCode/web.

Nix packaging in [`flake.nix`](../../aski/flake.nix) exposes both as derivations (`tree-sitter-aski`, `tree-sitter-aski-wasm`).

### 2. Emacs — [`aski-ts-mode.el`](../../aski/aski-ts-mode.el) (≈290 lines)

Defines `aski-ts-mode--font-lock-settings` via `treesit-font-lock-rules`. The "elaborate colours" trick on the emacs side: **map each capture to a distinct standard `font-lock-*` face**. Emacs' face palette is surprisingly rich — `font-lock-comment-face`, `font-lock-preprocessor-face`, `font-lock-property-name-face`, `font-lock-operator-face`, `font-lock-constant-face`, `font-lock-variable-name-face`, `font-lock-function-name-face`, `font-lock-builtin-face`, etc. The mode partitions captures into ≈12 font-lock features (comment / string / number / constant / keyword / type / definition / builtin / function / property / variable / operator / punctuation), so users can pick their level via `treesit-font-lock-level` (1–4).

No custom faces required — the existing emacs face inventory is enough for "more colours than default". Custom faces are an option for further differentiation but unnecessary as a starting point.

### 3. VSCode — [`~/git/vscode-aski/`](../../vscode-aski/) (≈480 lines TS)

This is where the interesting work is. **VSCode still does not natively support tree-sitter** for syntax highlighting (Microsoft issue #50140, open since 2017; no progress as of 2026). vscode-aski reaches the same "elaborate" result through the **Semantic Token API**, in this exact pipeline:

1. Bundles `tree-sitter-aski.wasm` in `grammars/` and depends on `web-tree-sitter` (v0.26.x) in `package.json`.
2. On activation: loads the WASM grammar via `web-tree-sitter`, parses the document, runs `queries/highlights.scm` (a **copy** of the central one — kept in sync at extension build time).
3. Registers a `DocumentSemanticTokensProvider` and emits semantic tokens. A `CAPTURE_MAP` (extension.ts ~lines 47–118) translates `@type.definition` → `[tokenTypeIndex, modifierBitmask]`, with **hierarchical fallback**: `@type.definition` → `@type` → null. This means highlights.scm can be as elaborate as you want without breaking when a capture isn't mapped.
4. `package.json`'s `contributes.semanticTokenColorCustomizations` defines colours scoped per-language (`"type:aski": "#f5c000"`, `"function:aski": "#60a0f0"`, …). Each capture path gets a colour and that's what produces the "more colours than default" appearance.

A trivial TextMate `.tmLanguage.json` is included as a fallback for bracket matching only — no colourisation work is done by it.

### 4. Neovim

Built-in tree-sitter (Neovim ≥0.11, also via `nvim-treesitter`). Auto-discovers `queries/<lang>/highlights.scm` from the parser's directory; capture names map directly to `@function`/`@type`/etc. highlight groups, with the same hierarchical fallback. To distribute: ship the `.so` parser + `queries/` and either drop into runtimepath manually or land an entry in `nvim-treesitter`'s registry.

## Findings — canonical pattern across the ecosystem

**One `tree-sitter-X` repo per language is the unambiguous canon.** Examples: `tree-sitter/tree-sitter-rust`, `tree-sitter/tree-sitter-typescript` (single repo carries TS + TSX, but only because they share grammar machinery), `tree-sitter-grammars/tree-sitter-zig`, `nix-community/tree-sitter-nix`. Editor integration always lives in separate per-editor repos / extensions / plugins.

**The aski model — grammar-as-subdir-of-language-repo — is the outlier**, and not what the broader ecosystem does. It works because aski is a single-repo project; for our multi-repo sema-ecosystem it would be a step backward.

**Elaborate highlighting is not a tree-sitter feature**; it is the consequence of (a) defining many hierarchical capture names in `highlights.scm`, and (b) each editor's mapping layer translating those captures into that editor's native colour scheme. The naming convention (e.g. `@function.builtin.constructor`) is documented at <https://tree-sitter.github.io/tree-sitter/3-syntax-highlighting.html> but **not enforced** — you can invent any capture path you want, as long as the editor mapping handles it (with sensible fallback).

## Recommendation

Two new sibling repos, following sema-ecosystem conventions (one repo per concern, lowercase-hyphenated, cloned under `~/git/`, symlinked into `mentci/repos/`, listed in `docs/workspace-manifest.md`):

### Grammar repos — separate

- `~/git/tree-sitter-nota/`
- `~/git/tree-sitter-nexus/`

Each contains: `grammar.js`, `src/` (generated), `queries/highlights.scm` + `locals.scm` + `indents.scm`, `package.json` (`scope: "source.nota"` / `"source.nexus"`), `flake.nix` exposing native `.so` and `.wasm` derivations. Standard `AGENTS.md` + one-line `CLAUDE.md` shim.

Reasons for two repos rather than one combined `sema-tree-sitter`:
- Matches universal convention; downstream tooling (nvim-treesitter registry, helix-editor's grammar config, package managers) all expect `tree-sitter-<lang>` naming and one grammar per repo.
- The two languages will evolve at different speeds and need different release cadences.
- Nix flake outputs stay clean (one package per repo).

### Per-editor integration

- **Emacs**: a single `~/git/sema-emacs/` repo with `nota-ts-mode.el` and `nexus-ts-mode.el` (and room for future sema-language modes). Single ELPA-able package, both modes pull from the standard emacs face palette — aim for **15+ distinct faces** per language across the ≈12 treesit features. (If `~/git/CriomOS-emacs/` is the intended home for editor configuration, slot the modes there instead — a judgement call when we get there.)
- **VSCode/VSCodium**: a single `~/git/vscode-sema/` extension supporting both languages — same `extension.ts` skeleton vscode-aski uses (Parser + Language from WASM, query the tree, emit semantic tokens), with a per-language `CAPTURE_MAP` and a single `semanticTokenColorCustomizations` block scoping colours per language (`"type:nota"`, `"type:nexus"`, …). One extension is simpler than two: shared activation code, one install for users, one place to keep theme palettes coherent across the two sister languages.
- **Neovim**: no new repo needed initially. Ship `.so` + `queries/` from the grammar repos; add `~/.config/nvim` entries (or eventually upstream into `nvim-treesitter`'s parser registry).

### Elaborateness target

- **Captures**: aim for ≥30 hierarchical captures in each `highlights.scm` (aski has 28; we should at least match).
- **Emacs**: ≥15 distinct font-lock faces per language across treesit features.
- **VSCode**: ≥20 semantic-token-type × modifier combinations with distinct colours in the extension's default theme contribution.
- **Neovim**: same `highlights.scm` as the canonical source; user can override via `:hi link @nota.…` if desired.

### Workspace integration

- Add `tree-sitter-nota`, `tree-sitter-nexus`, `vscode-sema` (and `sema-emacs` if going that route) to `docs/workspace-manifest.md` as CANON entries.
- Mirror in `devshell.nix`'s `linkedRepos` so the symlinks land in `repos/` automatically.
- Standard `AGENTS.md` + `CLAUDE.md` shim in each.

## Open questions for Li

1. Should `vscode-sema` be one extension or two (`vscode-nota` + `vscode-nexus`)? Recommendation above is one — confirm or override.
2. Is the emacs side a new `sema-emacs` repo or should the modes go into `CriomOS-emacs`?
3. Approximate timing — do we want `tree-sitter-nota` first (likely simpler, more stable syntax) and `tree-sitter-nexus` after, or both in parallel?

## Sources

- [tree-sitter syntax highlighting docs](https://tree-sitter.github.io/tree-sitter/3-syntax-highlighting.html)
- [vscode issue #50140 — tree-sitter support (open since 2017)](https://github.com/microsoft/vscode/issues/50140)
- Existing local references: [`~/git/aski/tree-sitter-aski/`](../../aski/tree-sitter-aski/), [`~/git/aski/aski-ts-mode.el`](../../aski/aski-ts-mode.el), [`~/git/vscode-aski/`](../../vscode-aski/)
