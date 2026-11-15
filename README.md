# emacs-ohh

Emacs support for OHH (`.ohh`), uses
`tree-sitter-ohh`'s compiled grammar and `ohh-ls`.

## Install

```elisp
(add-to-list 'load-path "/path/to/emacs-ohh")
(require 'ohh-ts-mode)
(setq ohh-ts-mode-registry-path "/path/to/ohh-data/registry") ; required, no default
```

**Not published to MELPA (or any other package archive).** This repo
is pushed to `github.com/MrPoloGit/emacs-ohh`, usable today via
`straight.el`/`use-package :vc`/`package-vc-install` pointing at that
URL, or the manual `load-path` above, but it hasn't been submitted to
MELPA, nothing has an MELPA recipe yet.
