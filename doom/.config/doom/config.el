;;; ~/.config/doom/config.el -*- lexical-binding: t; -*-

(load! "lisp/org-config")
(load! "lisp/cardflow")
(load! "lisp/org-typst-preview")
;;
(setq user-full-name "Fabio Rodrigues"
      user-mail-address "fabio.rod@outlook.pt")
;;
(setq doom-font (font-spec :family "JetBrains Mono" :size 16)
      doom-variable-pitch-font (font-spec :family "JetBrains Mono" :size 16))

;; ~/.doom.d/config.el
(after! company
  (setq company-idle-delay 0.0          ; sem delay (default 0.2)
        company-minimum-prefix-length 1 ; 1 letra (default 3)
        company-tooltip-idle-delay 0.0))
(custom-set-faces!
  '(company-tooltip :family "JetBrains Mono" :height 110)
  '(company-tooltip-selection :background "#44475a")
  '(company-tooltip-common :weight bold)
  '(company-tooltip-annotation :slant italic))


;; If you or Emacs can't find your font, use 'M-x describe-font' to look them
;; up, `M-x eval-region' to execute elisp code, and 'M-x doom/reload-font' to
;; refresh your font settings. If Emacs still can't find your font, it likely
;; wasn't installed correctly. Font issues are rarely Doom issues!
(add-to-list 'custom-theme-load-path (expand-file-name "themes/" doom-user-dir))
(setq doom-theme 'hex-lavender-dark)
(add-to-list 'default-frame-alist '(undecorated . t))
(add-to-list 'default-frame-alist '(fullscreen . maximized))
(add-hook 'pdf-view-mode-hook #'pdf-view-roll-minor-mode)
(add-hook 'pdf-view-mode-hook (lambda () (display-line-numbers-mode -1)))

;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type t)

(setq shell-file-name (executable-find "bash"))

(setq-default vterm-shell "/usr/bin/fish")
(setq-default explicit-shell-file-name "/usr/bin/fish")

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

(setq gc-cons-threshold (* 256 1024 1024))
(setq read-process-output-max (* 4 1024 1024))
(setq comp-deferred-compilation t)
(setq comp-async-jobs-number 8)

;; Garbage collector optimization
(setq gcmh-idle-delay 5)
(setq gcmh-high-cons-threshold (* 1024 1024 1024))

;; Version control optimization
(setq vc-handled-backends '(Git))

;; Fix x11 issues
(setq x-no-window-manager t)
(setq frame-inhibit-implied-resize t)
(setq focus-follows-mouse nil)
