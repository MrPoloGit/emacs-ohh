# emacs-ohh

Emacs support for OHH (`.ohh`), built after VS Code, Neovim, Vim and Zed
already existed for this language, the same editor-parity goal
`emacs-phh/README.md` describes. Reuses
`tree-sitter-ohh`'s compiled grammar and `ohh-ls` over `eglot`, same
split as every other editor package in this project.

## Install

```elisp
(add-to-list 'load-path "/path/to/emacs-ohh")
(require 'ohh-ts-mode)
(setq ohh-ts-mode-registry-path "/path/to/ohh/registry") ; required, no default
```

## What's implemented (L0, highlighting)

- `.ohh` → `ohh-ts-mode` via `auto-mode-alist`.
- Highlighting ported from `tree-sitter-ohh/queries/highlights.scm`
  (same by-hand capture-name rewrite discipline `emacs-phh` uses). No
  injected sub-grammar here, unlike PHH's action strings, nothing
  inside an OHH string needs its own parser.
- The four well-known enum-valued keys (`game_type`, `bet_type`,
  `street`, `action`) get their value highlighted distinctly from a
  plain string, text-matched the same way `highlights.scm` does, using
  `:match` with a regexp, **not** `:any-of?`: the latter is valid in
  tree-sitter's *string* query syntax but silently disabled this whole
  feature in Emacs's *sexp* query form on this Emacs build
  (`treesit-font-lock-rules-mismatch`), confirmed by testing, not
  assumed either way, `:match` is what actually works here.
- **Imenu** lists one entry per top-level field of the hand object
  (`spec_version`, `players`, `rounds`, `pots`, ...), not every nested
  pair in the document, a player's own `name` field, for example,
  correctly does *not* show up. This needed an explicit predicate
  (`ohh-ts-mode--imenu-top-level-pair-p`); the obvious "match every
  `pair` node" rule would have buried the real outline in noise.

**Grammar binary is bundled**, macOS arm64 only, `parser/libtree-sitter-ohh.dylib` is the exact same compiled dylib
`nvim-ohh/parser/ohh.so` ships, renamed to Emacs's convention and
re-confirmed to load under `treesit`. Rebuild `tree-sitter-ohh` for
another platform.

## What's implemented (L1, diagnostics, hover, completion)

Same function-contact `eglot-server-programs` entry pattern as
`emacs-phh`, see that README's L1 section for the full reasoning
(loud failure on an unset registry path, dynamic re-read of the
customizable variable). **Not independently confirmed**: a live
interactive `eglot` handshake; everything here was tested in
`emacs -Q --batch`.

## How this was verified

`test/ohh-ts-mode-tests.el` (ERT) checks real faces at real corpus
positions (`holdem-cash-pokerstars.ohh`), the Imenu top-level-only
filter, and that a run-it-twice hand (`run-it-twice.ohh`, two
Flop/Turn/River rounds sharing street names, `ohh/registry/enums.json`'s
own documented edge case) still parses and produces a non-empty index
rather than erroring. **All 7 checks pass.** Byte-compiles with zero
warnings.
