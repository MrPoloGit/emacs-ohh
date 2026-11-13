;;; ohh-ts-mode.el --- Tree-sitter major mode for OHH hand histories -*- lexical-binding: t; -*-

;; Package-Requires: ((emacs "29.1"))

;;; Commentary:

;; Emacs support for OHH (.ohh), built after VS Code, Neovim, Vim and Zed
;; already existed for this language, the same editor-parity discipline
;; as emacs-phh/phh-ts-mode.el: the
;; tree-sitter-ohh grammar (copied verbatim from nvim-ohh/parser/ohh.so,
;; renamed to Emacs's own `libtree-sitter-LANG.<ext>' convention, same
;; confirmed-identical-dylib provenance as emacs-phh's) for highlighting,
;; and ohh-ls over `eglot' for diagnostics/hover/completion. No injected
;; sub-grammar here, unlike PHH's action-notation strings, OHH has
;; nothing embedded inside a string that needs its own parser.
;;
;; Capture names are rewritten from tree-sitter-ohh/queries/highlights.scm's
;; generic names to Emacs's own `font-lock-*-face' names, see
;; emacs-phh/phh-ts-mode.el's commentary for why that's not a mechanical
;; sync and is instead checked by hand against the real grammar
;; (test/ohh-ts-mode-tests.el).

;;; Code:

(require 'treesit)
(require 'eglot)

(defgroup ohh nil
  "Major mode for OHH poker hand histories."
  :group 'languages)

(defcustom ohh-ts-mode-server-program "ohh-ls"
  "Path to the ohh-ls executable."
  :type 'string
  :group 'ohh)

(defcustom ohh-ts-mode-registry-path nil
  "Path to the ohh/registry directory.

ohh-ls has no built-in default for this, same \"never approximate
silently\" reasoning as `phh-ts-mode-registry-path'. You must set this
before `ohh-ts-mode' will start the language server."
  :type '(choice (const nil) string)
  :group 'ohh)

;; See emacs-phh/phh-ts-mode.el's `phh-ts-mode--source-directory' comment
;; for why this is captured once, here, at top level, instead of read
;; lazily from inside a function.
(defconst ohh-ts-mode--source-directory
  (file-name-directory (or load-file-name buffer-file-name))
  "Directory this file was loaded from.")

;;;###autoload
(defun ohh-ts-mode-register-grammar ()
  "Add this package's bundled grammar to `treesit-extra-load-path'.

Only a macOS arm64 binary is bundled (same single-platform caveat as
nvim-ohh/README.md's parser/ohh.so). On another platform, rebuild
tree-sitter-ohh and point `treesit-extra-load-path' at the result."
  (add-to-list 'treesit-extra-load-path
               (expand-file-name "parser" ohh-ts-mode--source-directory)))

(defvar ohh-ts-mode--font-lock-rules
  (treesit-font-lock-rules
   :language 'ohh
   :feature 'key
   '((pair key: (string) @font-lock-property-name-face))

   :language 'ohh
   :feature 'string
   '((string) @font-lock-string-face
     (escape_sequence) @font-lock-escape-face)

   :language 'ohh
   :feature 'constant
   '((number) @font-lock-number-face
     (true) @font-lock-constant-face
     (false) @font-lock-constant-face
     (null) @font-lock-constant-face)

   ;; OHH-specific: the four well-known enum-valued keys get a distinct
   ;; face on their VALUE, text-matched the same way tree-sitter-ohh's
   ;; own highlights.scm does .
   ;; `:match' (a regexp), not `:any-of?', `:any-of?' compiles in the
   ;; string query syntax but is silently refused in this sexp form on
   ;; this Emacs build (treesit-font-lock-rules-mismatch, feature
   ;; disabled entirely); confirmed by testing, not assumed.
   :language 'ohh
   :feature 'ohh-specific
   :override t
   '(((pair key: (string) @_key value: (string) @font-lock-type-face)
      (:match "\"\\(game_type\\|bet_type\\|street\\|action\\)\"" @_key)))

   :language 'ohh
   :feature 'punctuation
   '("{" @font-lock-bracket-face
     "}" @font-lock-bracket-face
     "[" @font-lock-bracket-face
     "]" @font-lock-bracket-face
     ":" @font-lock-operator-face
     "," @font-lock-delimiter-face))
  "Font-lock rules for `ohh-ts-mode'.")

(defun ohh-ts-mode--imenu-key-name (node)
  "Return a top-level `pair' NODE's key text (quotes stripped), for Imenu."
  (string-trim (treesit-node-text (treesit-node-child-by-field-name node "key") t)
               "\"" "\""))

(defun ohh-ts-mode--imenu-top-level-pair-p (node)
  "Non-nil if NODE is a `pair' directly inside the top-level `{\"ohh\": ...}' object.

Keeps Imenu to one entry per hand field (spec_version, players,
rounds, pots, ...) instead of every nested pair in the whole document
(player names, action amounts, ...), which would be noise, not an
outline."
  (let ((object (treesit-node-parent node)))
    (and object
         (equal (treesit-node-type (treesit-node-parent object)) "pair")
         (equal (ohh-ts-mode--imenu-key-name (treesit-node-parent object)) "ohh"))))

(defvar ohh-ts-mode--imenu-settings
  `(("Field" ,(rx bos "pair" eos) ohh-ts-mode--imenu-top-level-pair-p ohh-ts-mode--imenu-key-name))
  "Imenu entries: one per field of the hand object (not every nested pair).")

;;;###autoload
(define-derived-mode ohh-ts-mode prog-mode "OHH"
  "Major mode for OHH (.ohh) poker hand histories."
  :group 'ohh
  (ohh-ts-mode-register-grammar)
  (when (treesit-ready-p 'ohh)
    (setq-local treesit-primary-parser (treesit-parser-create 'ohh))
    (setq-local treesit-font-lock-settings ohh-ts-mode--font-lock-rules)
    (setq-local treesit-font-lock-feature-list
                '((key string)
                  (constant ohh-specific)
                  (punctuation)
                  ()))
    (setq-local treesit-simple-imenu-settings ohh-ts-mode--imenu-settings)
    (treesit-major-mode-setup)))

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.ohh\\'" . ohh-ts-mode))

(defun ohh-ts-mode--eglot-contact (_interactive _project)
  "Build ohh-ls's eglot CONTACT; see `phh-ts-mode--eglot-contact' for why
this is a function rather than a static list."
  (unless ohh-ts-mode-registry-path
    (user-error "ohh-ts-mode: set `ohh-ts-mode-registry-path' before starting eglot"))
  (list ohh-ts-mode-server-program ohh-ts-mode-registry-path))

(with-eval-after-load 'eglot
  (add-to-list 'eglot-server-programs
               '(ohh-ts-mode . ohh-ts-mode--eglot-contact)))

(provide 'ohh-ts-mode)
;;; ohh-ts-mode.el ends here
