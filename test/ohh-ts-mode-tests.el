;;; ohh-ts-mode-tests.el --- ERT tests for ohh-ts-mode -*- lexical-binding: t; -*-

;; Run with:
;;   emacs -Q --batch -L .. -l ohh-ts-mode-tests.el -f ert-run-tests-batch-and-exit

;;; Code:

(require 'ert)
(require 'ohh-ts-mode)

(defconst ohh-ts-mode-tests--dir
  (file-name-directory (or load-file-name buffer-file-name)))
(defconst ohh-ts-mode-tests--corpus-file
  (expand-file-name "../../ohh-data/corpus/valid/holdem-cash-pokerstars.ohh"
                     ohh-ts-mode-tests--dir))
(defconst ohh-ts-mode-tests--run-it-twice-file
  (expand-file-name "../../ohh-data/corpus/valid/run-it-twice.ohh" ohh-ts-mode-tests--dir))

(defmacro ohh-ts-mode-tests--with-corpus-buffer (var file &rest body)
  (declare (indent 2))
  `(let ((,var (find-file-noselect ,file)))
     (with-current-buffer ,var
       (ohh-ts-mode)
       (font-lock-ensure)
       ,@body)))

(ert-deftest ohh-ts-mode-tests-mode-active ()
  (ohh-ts-mode-tests--with-corpus-buffer buf ohh-ts-mode-tests--corpus-file
    (should (eq major-mode 'ohh-ts-mode))
    (should (treesit-parser-list))))

(ert-deftest ohh-ts-mode-tests-enum-value-gets-type-face ()
  "The `game_type' field's string value is highlighted distinctly from a
plain string value, same as `street'/`bet_type'/`action'."
  (ohh-ts-mode-tests--with-corpus-buffer buf ohh-ts-mode-tests--corpus-file
    (goto-char (point-min))
    (search-forward "\"Holdem\"")
    (backward-char 3)
    (should (eq (get-text-property (point) 'face) 'font-lock-type-face))))

(ert-deftest ohh-ts-mode-tests-plain-string-value-not-type-face ()
  "A non-enum string value (e.g. `table_name') stays plain string face,
confirming the enum rule is scoped to the four known keys, not every
string value in the document."
  (ohh-ts-mode-tests--with-corpus-buffer buf ohh-ts-mode-tests--corpus-file
    (goto-char (point-min))
    (search-forward "\"McNaught\"")
    (backward-char 5)
    (should (eq (get-text-property (point) 'face) 'font-lock-string-face))))

(ert-deftest ohh-ts-mode-tests-key-gets-property-face ()
  (ohh-ts-mode-tests--with-corpus-buffer buf ohh-ts-mode-tests--corpus-file
    (goto-char (point-min))
    (search-forward "\"spec_version\"")
    (backward-char 5)
    (should (eq (get-text-property (point) 'face) 'font-lock-property-name-face))))

(ert-deftest ohh-ts-mode-tests-number-gets-number-face ()
  (ohh-ts-mode-tests--with-corpus-buffer buf ohh-ts-mode-tests--corpus-file
    (goto-char (point-min))
    (search-forward "table_size")
    (search-forward ": ")
    (should (eq (get-text-property (point) 'face) 'font-lock-number-face))))

(ert-deftest ohh-ts-mode-tests-imenu-top-level-fields-only ()
  "Imenu lists one entry per field of the hand object, not every nested
pair (player names, action amounts, ...), this is the point of the
`ohh-ts-mode--imenu-top-level-pair-p' predicate."
  (ohh-ts-mode-tests--with-corpus-buffer buf ohh-ts-mode-tests--corpus-file
    (let ((names (mapcar #'car (cdr (assoc "Field" (funcall imenu-create-index-function))))))
      (should (member "spec_version" names))
      (should (member "players" names))
      (should (member "rounds" names))
      (should (member "pots" names))
      ;; A nested field, e.g. a player's own "name", must NOT appear.
      (should-not (member "name" names)))))

(ert-deftest ohh-ts-mode-tests-run-it-twice-file-parses-cleanly ()
  "A run-it-twice hand (two Flop/Turn/River rounds sharing street names,
ohh-data/registry/enums.json's own documented edge case) still activates
tree-sitter and produces a non-empty Imenu index, rather than erroring."
  (ohh-ts-mode-tests--with-corpus-buffer buf ohh-ts-mode-tests--run-it-twice-file
    (should (treesit-parser-list))
    (should (funcall imenu-create-index-function))))

(provide 'ohh-ts-mode-tests)
;;; ohh-ts-mode-tests.el ends here
