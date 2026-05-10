;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Place your private configuration here! Remember, you do not need to run 'doom
(defvar meu/org-current-marker nil)
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

(after! org
  (require 'subr-x)

  (defvar meu/org-sidebar-buffer "*org-sidebar*")
  (defvar meu/org-card-buffer "*org-card*")
  (defvar meu/org-source-buffer nil)
  (defvar meu/org-sidebar-window nil)
  (defvar meu/org-card-window nil)

  ;; -----------------------------
  ;; Sidebar mode
  ;; -----------------------------

  (defvar meu/org-sidebar-mode-map (make-sparse-keymap))

  (define-derived-mode meu/org-sidebar-mode special-mode "OrgSidebar"
    "Sidebar virtual para navegar headings Org."
    (setq buffer-read-only t)
    (setq-local cursor-type nil)
    (setq-local truncate-lines t))

  ;; -----------------------------
  ;; Bounds do node
  ;; -----------------------------

  (defun meu/org-node-full-bounds ()
    "Retorna região do node atual: heading + conteúdo direto, sem filhos."
    (save-excursion
      (org-back-to-heading t)
      (let* ((start (point))
             (content-start
              (progn
                (org-end-of-meta-data t)
                (point)))
             (end
              (save-excursion
                (goto-char content-start)
                ;; parar no primeiro heading seguinte, seja filho ou irmão
                (if (re-search-forward org-heading-regexp nil t)
                    (match-beginning 0)
                  (point-max)))))
        (cons start end))))

  (defun meu/org-node-content-bounds ()
    "Retorna só conteúdo direto do node, sem heading/properties/filhos."
    (save-excursion
      (org-back-to-heading t)
      (let* ((start
              (progn
                (org-end-of-meta-data t)
                (point)))
             (end
              (save-excursion
                (goto-char start)
                (if (re-search-forward org-heading-regexp nil t)
                    (match-beginning 0)
                  (point-max)))))
        (cons start end))))

  (defun meu/org-node-snippet ()
    "Cria preview curto do conteúdo direto do node, preservando linhas."
    (let* ((bounds (meu/org-node-content-bounds))
           (raw (buffer-substring-no-properties (car bounds) (cdr bounds)))
           ;; remover drawers/properties se aparecerem
           (no-drawers
            (replace-regexp-in-string
             "^[ \t]*:PROPERTIES:\n\\(?:.*\n\\)*?[ \t]*:END:\n?"
             ""
             raw))
           ;; limpar espaços à direita
           (lines
            (mapcar #'string-trim-right
                    (split-string no-drawers "\n")))
           ;; remover linhas vazias do início/fim, mas manter as internas
           (clean-lines
            (let ((xs lines))
              (while (and xs (string-empty-p (string-trim (car xs))))
                (setq xs (cdr xs)))
              (setq xs (reverse xs))
              (while (and xs (string-empty-p (string-trim (car xs))))
                (setq xs (cdr xs)))
              (reverse xs)))
           ;; limitar número de linhas no sidebar
           (max-lines 3)
           (shown-lines (seq-take clean-lines max-lines))
           (has-more (> (length clean-lines) max-lines)))
      (if (null shown-lines)
          ""
        (concat
         (string-join shown-lines "\n")
         (when has-more "\n…")))))

  ;; -----------------------------
  ;; Card editável via indirect buffer
  ;; -----------------------------

  (defun meu/org-show-card-at-marker (marker)
    "Mostra node atual no buffer direito como indirect buffer editável."
    (let ((source (marker-buffer marker))
          (pos (marker-position marker))
          bounds)

      ;; calcular bounds no buffer original
      (with-current-buffer source
        (save-excursion
          (goto-char pos)
          (org-back-to-heading t)
          (setq bounds (meu/org-node-full-bounds))))

      ;; recriar indirect buffer
      (when (get-buffer meu/org-card-buffer)
        (kill-buffer meu/org-card-buffer))

      (with-current-buffer source
        (clone-indirect-buffer meu/org-card-buffer nil))

      (with-current-buffer meu/org-card-buffer
        (setq buffer-read-only nil)
        (widen)
        (narrow-to-region (car bounds) (cdr bounds))
        (goto-char (point-min))
        (org-mode)
        ;; esconder drawers/properties visualmente se possível
        (when (fboundp 'org-fold-hide-drawer-all)
          (org-fold-hide-drawer-all)))

      (when (window-live-p meu/org-card-window)
        (with-selected-window meu/org-card-window
          (switch-to-buffer meu/org-card-buffer)))))

  ;; -----------------------------
  ;; Render sidebar virtual
  ;; -----------------------------

  (defun meu/org-render-sidebar ()
    "Renderiza headings + preview virtual numa sidebar."
    (let ((source (or meu/org-source-buffer (current-buffer)))
          (buf (get-buffer-create meu/org-sidebar-buffer)))

      (setq meu/org-source-buffer source)

      (with-current-buffer buf
        (setq buffer-read-only nil)
        (erase-buffer)

        (setq-local truncate-lines nil)
        (setq-local word-wrap t)
        (visual-line-mode 1)

        (with-current-buffer source
          (org-map-entries
           (lambda ()
             (let* ((level (org-outline-level))
                    (title (org-get-heading t t t t))
                    (snippet (meu/org-node-snippet))
                    (indent (make-string (* 2 (1- level)) ?\s))
                    (marker (point-marker))
                    (face (intern (format "org-level-%d" (min level 8))))
                    line-start
                    line-end
                    ov)

               (with-current-buffer buf
                 (setq line-start (point))

                 ;; Só a linha do título existe mesmo no buffer
                 (insert indent)
                 (insert (propertize "● " 'face 'font-lock-keyword-face))
                 (insert (propertize title 'face face))
                 (insert "\n")

                 (setq line-end (point))

                 ;; Só o título tem marker/level
                 (put-text-property line-start line-end 'meu/org-marker marker)
                 (put-text-property line-start line-end 'meu/org-level level)

                 ;; Preview virtual: aparece, mas não é texto selecionável
                 (unless (string-empty-p snippet)
                   (setq ov (make-overlay (1- line-end) (1- line-end)))
                   (overlay-put
                    ov
                    'after-string
                    (propertize
                     (concat
                      (mapconcat
                       (lambda (line)
                         (concat indent "  " line))
                       (split-string snippet "\n")
                       "\n")
                      "\n")
                     'face 'font-lock-comment-face))))))))

        (goto-char (point-min))
        (meu/org-sidebar-mode))

      buf))

  ;; -----------------------------
  ;; Helpers sidebar
  ;; -----------------------------

  (defun meu/org-sidebar-current-marker ()
    (or (get-text-property (point) 'meu/org-marker)
        (save-excursion
          (beginning-of-line)
          (get-text-property (point) 'meu/org-marker))))

  (defun meu/org-sidebar-current-level ()
    (or (get-text-property (point) 'meu/org-level)
        (save-excursion
          (beginning-of-line)
          (get-text-property (point) 'meu/org-level))))

  (defun meu/org-sidebar-sync ()
    "Atualiza o card com o node selecionado."
    (interactive)
    (let ((marker (meu/org-sidebar-current-marker)))
      (when marker
        (setq meu/org-current-marker marker)
        (meu/org-show-card-at-marker marker))))

  ;; -----------------------------
  ;; Navegação semântica
  ;; -----------------------------

  (defun meu/org-sidebar-next-sibling ()
    "Desce para o próximo irmão."
    (interactive)
    (let ((level (meu/org-sidebar-current-level))
          found)
      (save-excursion
        (while (and (not found)
                    (= 0 (forward-line 1))
                    (not (eobp)))
          (let ((l (meu/org-sidebar-current-level)))
            (cond
             ((null l) nil)
             ((= l level) (setq found (point)))
             ((< l level) (setq found 'stop))))))
      (when (and found (not (eq found 'stop)))
        (goto-char found)
        (meu/org-sidebar-sync))))

  (defun meu/org-sidebar-prev-sibling ()
    "Sobe para o irmão anterior."
    (interactive)
    (let ((level (meu/org-sidebar-current-level))
          found)
      (save-excursion
        (while (and (not found)
                    (= 0 (forward-line -1))
                    (not (bobp)))
          (let ((l (meu/org-sidebar-current-level)))
            (cond
             ((null l) nil)
             ((= l level) (setq found (point)))
             ((< l level) (setq found 'stop))))))
      (when (and found (not (eq found 'stop)))
        (goto-char found)
        (meu/org-sidebar-sync))))

  (defun meu/org-sidebar-first-child ()
    "Entra no primeiro filho."
    (interactive)
    (let* ((level (meu/org-sidebar-current-level))
           target)
      (save-excursion
        (forward-line 1)
        (let ((l (meu/org-sidebar-current-level)))
          (when (and l (= l (1+ level)))
            (setq target (point)))))
      (when target
        (goto-char target)
        (meu/org-sidebar-sync))))

  (defun meu/org-sidebar-parent ()
    "Volta para o pai."
    (interactive)
    (let ((level (meu/org-sidebar-current-level))
          found)
      (save-excursion
        (while (and (not found)
                    (= 0 (forward-line -1))
                    (not (bobp)))
          (let ((l (meu/org-sidebar-current-level)))
            (when (and l (< l level))
              (setq found (point))))))
      (when found
        (goto-char found)
        (meu/org-sidebar-sync))))

  ;; -----------------------------
  ;; Edição
  ;; -----------------------------

  (defun meu/org-sidebar-edit ()
    "Vai para o card e entra em insert."
    (interactive)
    (when (window-live-p meu/org-card-window)
      (select-window meu/org-card-window)
      (goto-char (point-min))
      (evil-insert-state)))

  (defun meu/org-sidebar-goto-marker (marker)
    "Move cursor da sidebar para a linha correspondente ao MARKER."
    (when marker
      (goto-char (point-min))
      (let ((found nil))
        (while (and (not found) (not (eobp)))
          (let ((m (meu/org-sidebar-current-marker)))
            (when (and m (= (marker-position m)
                            (marker-position marker)))
              (setq found t)))
          (unless found
            (forward-line 1))))))

  (defun meu/org-sidebar-return ()
    "Guarda, atualiza sidebar e volta ao node que estava a ser editado."
    (interactive)
    (when (and (window-live-p meu/org-sidebar-window)
               (buffer-live-p meu/org-source-buffer))

      (with-current-buffer meu/org-source-buffer
        (save-buffer))

      (with-selected-window meu/org-sidebar-window
        (meu/org-render-sidebar)
        (switch-to-buffer meu/org-sidebar-buffer)
        (meu/org-sidebar-goto-marker meu/org-current-marker)
        (meu/org-sidebar-sync))

      (select-window meu/org-sidebar-window)))

  ;; -----------------------------
  ;; Layout
  ;; -----------------------------

  (defun meu/org-open-layout ()
    "Abre layout sidebar + card."
    (interactive)
    (delete-other-windows)

    (let ((sidebar (meu/org-render-sidebar)))
      (setq meu/org-sidebar-window (selected-window))
      (switch-to-buffer sidebar)

      (setq meu/org-card-window (split-window-right))
      (with-selected-window meu/org-card-window
        (switch-to-buffer (get-buffer-create meu/org-card-buffer)))

      (select-window meu/org-sidebar-window)
      (meu/org-sidebar-sync)))

  ;; -----------------------------
  ;; Keybinds
  ;; -----------------------------

  (evil-define-key 'normal meu/org-sidebar-mode-map
    (kbd "<down>")  #'meu/org-sidebar-next-sibling
    (kbd "<up>")    #'meu/org-sidebar-prev-sibling
    (kbd "<right>") #'meu/org-sidebar-first-child
    (kbd "<left>")  #'meu/org-sidebar-parent
    (kbd "RET")     #'meu/org-sidebar-sync
    (kbd "i")       #'meu/org-sidebar-edit)

  (evil-define-key 'normal org-mode-map
    (kbd "q")
    (lambda ()
      (interactive)
      (when (string= (buffer-name) meu/org-card-buffer)
        (meu/org-sidebar-return))))

  (defun meu/org-sidebar-return ()
    "Guarda o ficheiro original, atualiza sidebar e volta para a sidebar."
    (interactive)
    (when (and (window-live-p meu/org-sidebar-window)
               (buffer-live-p meu/org-source-buffer))

      ;; guardar o buffer real, não o indirect buffer
      (with-current-buffer meu/org-source-buffer
        (save-buffer))

      ;; atualizar sidebar sem recriar layout todo
      (let ((sidebar-window meu/org-sidebar-window))
        (with-selected-window sidebar-window
          (let ((inhibit-read-only t))
            (meu/org-render-sidebar)
            (switch-to-buffer meu/org-sidebar-buffer)
            (goto-char (point-min))))
        (select-window sidebar-window)))))
