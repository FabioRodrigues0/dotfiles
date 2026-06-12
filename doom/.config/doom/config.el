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
        company-tooltip-idle-delay 0.0)
  (global-company-mode 1)
  (set-company-backend! '(org-mode markdown-mode typst-ts-mode)
    '(:separate company-capf company-dabbrev company-yasnippet company-files)))
(custom-set-faces!
  '(company-tooltip :family "JetBrains Mono" :height 110)
  '(company-tooltip-selection :background "#44475a")
  '(company-tooltip-common :weight bold)
  '(company-tooltip-annotation :slant italic))

;; Teclado PT-Mac: Option para caracteres especiais ({ } [ ] etc.), Command como Meta
(when (eq system-type 'darwin)
  (setq mac-option-modifier nil)
  (setq mac-command-modifier 'meta))

;; If you or Emacs can't find your font, use 'M-x describe-font' to look them
;; up, `M-x eval-region' to execute elisp code, and 'M-x doom/reload-font' to
;; refresh your font settings. If Emacs still can't find your font, it likely
;; wasn't installed correctly. Font issues are rarely Doom issues!
(add-to-list 'custom-theme-load-path (expand-file-name "themes/" doom-user-dir))
(setq doom-theme 'hex-lavender-dark)

;; Mostra cores (hex, rgb, nomes) como quadradinho colorido ao lado do código.
(use-package! colorful-mode
  :hook ((prog-mode . colorful-mode)
         (text-mode . colorful-mode))
  :config
  (setq colorful-use-prefix t          ; quadradinho em vez de pintar o texto
        colorful-prefix-string "■ "    ; o quadradinho
        colorful-prefix-alignment 'left))
(add-to-list 'default-frame-alist '(undecorated . t))
(add-to-list 'default-frame-alist '(fullscreen . maximized))
(add-hook 'pdf-view-mode-hook #'pdf-view-roll-minor-mode)
(add-hook 'pdf-view-mode-hook (lambda () (display-line-numbers-mode -1)))

;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type t)

(defvar fabio/fish-shell
  (or (executable-find "fish") "/usr/bin/fish"))

(setq shell-file-name fabio/fish-shell
      shell-command-switch "-c")
(setq-default shell-file-name fabio/fish-shell
              explicit-shell-file-name fabio/fish-shell
              vterm-shell fabio/fish-shell)
(setenv "SHELL" fabio/fish-shell)

(after! compile
  (add-to-list 'compilation-environment (concat "SHELL=" fabio/fish-shell)))

;; Com `:tools (lsp +eglot)`, o módulo Java do Doom não ativa LSP sozinho.
;; Arrancar o jdtls em ficheiros Java dá diagnósticos como imports em falta.
(after! eglot
  (setq eglot-connect-timeout 120
        eglot-max-file-watches 50000)
  (add-to-list 'eglot-server-programs
               '((java-mode java-ts-mode) .
                 ("jdtls" "--jvm-arg=-Xmx4G" "--jvm-arg=-Xms512m"))))

(add-hook 'java-mode-local-vars-hook #'lsp! 'append)
(add-hook 'java-ts-mode-local-vars-hook #'lsp! 'append)

(require 'cl-lib)

(defun fabio/gradle-project-root ()
  "Return the current Gradle project root."
  (or (locate-dominating-file default-directory "settings.gradle")
      (locate-dominating-file default-directory "settings.gradle.kts")
      (locate-dominating-file default-directory "build.gradle")
      (locate-dominating-file default-directory "build.gradle.kts")))

(defun fabio/gradle-command (root)
  "Return the Gradle command to use for ROOT."
  (let ((wrapper (expand-file-name "gradlew" root)))
    (cond ((file-exists-p wrapper) wrapper)
          ((executable-find "gradle") "gradle")
          (t (user-error "Não encontrei gradlew no projeto nem gradle no PATH")))))

(defun fabio/spotless-project-root ()
  "Return the current Gradle project root when it appears to use Spotless."
  (when-let* ((root (fabio/gradle-project-root))
              (build-file (cl-find-if #'file-exists-p
                                      (mapcar (lambda (file)
                                                (expand-file-name file root))
                                              '("build.gradle" "build.gradle.kts")))))
    (with-temp-buffer
      (insert-file-contents build-file nil 0 4096)
      (when (re-search-forward "\\bspotless\\b" nil t)
        root))))

(defun fabio/spotless-buffer-p ()
  "Return non-nil when this buffer should be formatted with Spotless."
  (and buffer-file-name
       (memq major-mode '(java-mode java-ts-mode kotlin-mode kotlin-ts-mode))
       (fabio/spotless-project-root)))

(defun fabio/spotless-apply (&optional no-save)
  "Format the current Gradle project with Spotless and reload this buffer."
  (interactive)
  (unless buffer-file-name
    (user-error "Este buffer não está associado a um ficheiro"))
  (let ((root (or (fabio/spotless-project-root)
                  (user-error "Não encontrei Spotless neste projeto Gradle")))
        (file buffer-file-name))
    (unless no-save
      (save-buffer))
    (let ((default-directory root))
      (unless (zerop (call-process (fabio/gradle-command root) nil "*spotlessApply*" t "spotlessApply"))
        (pop-to-buffer "*spotlessApply*")
        (user-error "spotlessApply falhou")))
    (when (and (buffer-file-name)
               (file-equal-p buffer-file-name file))
      (revert-buffer :ignore-auto :noconfirm :preserve-modes))
    (message "Formatado com Spotless")))

(defun fabio/spotless-apply-after-save ()
  "Run Spotless after saving Java/Kotlin files in Spotless Gradle projects."
  (when (fabio/spotless-buffer-p)
    (let ((inhibit-message t))
      (fabio/spotless-apply :no-save))))

(defun fabio/format-buffer-a (orig-fn &rest args)
  "Use Spotless instead of Doom's default formatter in Spotless projects."
  (if (fabio/spotless-buffer-p)
      (fabio/spotless-apply)
    (apply orig-fn args)))

(defun fabio/use-spotless-formatting-h ()
  "Use the project's Spotless configuration for Java/Kotlin formatting."
  (when (fabio/spotless-project-root)
    (setq-local +format-with nil)
    (add-hook 'after-save-hook #'fabio/spotless-apply-after-save nil t)))

(after! apheleia
  (advice-add #'+format/buffer :around #'fabio/format-buffer-a))

(add-hook 'java-mode-hook #'fabio/use-spotless-formatting-h)
(add-hook 'java-ts-mode-hook #'fabio/use-spotless-formatting-h)
(add-hook 'kotlin-mode-hook #'fabio/use-spotless-formatting-h)
(add-hook 'kotlin-ts-mode-hook #'fabio/use-spotless-formatting-h)

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

;; Correr `doom sync' direto do Emacs (sem ir ao terminal).
(defun fabio/doom-sync ()
  "Corre `doom sync' num buffer assíncrono."
  (interactive)
  (let* ((default-directory doom-emacs-dir)
         (doom-bin (expand-file-name "bin/doom" doom-emacs-dir)))
    (async-shell-command (format "%s sync" (shell-quote-argument doom-bin))
                         "*doom sync*")))

(map! :leader :desc "doom sync" "h r s" #'fabio/doom-sync)

;; Tinymist via eglot para Typst
(after! eglot
  (with-eval-after-load 'typst-ts-mode
    (add-to-list 'eglot-server-programs
                 '((typst-ts-mode) . ("tinymist")))
    (setq-default eglot-workspace-configuration
                  '(:tinymist (:exportPdf "onType")))))

(after! typst-ts-mode
  (unless (treesit-language-available-p 'typst)
    (if (fboundp 'typst-ts-utils-install-current-grammar)
        (typst-ts-utils-install-current-grammar)
      (treesit-install-language-grammar 'typst))))

(add-hook 'typst-ts-mode-hook #'eglot-ensure)

(add-to-list 'auto-mode-alist '("\\.typ\\'" . typst-ts-mode))

(after! typst-ts-mode
  (setq typst-ts-indent-offset 2)

  (defun fabio/typst-return-dwim (&optional arg)
    "Insert a Typst newline with predictable indentation.
Keep `typst-ts-mode' smart list behavior at end of list items, but use
`newline-and-indent' elsewhere instead of the global RET binding."
    (interactive "P")
    (let ((node (and (fboundp 'typst-ts-core-parent-util-type)
                     (fboundp 'typst-ts-core-get-parent-of-node-at-bol-nonwhite)
                     (typst-ts-core-parent-util-type
                      (typst-ts-core-get-parent-of-node-at-bol-nonwhite)
                      "item" t t))))
      (if (and (not arg)
               (bound-and-true-p typst-ts-electric-return)
               node
               (eolp)
               (fboundp 'typst-ts-editing-return))
          (typst-ts-editing-return)
        (newline-and-indent))))

  (defun fabio/typst-writing-setup-h ()
    "Make Typst buffers use two-space editing defaults."
    (setq-local tab-width 2
                evil-shift-width 2))

  (add-hook 'typst-ts-mode-hook #'fabio/typst-writing-setup-h)
  (map! :map typst-ts-mode-map
        :i "RET" #'fabio/typst-return-dwim
        :n "RET" #'fabio/typst-return-dwim))

(use-package websocket)
(use-package! typst-preview
  :after typst-ts-mode
  :init
  (setq typst-preview-autostart t) ; start preview automatically when typst-preview-mode is activated
  :custom
  (typst-preview-browser (if (eq system-type 'darwin) "xwidget" "default"))
  (typst-preview-invert-colors "never")	; invert colors depending on system theme
  (typst-preview-executable "tinymist") ; path to tinymist binary (relative or absolute)
  (typst-preview-partial-rendering t)   ; enable partial rendering
  :config
  (defun fabio/typst-preview-xwidget-split-right (orig browser hostname)
    "Abre o typst-preview xwidget à direita em macOS, mantendo o Typst à esquerda."
    (if (and (eq system-type 'darwin)
             (string= browser "xwidget"))
        (let* ((source-window (selected-window))
               (preview-window
                (or (window-in-direction 'right source-window)
                    (split-window source-window nil 'right))))
          (select-window preview-window)
          (funcall orig browser hostname)
          (when (and (window-live-p source-window)
                     (window-live-p preview-window))
            (balance-windows-area)
            (select-window source-window)))
      (funcall orig browser hostname)))

  (advice-add 'typst-preview--connect-browser
              :around
              #'fabio/typst-preview-xwidget-split-right)

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
