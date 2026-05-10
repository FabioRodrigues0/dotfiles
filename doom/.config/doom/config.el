;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file!
(setq org-directory "~/org/")
(map! :leader
      :desc "Org Capture"
      "x" #'org-capture)
(after! org
  (setq org-agenda-files '("~/org/inbox.org"
                           "~/org/tarefas.org"
                           "~/org/habitos.org"
                           "~/org/agenda.org"))

  ;; Estados de uma tarefa
  (setq org-todo-keywords
        '((sequence "TODO(t)" "EM CURSO(e)" "À ESPERA(a)" "|" "FEITO(f)" "CANCELADO(c)")))

  ;; Captura rápida (SPC X no Doom)
  (setq org-capture-templates
        '(("t" "Tarefa" entry (file "~/org/inbox.org")
           "* TODO %?\n  %U\n")
          ("e" "Evento" entry (file "~/org/agenda.org")
           "* %?\n  %^T\n")
          ("n" "Nota rápida" entry (file "~/org/inbox.org")
           "* %?\n  %U\n")))

  (setq org-agenda-span 'week
        org-agenda-start-on-weekday 1  ;; começa na segunda
        org-agenda-time-grid
        '((daily weekly today require-timed)
          (800 1000 1200 1400 1600 1800 2000)
          "......" "----------------")))



;; Some functionality uses this to identify you, e.g. GPG configuration, email
;; clients, file templates and snippets. It is optional.
;; (setq user-full-name "John Doe"
;;       user-mail-address "john@doe.com")

;; Doom exposes five (optional) variables for controlling fonts in Doom:
;;
;; - `doom-font' -- the primary font to use
;; - `doom-variable-pitch-font' -- a non-monospace font (where applicable)
;; - `doom-big-font' -- used for `doom-big-font-mode'; use this for
;;   presentations or streaming.
;; - `doom-symbol-font' -- for symbols
;; - `doom-serif-font' -- for the `fixed-pitch-serif' face
;;
;; See 'C-h v doom-font' for documentation and more examples of what they
;; accept. For example:
;;
(setq doom-font (font-spec :family "JetBrains Mono" :size 16)
      doom-variable-pitch-font (font-spec :family "JetBrains Mono" :size 16))
;;
;; If you or Emacs can't find your font, use 'M-x describe-font' to look them
;; up, `M-x eval-region' to execute elisp code, and 'M-x doom/reload-font' to
;; refresh your font settings. If Emacs still can't find your font, it likely
;; wasn't installed correctly. Font issues are rarely Doom issues!
(add-to-list 'custom-theme-load-path (expand-file-name "themes/" doom-user-dir))
(setq doom-theme 'hex-lavender-dark)
(add-to-list 'default-frame-alist '(undecorated . t))
(add-to-list 'default-frame-alist '(fullscreen . maximized))
;; There are two ways to load a theme. Both assume the theme is installed and
;; available. You can either set `doom-theme' or manually load a theme with the
;; `load-theme' function. This is the default:
;; (setq doom-theme 'hex-lavender-dark)

;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type t)

;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
(setq org-directory "~/org/")

(setq shell-file-name (executable-find "bash"))

(setq-default vterm-shell "/usr/bin/fish")
(setq-default explicit-shell-file-name "/usr/bin/fish")

;; Whenever you reconfigure a package, make sure to wrap your config in an
;; `with-eval-after-load' block, otherwise Doom's defaults may override your
;; settings. E.g.
;;
;;   (with-eval-after-load 'PACKAGE
;;     (setq x y))
;;
;; The exceptions to this rule:
;;
;;   - Setting file/directory variables (like `org-directory')
;;   - Setting variables which explicitly tell you to set them before their
;;     package is loaded (see 'C-h v VARIABLE' to look them up).
;;   - Setting doom variables (which start with 'doom-' or '+').
;;
;; Here are some additional functions/macros that will help you configure Doom.
;;
;; - `load!' for loading external *.el files relative to this one
;; - `add-load-path!' for adding directories to the `load-path', relative to
;;   this file. Emacs searches the `load-path' when you load packages with
;;   `require' or `use-package'.
;; - `map!' for binding new keys
;;
;; To get information about any of these functions/macros, move the cursor over
;; the highlighted symbol at press 'K' (non-evil users must press 'C-c c k').
;; This will open documentation for it, including demos of how they are used.
;; Alternatively, use `C-h o' to look up a symbol (functions, variables, faces,
;; etc).
;;
;; You can also try 'gd' (or 'C-c c d') to jump to their definition and see how
;; they are implemented.

;; Ativar o helix-mode (instala-se via package!)
;; Em ~/.doom.d/config.el

;; Remapeamento KLÇO em vez de HJKL
(map! :n "k" #'evil-backward-char
      :n "l" #'evil-next-line
      :n "ç" #'evil-forward-char
      :n "o" #'evil-previous-line

      ;; Nova linha abaixo/acima (antigo o/O do vim)
      :n "h" #'evil-open-below
      :n "j" #'evil-open-above

      ;; Visual mode também
      :v "k" #'evil-backward-char
      :v "l" #'evil-next-line
      :v "ç" #'evil-forward-char
      :v "o" #'evil-previous-line)

;; Recriar o teu mapeamento de setas (k, l, ç, o)
;; No Evil (Vim/Helix engine do Emacs):
;;(setq evil-vimpulse-movement-cmds '((k . left)
;;                                    (l . down)
;;                                    (ç . right)
;;                                    (o . up)))


;; Tinymist via eglot para Typst
(after! eglot
  (with-eval-after-load 'typst-ts-mode
    (add-to-list 'eglot-server-programs
                 '((typst-ts-mode) . ("tinymist")))
    (setq-default eglot-workspace-configuration
                  '(:tinymist (:exportPdf "onType")))))

(after! typst-ts-mode
  (unless (treesit-language-available-p 'typst)
    (typst-ts-utils-install-current-grammar)))

(add-hook 'typst-ts-mode-hook #'eglot-ensure)

(add-to-list 'auto-mode-alist '("\\.typ\\'" . typst-ts-mode))

(use-package websocket)
(use-package! typst-preview
  :after typst-ts-mode
  :init
  (setq typst-preview-autostart t) ; start preview automatically when typst-preview-mode is activated
  :custom
  (typst-preview-browser "default") 	; this is the default option; other options are `eaf-browser' or `xwidget'.
  (typst-preview-invert-colors "never")	; invert colors depending on system theme
  (typst-preview-executable "tinymist") ; path to tinymist binary (relative or absolute)
  (typst-preview-partial-rendering t)   ; enable partial rendering
  :config
  (map! :map typst-ts-mode-map
        :n "SPC p t" #'typst-preview-mode
        :n "SPC p r" (lambda ()
                       (interactive)
                       (let ((default-directory (file-name-directory (buffer-file-name))))
                         (compile (format "typst compile %s"
                                          (file-name-nondirectory (buffer-file-name))))))))
