;;; ~/.config/doom/config.el -*- lexical-binding: t; -*-

(load! "lisp/org-config")
(load! "lisp/typst-tables")
(load! "lisp/python-web")
(load! "lisp/java-csharp")
(load! "lisp/java-gerar")
(load! "lisp/novo-ficheiro")
(load! "lisp/projetos")
;;
(setq user-full-name "Fabio Rodrigues"
      user-mail-address "fabio.rod@outlook.pt")
;;
(setq doom-font (font-spec :family "JetBrains Mono" :size 16)
      doom-variable-pitch-font (font-spec :family "JetBrains Mono" :size 16))
;; Fonte de recurso para simbolos. O Symbola nao existe no brew; o Apple Symbols
;; vem com o macOS. O `doom doctor' continua a avisar porque so procura o Symbola.
(when (eq system-type 'darwin)
  (setq doom-symbol-font (font-spec :family "Apple Symbols")))

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
  (setq mac-command-modifier 'meta)
  ;; BSD ls, usado por defeito no macOS, nao suporta --dired.
  (setq dired-use-ls-dired nil))

(after! dired
  (when (eq system-type 'darwin)
    (setq dired-use-ls-dired nil)))

;; If you or Emacs can't find your font, use 'M-x describe-font' to look them
;; up, `M-x eval-region' to execute elisp code, and 'M-x doom/reload-font' to
;; refresh your font settings. If Emacs still can't find your font, it likely
;; wasn't installed correctly. Font issues are rarely Doom issues!
(add-to-list 'custom-theme-load-path (expand-file-name "themes/" doom-user-dir))
(setq doom-theme 'hex-lavender-dark)

;; Mostra cores (hex, rgb, nomes) como quadradinho colorido ao lado do código.
;; Fica fora de org/text-mode porque pode quebrar fontification em previews Org.
(defun fabio/maybe-enable-colorful-mode ()
  "Enable colorful-mode only when the package is available."
  (when (require 'colorful-mode nil t)
    (setq colorful-use-prefix t
          colorful-prefix-string "■ "
          colorful-prefix-alignment 'left)
    (colorful-mode 1)))

(add-hook 'prog-mode-hook #'fabio/maybe-enable-colorful-mode)
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
              explicit-shell-file-name fabio/fish-shell)
(setenv "SHELL" fabio/fish-shell)

(after! compile
  (add-to-list 'compilation-environment (concat "SHELL=" fabio/fish-shell)))

;; Com `:tools (lsp +eglot)`, o módulo Java do Doom não ativa LSP sozinho.
;; Arrancar o jdtls em ficheiros Java dá diagnósticos como imports em falta.
(after! eglot
  (setq eglot-connect-timeout 120
        eglot-max-file-watches 50000)
  ;; As opcoes ativam os Generate com escolha de campos (lisp/java-gerar.el).
  (add-to-list 'eglot-server-programs
               `((java-mode java-ts-mode) .
                 ("jdtls" "--jvm-arg=-Xmx4G" "--jvm-arg=-Xms512m"
                  :initializationOptions ,fabio/jdtls-init-options))))

(add-hook 'java-mode-local-vars-hook #'lsp! 'append)
(add-hook 'java-ts-mode-local-vars-hook #'lsp! 'append)

;; C#: dotnet vem do mise e o csharp-ls de `dotnet tool install --global`.
;; O Emacs de GUI nao herda o PATH do fish, e o csharp-ls precisa de DOTNET_ROOT
;; para achar o runtime (o mise instala-o em ~/.local/share/mise/dotnet-root,
;; caminho fixo independente da versao).
(let ((dotnet-tools (expand-file-name "~/.dotnet/tools")))
  (setenv "DOTNET_ROOT" (expand-file-name "~/.local/share/mise/dotnet-root"))
  (setenv "DOTNET_CLI_TELEMETRY_OPTOUT" "1")
  (add-to-list 'exec-path dotnet-tools)
  (setenv "PATH" (concat dotnet-tools ":" (getenv "PATH"))))

(after! eglot
  (add-to-list 'eglot-server-programs
               `((csharp-mode csharp-ts-mode) .
                 (,(expand-file-name "~/.dotnet/tools/csharp-ls")))))

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
  (typst-preview-cmd-options '("--verbose"))
  (typst-preview-host "")
  :config
  (defconst fabio/typst-preview-data-host "127.0.0.1:23625")
  (defconst fabio/typst-preview-control-host "127.0.0.1:23626")

  (defun fabio/typst-preview--replace-option (args option value)
    "Return ARGS with OPTION's following value replaced by VALUE."
    (cond
     ((null args) nil)
     ((and (string= (car args) option) (cdr args))
      (cons option (cons value (cddr args))))
     (t
      (cons (car args)
            (fabio/typst-preview--replace-option (cdr args) option value)))))

  (defun fabio/typst-preview--fixed-host-args (args)
    "Rewrite tinymist preview ARGS to use stable localhost ports."
    (setq args (fabio/typst-preview--replace-option args "--host" ""))
    (setq args (fabio/typst-preview--replace-option
                args "--data-plane-host" fabio/typst-preview-data-host))
    (setq args (fabio/typst-preview--replace-option
                args "--control-plane-host" fabio/typst-preview-control-host))
    args)

  (defun fabio/typst-preview-start-process-a (orig name buffer program &rest args)
    "Force stable tinymist preview ports for the typst-preview process."
    (when (string= name "typst-preview-proc")
      (setq args (fabio/typst-preview--fixed-host-args args)))
    (apply orig name buffer program args))

  (advice-remove 'start-process #'fabio/typst-preview-start-process-a)
  (advice-add 'start-process :around #'fabio/typst-preview-start-process-a)

  (defun fabio/typst-preview-find-server-filter-a (_proc input)
    "Handle tinymist 0.14 preview host log lines in INPUT."
    (when (bound-and-true-p typst-preview--local-master)
      (when (string-match
             "\\(?:Data plane\\|Static file\\) server listening on: \\([^[:space:]\n]+\\)"
             input)
        (setf (typst-preview--master-static-host typst-preview--local-master)
              (match-string 1 input)))
      (when (string-match
             "Control panel server listening on: \\([^[:space:]\n]+\\)"
             input)
        (setf (typst-preview--master-control-host typst-preview--local-master)
              (match-string 1 input)))))

  (advice-remove 'typst-preview--find-server-filter
                 #'fabio/typst-preview-find-server-filter-a)
  (advice-add 'typst-preview--find-server-filter
              :after
              #'fabio/typst-preview-find-server-filter-a)

  (defun fabio/typst-preview-clear-bad-masters-a (&rest _)
    "Clear stale typst-preview masters that were started without a preview host."
    (setq typst-preview--active-masters
          (cl-remove-if
           (lambda (master)
             (unless (typst-preview--master-static-host master)
               (when (process-live-p (typst-preview--master-process master))
                 (delete-process (typst-preview--master-process master)))
               t))
           typst-preview--active-masters))
    (when (and (boundp 'typst-preview--local-master)
               typst-preview--local-master
               (not (typst-preview--master-static-host typst-preview--local-master)))
      (kill-local-variable 'typst-preview--local-master)))

  (advice-remove 'typst-preview-start #'fabio/typst-preview-clear-bad-masters-a)
  (advice-add 'typst-preview-start
              :before
              #'fabio/typst-preview-clear-bad-masters-a)

  (defun fabio/typst-preview--url-from-hostname (hostname)
    "Return a preview URL from HOSTNAME, or nil if HOSTNAME is blank."
    (when (and (stringp hostname)
               (not (string-empty-p (string-trim hostname))))
      (let ((host (string-trim hostname)))
        (if (string-match-p "\\`https?://" host)
            host
          (concat "http://" host)))))

  (defun fabio/typst-preview--system-open-url (url)
    "Open URL with the OS browser, bypassing Emacs `browse-url' dispatch."
    (let ((program (cond
                    ((eq system-type 'darwin) "open")
                    ((executable-find "xdg-open") "xdg-open")
                    (t nil))))
      (if program
          (start-process "typst-preview-browser" nil program url)
        (browse-url url))))

  (defun fabio/typst-preview-open-url (browser hostname)
    "Open Typst preview BROWSER at HOSTNAME using the real tinymist port."
    (if-let ((url (fabio/typst-preview--url-from-hostname hostname)))
        (progn
          (message "Typst preview: %s" url)
          (pcase browser
            ("xwidget"
             (if (fboundp 'xwidget-webkit-browse-url)
                 (xwidget-webkit-browse-url url)
               (fabio/typst-preview--system-open-url url)))
            ("eaf-browser"
             (if (fboundp 'eaf-open-browser-other-window)
                 (eaf-open-browser-other-window url)
               (fabio/typst-preview--system-open-url url)))
            ("default"
             (fabio/typst-preview--system-open-url url))
            (_
             (fabio/typst-preview--system-open-url url))))
      (user-error "Typst preview ainda não devolveu uma porta; faz typst-preview-restart")))

  (defun fabio/typst-preview-xwidget-split-right (orig browser hostname)
    "Abre o typst-preview xwidget à direita em macOS, mantendo o Typst à esquerda."
    (if (and (eq system-type 'darwin)
             (string= browser "xwidget"))
        (let* ((source-window (selected-window))
               (preview-window
                (or (window-in-direction 'right source-window)
                    (split-window source-window nil 'right))))
          (select-window preview-window)
          (fabio/typst-preview-open-url browser hostname)
          (when (and (window-live-p source-window)
                     (window-live-p preview-window))
            (balance-windows-area)
            (select-window source-window)))
      (fabio/typst-preview-open-url browser hostname)))

  (advice-remove 'typst-preview--connect-browser
                 #'fabio/typst-preview-xwidget-split-right)
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
