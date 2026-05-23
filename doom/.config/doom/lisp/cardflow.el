;;; cardflow.el -*- lexical-binding: t; -*-

(after! org
  (require 'subr-x)
  (require 'json)

  (defvar meu/org-sidebar-buffer "*org-sidebar*")
  (defvar meu/org-card-buffer "*org-card*")
  (defvar meu/org-source-buffer nil)
  (defvar meu/org-sidebar-window nil)
  (defvar meu/org-card-window nil)
  (defvar meu/org-current-marker nil)
  (defvar meu/org-current-pos nil)
  (defvar meu/org-sidebar-needs-render nil)
  (defvar meu/org-cardflow-save-guards-installed nil)

  ;; -----------------------------
  ;; Sidebar mode
  ;; -----------------------------

  (defvar meu/org-sidebar-mode-map (make-sparse-keymap))

  (defun meu/org-cardflow-virtual-buffer-p (&optional buffer)
    "Retorna non-nil se BUFFER for um buffer virtual do Cardflow."
    (member (buffer-name (or buffer (current-buffer)))
            (list meu/org-sidebar-buffer meu/org-card-buffer)))

  (defun meu/org-cardflow-refuse-virtual-save (&rest _args)
    "Impede que buffers virtuais do Cardflow sejam gravados em disco."
    (user-error "Buffer virtual do Cardflow: guarda saindo do card, não com :save nesta janela"))

  (defun meu/org-cardflow-save-guard (orig &rest args)
    "Bloqueia ORIG se o buffer atual for virtual do Cardflow."
    (if (meu/org-cardflow-virtual-buffer-p)
        (meu/org-cardflow-refuse-virtual-save)
      (apply orig args)))

  (defun meu/org-sidebar-disable-diagnostics ()
    "Remove diagnósticos e spellcheck apenas no sidebar virtual."
    (dolist (mode '(flycheck-mode
                    flymake-mode
                    flyspell-mode
                    spell-fu-mode
                    jinx-mode
                    langtool-check-mode
                    langtool-mode
                    writegood-mode))
      (when (and (fboundp mode) (bound-and-true-p mode))
        (funcall mode -1)))
    (remove-overlays (point-min) (point-max) 'flyspell-overlay t)
    (remove-overlays (point-min) (point-max) 'flycheck-overlay t)
    (remove-overlays (point-min) (point-max) 'flymake-diagnostic t)
    (remove-overlays (point-min) (point-max) 'langtool-message t)
    (remove-overlays (point-min) (point-max) 'spell-fu-overlay t)
    (remove-overlays (point-min) (point-max) 'jinx-overlay t))

  (unless meu/org-cardflow-save-guards-installed
    (advice-add 'save-buffer :around #'meu/org-cardflow-save-guard)
    (advice-add 'write-file :around #'meu/org-cardflow-save-guard)
    (advice-add 'write-region :around #'meu/org-cardflow-save-guard)
    (setq meu/org-cardflow-save-guards-installed t))

  (define-derived-mode meu/org-sidebar-mode org-mode "OrgSidebar"
    "Sidebar virtual para navegar headings Org."
    (setq buffer-read-only t)
    (setq-local buffer-file-name nil)
    (setq-local buffer-offer-save nil)
    (setq-local org-highlight-latex-and-related nil)
    (add-hook 'before-save-hook #'meu/org-cardflow-refuse-virtual-save nil t)
    (add-hook 'write-contents-functions #'meu/org-cardflow-refuse-virtual-save nil t)
    (add-hook 'write-file-functions #'meu/org-cardflow-refuse-virtual-save nil t)
    (add-hook 'write-region-annotate-functions
              #'meu/org-cardflow-refuse-virtual-save
              nil
              t)
    (setq-local cursor-type nil)
    (setq-local truncate-lines nil)
    (setq-local word-wrap t)
    (display-line-numbers-mode -1)
    (when (bound-and-true-p org-indent-mode)
      (org-indent-mode -1))
    (visual-line-mode 1)
    (evil-normalize-keymaps))

  (defun meu/org-cardflow-enable-org-rendering ()
    "Ativa a renderização base do Org no buffer atual."
    (unless (derived-mode-p 'org-mode)
      (org-mode))
    (when (string= (buffer-name) meu/org-sidebar-buffer)
      (setq-local org-highlight-latex-and-related nil)
      (meu/org-sidebar-disable-diagnostics))
    (font-lock-mode 1)
    (when (bound-and-true-p flycheck-mode)
      (flycheck-mode -1))
    (when (bound-and-true-p flymake-mode)
      (flymake-mode -1))
    (when (fboundp 'org-modern-mode)
      (org-modern-mode 1))
    (when (fboundp 'org-fold-hide-drawer-all)
      (org-fold-hide-drawer-all))
    (unless (bound-and-true-p meu/org-cardflow-fontified)
      (setq-local meu/org-cardflow-fontified t)
      (font-lock-flush (point-min) (point-max))
      (font-lock-ensure (point-min) (point-max)))
    (when (fboundp 'meu/org-typst-preview-buffer)
      (condition-case err
          (let ((meu/org-typst-preview-silent-errors
                 (string= (buffer-name) meu/org-sidebar-buffer)))
            (meu/org-typst-preview-buffer))
        (error
         (message "Cardflow Typst preview ignorado: %s" err)))))

  (defun meu/org-sidebar-indent-prefix (level &optional content)
    "Retorna indentação visual para LEVEL.
CONTENT indica que a linha é conteúdo do node, não heading."
    (let ((parts nil))
      (dotimes (_ (max 0 (if content level (1- level))))
        (push (propertize "│   " 'face 'font-lock-comment-face) parts))
      (concat
       (apply #'concat (nreverse parts))
       (cond
        (content "")
        ((> level 1)
         (propertize "├── " 'face 'font-lock-comment-face))
        (t "")))))

  (defun meu/org-sidebar-apply-content-indent (start end prefix)
    "Aplica PREFIX visual no início e wraps de cada linha entre START e END."
    (let ((inhibit-read-only t))
      (save-excursion
        (goto-char start)
        (while (< (point) end)
          (let* ((line-beg (line-beginning-position))
                 (line-end (line-end-position))
                 (prefix-ov (make-overlay line-beg line-beg nil t t))
                 (wrap-ov (make-overlay line-beg (min (1+ line-end) end) nil t t)))
            (overlay-put prefix-ov 'meu/org-sidebar-indent t)
            (overlay-put prefix-ov 'priority 1000)
            (overlay-put prefix-ov 'before-string prefix)
            (overlay-put wrap-ov 'meu/org-sidebar-indent t)
            (overlay-put wrap-ov 'priority 999)
            (overlay-put wrap-ov 'wrap-prefix prefix))
          (forward-line 1)))))

  (defun meu/org-sidebar-refresh-content-indent ()
    "Reaplica indentação visual do conteúdo da sidebar."
    (let ((inhibit-read-only t))
      (remove-overlays (point-min) (point-max) 'meu/org-sidebar-indent t)
      (save-excursion
        (goto-char (point-min))
        (while (not (eobp))
          (let ((prefix (get-text-property (line-beginning-position)
                                           'meu/org-content-prefix)))
            (when prefix
              (meu/org-sidebar-apply-content-indent
               (line-beginning-position)
               (min (1+ (line-end-position)) (point-max))
               prefix)))
          (forward-line 1)))))

  ;; -----------------------------
  ;; Bounds do node
  ;; -----------------------------

  (defun meu/org-node-full-bounds ()
    "Retorna heading + conteúdo direto, sem filhos."
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
                (if (re-search-forward org-heading-regexp nil t)
                    (match-beginning 0)
                  (point-max)))))
        (cons start end))))

  (defun meu/org-node-content-bounds ()
    "Retorna só conteúdo direto, sem heading/properties/filhos."
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
    "Preview curto do conteúdo direto do node, preservando linhas."
    (let* ((bounds (meu/org-node-content-bounds))
           (raw (buffer-substring-no-properties (car bounds) (cdr bounds)))
           (no-drawers
            (replace-regexp-in-string
             "^[ \t]*:PROPERTIES:\n\\(?:.*\n\\)*?[ \t]*:END:\n?"
             ""
             raw))
           (lines
            (mapcar #'string-trim-right
                    (split-string no-drawers "\n")))
           (clean-lines
            (let ((xs lines))
              (while (and xs (string-empty-p (string-trim (car xs))))
                (setq xs (cdr xs)))
              (setq xs (reverse xs))
              (while (and xs (string-empty-p (string-trim (car xs))))
                (setq xs (cdr xs)))
              (reverse xs)))
           (shown-lines clean-lines))
      (if (null shown-lines)
          ""
        (string-join shown-lines "\n"))))

  ;; -----------------------------
  ;; Card editável
  ;; -----------------------------

  (defun meu/org-show-card-at-marker (marker)
    "Mostra node atual no buffer direito como indirect buffer editável."
    (let ((source (marker-buffer marker))
          (pos (marker-position marker))
          bounds)
      (with-current-buffer source
        (save-excursion
          (goto-char pos)
          (org-back-to-heading t)
          (setq bounds (meu/org-node-full-bounds))))

      (unless (and (buffer-live-p (get-buffer meu/org-card-buffer))
                   (eq (buffer-base-buffer (get-buffer meu/org-card-buffer)) source))
        (when (get-buffer meu/org-card-buffer)
          (kill-buffer meu/org-card-buffer))
        (with-current-buffer source
          (clone-indirect-buffer meu/org-card-buffer nil)))

      (with-current-buffer meu/org-card-buffer
        (setq-local meu/org-cardflow-fontified nil)
        (setq buffer-read-only nil)
        (widen)
        (narrow-to-region (car bounds) (cdr bounds))
        (goto-char (point-min))
        (meu/org-cardflow-enable-org-rendering))

      (when (window-live-p meu/org-card-window)
        (with-selected-window meu/org-card-window
          (switch-to-buffer meu/org-card-buffer)))))

  ;; -----------------------------
  ;; Sidebar render
  ;; -----------------------------

  (defun meu/org-render-sidebar ()
    "Renderiza headings + preview virtual."
    (let ((source (if (not (meu/org-cardflow-virtual-buffer-p))
                      (current-buffer)
                    meu/org-source-buffer))
          (buf (get-buffer-create meu/org-sidebar-buffer)))
      (unless (and source (buffer-live-p source)
                   (not (meu/org-cardflow-virtual-buffer-p source)))
        (user-error "Abre o Cardflow a partir do ficheiro Org fonte, não de um buffer virtual"))
      (setq meu/org-source-buffer source)

      (with-current-buffer buf
        (setq buffer-read-only nil)
        (erase-buffer)
        (remove-overlays)

        (with-current-buffer source
          (org-map-entries
           (lambda ()
             (let* ((level (org-outline-level))
                    (title (org-get-heading t t t t))
                    (snippet (meu/org-node-snippet))
                    (heading-prefix (meu/org-sidebar-indent-prefix level))
                    (content-prefix (meu/org-sidebar-indent-prefix level t))
                    (marker (point-marker))
                    (face (intern (format "org-level-%d" (min level 8))))
                    line-start
                    line-end
                    snippet-start
                    snippet-end)
               (with-current-buffer buf
                 (setq line-start (point))

                 (insert heading-prefix)
                 (insert (propertize "● " 'face 'font-lock-keyword-face))
                 (insert (propertize title 'face face))
                 (insert "\n")

                 (setq line-end (point))

                 (put-text-property line-start line-end 'meu/org-marker marker)
                 (put-text-property line-start line-end 'meu/org-level level)
                 (put-text-property line-start line-end 'meu/org-heading-line t)

                 ;; preview real; permite font-lock, links e overlays Typst.
                 (unless (or (string-empty-p snippet)
                             (and meu/org-current-pos
                                  (= (marker-position marker) meu/org-current-pos)))
                   (setq snippet-start (point))
                   (insert snippet)
                   (insert "\n")
                   (setq snippet-end (point))
                   (put-text-property snippet-start snippet-end 'meu/org-marker marker)
                   (put-text-property snippet-start snippet-end 'meu/org-content-line t)
                   ;; Indentação visual apenas. Não inserir espaços reais no
                   ;; conteúdo, porque isso altera blocos Org/Typst.
                   (put-text-property
                    snippet-start snippet-end
                    'meu/org-content-prefix content-prefix)
                   (put-text-property
                    snippet-start snippet-end
                    'meu/org-content-wrap-prefix content-prefix)))))))

        (goto-char (point-min))
        (setq-local meu/org-cardflow-fontified nil)
        (meu/org-sidebar-mode)
        (let ((meu/org-typst-preview-silent-errors t))
          (meu/org-cardflow-enable-org-rendering))
        (meu/org-sidebar-disable-diagnostics)
        (meu/org-sidebar-refresh-content-indent))
      buf))

  ;; -----------------------------
  ;; Helpers
  ;; -----------------------------

  (defun meu/org-sidebar-current-marker ()
    (or (get-text-property (point) 'meu/org-marker)
        (save-excursion
          (beginning-of-line)
          (or (get-text-property (point) 'meu/org-marker)
              (when (re-search-backward "^.*$" nil t)
                (while (and (not (bobp))
                            (not (get-text-property (point) 'meu/org-heading-line)))
                  (forward-line -1))
                (get-text-property (point) 'meu/org-marker)))))))

  (defun meu/org-sidebar-current-level ()
    (save-excursion
      (beginning-of-line)
      (unless (get-text-property (point) 'meu/org-heading-line)
        (while (and (not (bobp))
                    (not (get-text-property (point) 'meu/org-heading-line)))
          (forward-line -1)))
      (get-text-property (point) 'meu/org-level)))

  (defun meu/org-sidebar-line-level ()
    "Retorna level apenas se a linha atual for uma linha navegável."
    (save-excursion
      (beginning-of-line)
      (when (get-text-property (point) 'meu/org-heading-line)
        (get-text-property (point) 'meu/org-level))))

  (defun meu/org-sidebar-goto-marker (marker)
    "Move cursor da sidebar para a linha correspondente ao MARKER ou posição."
    (let ((target-pos
           (cond
            ((markerp marker) (marker-position marker))
            ((integerp marker) marker)
            (t meu/org-current-pos))))
      (when target-pos
        (goto-char (point-min))
        (let ((found nil))
          (while (and (not found) (not (eobp)))
            (let ((m (get-text-property (point) 'meu/org-marker)))
              (when (and (get-text-property (point) 'meu/org-heading-line)
                         m
                         (= (marker-position m) target-pos))
                (setq found t)))
            (unless found
              (forward-line 1)))))))

  (defun meu/org-sidebar-sync ()
    "Atualiza card e redesenha sidebar para esconder preview do node selecionado."
    (interactive)
    (let ((marker (meu/org-sidebar-current-marker)))
      (when marker
        (setq meu/org-current-marker marker)
        (setq meu/org-current-pos (marker-position marker))

        (meu/org-show-card-at-marker marker)

        (when (and meu/org-sidebar-needs-render
                   (window-live-p meu/org-sidebar-window))
          (with-selected-window meu/org-sidebar-window
            (meu/org-render-sidebar)
            (switch-to-buffer meu/org-sidebar-buffer)
            (setq meu/org-sidebar-needs-render nil)))
        (when (window-live-p meu/org-sidebar-window)
          (with-selected-window meu/org-sidebar-window
            (meu/org-sidebar-goto-marker meu/org-current-pos))))))

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
          (let ((l (meu/org-sidebar-line-level)))
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
                    (= 0 (forward-line -1)))
          (let ((l (meu/org-sidebar-line-level)))
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
        (while (and (not target) (not (eobp)))
          (let ((l (meu/org-sidebar-line-level)))
            (cond
             ((null l) nil)
             ((= l (1+ level)) (setq target (point)))
             ((<= l level) (setq target 'stop))))
          (unless target
            (forward-line 1))))
      (when target
        (unless (eq target 'stop)
          (goto-char target)
          (meu/org-sidebar-sync)))))

  (defun meu/org-sidebar-parent ()
    "Volta para o pai."
    (interactive)
    (let ((level (meu/org-sidebar-current-level))
          found)
      (save-excursion
        (while (and (not found)
                    (= 0 (forward-line -1)))
          (let ((l (meu/org-sidebar-line-level)))
            (when (and l (< l level))
              (setq found (point))))))
      (when found
        (goto-char found)
        (meu/org-sidebar-sync))))

  ;; -----------------------------
  ;; Edição / guardar
  ;; -----------------------------

  (defun meu/org-sidebar-edit ()
    "Vai para o card e entra em insert."
    (interactive)
    (when (window-live-p meu/org-card-window)
      (select-window meu/org-card-window)
      (goto-char (point-min))
      (evil-insert-state)))

  (defun meu/org-sidebar-return ()
    "Guarda, atualiza sidebar e volta ao node editado."
    (interactive)
    (when (and (window-live-p meu/org-sidebar-window)
               (buffer-live-p meu/org-source-buffer)
               (not (meu/org-cardflow-virtual-buffer-p meu/org-source-buffer)))
      (with-current-buffer meu/org-source-buffer
        (save-buffer))

      (with-selected-window meu/org-sidebar-window
        (meu/org-render-sidebar)
        (switch-to-buffer meu/org-sidebar-buffer)
        (meu/org-sidebar-goto-marker meu/org-current-pos)
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

  (defun meu/org-refresh-sidebar-and-jump (marker)
    "Atualiza sidebar e salta para MARKER."
    (when (window-live-p meu/org-sidebar-window)
      (with-selected-window meu/org-sidebar-window
        (meu/org-render-sidebar)
        (switch-to-buffer meu/org-sidebar-buffer)
        (meu/org-sidebar-goto-marker marker)
        (meu/org-sidebar-sync))))

  ;; -----------------------------
  ;; Criar nodes
  ;; -----------------------------

  (defun meu/org-insert-sibling ()
    "Cria irmão depois da subtree do node atual."
    (interactive)
    (let ((marker (meu/org-sidebar-current-marker))
          new-marker)
      (when marker
        (with-current-buffer (marker-buffer marker)
          (save-restriction
            (widen)
            (goto-char (marker-position marker))
            (org-back-to-heading t)

            (let ((level (org-outline-level)))
              (org-end-of-subtree t t)

              (unless (bolp)
                (insert "\n"))
              (unless (looking-at-p "\n")
                (insert "\n"))

              (let ((start (point)))
                (insert (make-string level ?*) " Novo node\n")
                (setq new-marker (copy-marker start))
                (insert ":PROPERTIES:\n:END:\n\n")))

            (save-buffer)))

        (setq meu/org-current-marker new-marker)
        (setq meu/org-current-pos (marker-position new-marker))
        (meu/org-refresh-sidebar-and-jump new-marker)
        (meu/org-sidebar-edit))))

  (defun meu/org-insert-child ()
    "Cria filho no fim da subtree do node atual."
    (interactive)
    (let ((marker (meu/org-sidebar-current-marker))
          new-marker)
      (when marker
        (with-current-buffer (marker-buffer marker)
          (save-restriction
            (widen)
            (goto-char (marker-position marker))
            (org-back-to-heading t)

            (let ((child-level (1+ (org-outline-level))))
              (org-end-of-subtree t t)

              (unless (bolp)
                (insert "\n"))
              (unless (looking-at-p "\n")
                (insert "\n"))

              (let ((start (point)))
                (insert (make-string child-level ?*) " Novo filho\n")
                (setq new-marker (copy-marker start))
                (insert ":PROPERTIES:\n:END:\n\n")))

            (save-buffer)))

        (setq meu/org-current-marker new-marker)
        (setq meu/org-current-pos (marker-position new-marker))
        (meu/org-refresh-sidebar-and-jump new-marker)
        (meu/org-sidebar-edit))))

  (defun meu/org-move-subtree-up ()
    "Move o node/subtree atual para cima."
    (interactive)
    (let ((marker (meu/org-sidebar-current-marker))
          new-marker)
      (when marker
        (with-current-buffer (marker-buffer marker)
          (save-restriction
            (widen)
            (goto-char (marker-position marker))
            (org-back-to-heading t)
            (org-move-subtree-up 1)
            (org-back-to-heading t)
            (setq new-marker (copy-marker (point)))
            (save-buffer)))

        (setq meu/org-current-marker new-marker)
        (setq meu/org-current-pos (marker-position new-marker))
        (meu/org-refresh-sidebar-and-jump new-marker))))


  (defun meu/org-move-subtree-down ()
    "Move o node/subtree atual para baixo."
    (interactive)
    (let ((marker (meu/org-sidebar-current-marker))
          new-marker)
      (when marker
        (with-current-buffer (marker-buffer marker)
          (save-restriction
            (widen)
            (goto-char (marker-position marker))
            (org-back-to-heading t)
            (org-move-subtree-down 1)
            (org-back-to-heading t)
            (setq new-marker (copy-marker (point)))
            (save-buffer)))

        (setq meu/org-current-marker new-marker)
        (setq meu/org-current-pos (marker-position new-marker))
        (meu/org-refresh-sidebar-and-jump new-marker))))

  ;; -----------------------------
  ;; Canvas experimental
  ;; -----------------------------

  (defvar meu/org-cardflow-canvas-source nil)
  (defvar meu/org-cardflow-canvas-file
    (expand-file-name "cardflow-canvas.html" temporary-file-directory))
  (defvar meu/org-cardflow-canvas-server nil)
  (defvar meu/org-cardflow-canvas-port nil)

  (defun meu/org-cardflow-canvas--source-buffer ()
    "Retorna o buffer Org fonte para a view canvas."
    (cond
     ((and meu/org-cardflow-canvas-source
           (buffer-live-p meu/org-cardflow-canvas-source))
      meu/org-cardflow-canvas-source)
     ((and (derived-mode-p 'org-mode)
           (not (meu/org-cardflow-virtual-buffer-p)))
      (current-buffer))
     ((and meu/org-source-buffer
           (buffer-live-p meu/org-source-buffer))
      meu/org-source-buffer)
     (t
      (user-error "Abre o canvas a partir de um buffer Org fonte ou do Cardflow"))))

  (defun meu/org-cardflow-canvas--node-content ()
    "Retorna conteúdo direto do node atual para o painel lateral."
    (let* ((bounds (meu/org-node-content-bounds))
           (raw (buffer-substring-no-properties (car bounds) (cdr bounds))))
      (string-trim
       (replace-regexp-in-string
        "^[ \t]*:PROPERTIES:\n\\(?:.*\n\\)*?[ \t]*:END:\n?"
        ""
        raw))))

  (defun meu/org-cardflow-canvas--nodes (source)
    "Extrai nodes de SOURCE para o canvas HTML."
    (let ((nodes nil)
          (stack nil)
          (idx 0))
      (with-current-buffer source
        (org-map-entries
         (lambda ()
           (let* ((level (org-outline-level))
                  (id (format "n%d" idx))
                  (title (org-get-heading t t t t))
                  (content (meu/org-cardflow-canvas--node-content))
                  (parent (cdr (assoc (1- level) stack))))
             (setq stack (assq-delete-all level stack))
             (push (cons level id) stack)
             (push `((id . ,id)
                     (parent . ,parent)
                     (level . ,level)
                     (title . ,title)
                     (content . ,content)
                     (pos . ,(point)))
                   nodes)
             (setq idx (1+ idx))))))
      (vconcat (nreverse nodes))))

  (defun meu/org-cardflow-canvas--goto-node-id (id)
    "Vai para o heading identificado por ID no buffer atual."
    (unless (and (stringp id)
                 (string-match "\\`n\\([0-9]+\\)\\'" id))
      (user-error "Node inválido: %s" id))
    (let ((target (string-to-number (match-string 1 id)))
          (idx 0)
          found)
      (goto-char (point-min))
      (org-map-entries
       (lambda ()
         (when (= idx target)
           (setq found (point)))
         (setq idx (1+ idx))))
      (unless found
        (user-error "Node não encontrado: %s" id))
      (goto-char found)
      (org-back-to-heading t)))

  (defun meu/org-cardflow-canvas--id-at-pos (nodes pos)
    "Retorna o id em NODES cuja posição é POS."
    (catch 'found
      (dotimes (i (length nodes))
        (let ((node (aref nodes i)))
          (when (= (alist-get 'pos node) pos)
            (throw 'found (alist-get 'id node)))))
      nil))

  (defun meu/org-cardflow-canvas--rewrite-file (nodes)
    "Reescreve o HTML do canvas com NODES."
    (with-temp-file meu/org-cardflow-canvas-file
      (insert (meu/org-cardflow-canvas--html
               nodes
               meu/org-cardflow-canvas-port))))

  (defun meu/org-cardflow-canvas--response (status type body)
    "Cria resposta HTTP simples."
    (format "HTTP/1.1 %s\r\nContent-Type: %s; charset=utf-8\r\nAccess-Control-Allow-Origin: *\r\nAccess-Control-Allow-Headers: content-type\r\nAccess-Control-Allow-Methods: POST, OPTIONS\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s"
            status type (string-bytes body) body))

  (defun meu/org-cardflow-canvas--json-response (payload)
    "Cria resposta HTTP JSON."
    (let ((json-object-type 'alist)
          (json-array-type 'array))
      (meu/org-cardflow-canvas--response
       "200 OK"
       "application/json"
       (json-encode payload))))

  (defun meu/org-cardflow-canvas--insert-node (id child)
    "Insere node irmão ou filho de ID. CHILD non-nil cria filho."
    (let (new-marker)
      (with-current-buffer (meu/org-cardflow-canvas--source-buffer)
        (save-restriction
          (widen)
          (meu/org-cardflow-canvas--goto-node-id id)
          (let ((level (+ (org-outline-level) (if child 1 0))))
            (org-end-of-subtree t t)
            (unless (bolp)
              (insert "\n"))
            (unless (looking-at-p "\n")
              (insert "\n"))
            (let ((start (point)))
              (insert (make-string level ?*)
                      (if child " Novo filho\n" " Novo node\n"))
              (setq new-marker (copy-marker start))
              (insert ":PROPERTIES:\n:END:\n\n")))
          (save-buffer)))
      new-marker))

  (defun meu/org-cardflow-canvas--update-node (id title content)
    "Atualiza título e conteúdo direto de ID."
    (let (marker)
      (with-current-buffer (meu/org-cardflow-canvas--source-buffer)
        (save-restriction
          (widen)
          (meu/org-cardflow-canvas--goto-node-id id)
          (setq marker (copy-marker (point)))
          (org-edit-headline (or title ""))
          (org-back-to-heading t)
          (let ((bounds (meu/org-node-content-bounds))
                (text (or content "")))
            (delete-region (car bounds) (cdr bounds))
            (goto-char (car bounds))
            (unless (string-empty-p text)
              (insert text)
              (unless (string-suffix-p "\n" text)
                (insert "\n"))))
          (save-buffer)))
      marker))

  (defun meu/org-cardflow-canvas--handle-action (payload)
    "Executa ação recebida do canvas e devolve payload JSON."
    (let* ((action (alist-get 'action payload))
           (id (alist-get 'id payload))
           marker selected nodes)
      (cond
       ((string= action "create-sibling")
        (setq marker (meu/org-cardflow-canvas--insert-node id nil)))
       ((string= action "create-child")
        (setq marker (meu/org-cardflow-canvas--insert-node id t)))
       ((string= action "update")
        (setq marker
              (meu/org-cardflow-canvas--update-node
               id
               (alist-get 'title payload)
               (alist-get 'content payload))))
       (t
        (user-error "Ação desconhecida: %s" action)))
      (setq nodes (meu/org-cardflow-canvas--nodes
                   (meu/org-cardflow-canvas--source-buffer)))
      (setq selected
            (and marker
                 (meu/org-cardflow-canvas--id-at-pos
                  nodes
                  (marker-position marker))))
      (meu/org-cardflow-canvas--rewrite-file nodes)
      `((ok . t)
        (selected . ,(or selected id)))))

  (defun meu/org-cardflow-canvas--server-filter (proc chunk)
    "Processa requisições HTTP simples de PROC."
    (let ((data (concat (or (process-get proc 'data) "") chunk)))
      (process-put proc 'data data)
      (when (string-match-p "\r\n\r\n" data)
        (let* ((parts (split-string data "\r\n\r\n"))
               (head (car parts))
               (body (mapconcat #'identity (cdr parts) "\r\n\r\n"))
               (len (if (string-match "Content-Length: \\([0-9]+\\)" head)
                        (string-to-number (match-string 1 head))
                      0)))
          (when (>= (string-bytes body) len)
            (condition-case err
                (let ((response
                       (cond
                        ((string-prefix-p "OPTIONS " head)
                         (meu/org-cardflow-canvas--response "204 No Content" "text/plain" ""))
                        ((string-prefix-p "POST /action " head)
                         (let* ((json-object-type 'alist)
                                (json-array-type 'array)
                                (payload (json-read-from-string
                                          (substring body 0 len))))
                           (meu/org-cardflow-canvas--json-response
                            (meu/org-cardflow-canvas--handle-action payload))))
                        (t
                         (meu/org-cardflow-canvas--response
                          "404 Not Found" "text/plain" "not found")))))
                  (process-send-string proc response))
              (error
               (process-send-string
                proc
                (meu/org-cardflow-canvas--json-response
                 `((ok . :json-false)
                   (error . ,(error-message-string err)))))))
            (delete-process proc))))))

  (defun meu/org-cardflow-canvas--ensure-server ()
    "Garante servidor local para ações do canvas."
    (unless (process-live-p meu/org-cardflow-canvas-server)
      (setq meu/org-cardflow-canvas-server
            (make-network-process
             :name "cardflow-canvas-server"
             :server t
             :service t
             :host "127.0.0.1"
             :noquery t
             :filter #'meu/org-cardflow-canvas--server-filter))
      (setq meu/org-cardflow-canvas-port
            (process-contact meu/org-cardflow-canvas-server :service)))
    meu/org-cardflow-canvas-port)

  (defun meu/org-cardflow-canvas--html (nodes &optional port)
    "Gera HTML do canvas para NODES."
    (let ((json-array-type 'array)
          (json-object-type 'alist))
      (format
       "<!doctype html>
<html>
<head>
<meta charset=\"utf-8\">
<title>Cardflow Canvas</title>
<style>
:root {
  --bg: #0d0d0b;
  --panel: #17151b;
  --card: #242129;
  --card2: #2e2936;
  --line: #6f5f8f;
  --fg: #d8d0df;
  --muted: #948b9f;
  --accent: #c9b6ff;
}
* { box-sizing: border-box; }
body { margin: 0; background: var(--bg); color: var(--fg); font: 14px/1.45 ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; overflow: hidden; }
#app { display: grid; grid-template-columns: 1fr 380px; height: 100vh; }
#canvasWrap { position: relative; overflow-x: auto; overflow-y: hidden; }
#canvas { display: flex; gap: 8px; height: 100vh; min-width: max-content; padding: 0 6px; }
.column {
  flex: 0 0 330px; height: 100vh; overflow-y: auto; padding: 36px 2px 44px;
  border-right: 1px solid #211d27; scroll-behavior: smooth;
}
.column-title { color: var(--muted); font-size: 11px; margin: 0 0 12px 4px; }
.node {
  width: 100%%; min-height: 92px; padding: 12px 14px; margin-bottom: 14px;
  border: 1px solid #3b3346; border-left: 4px solid var(--accent);
  background: linear-gradient(180deg, var(--card), var(--card2));
  border-radius: 8px; box-shadow: 0 10px 28px rgba(0,0,0,.28);
  cursor: pointer; white-space: normal;
}
.node:hover, .node.selected { border-color: var(--accent); background: #332d3d; }
.node.path { border-color: #81709f; }
.node.child-target { border-color: #8b7ac1; }
.level { color: var(--accent); font-size: 11px; margin-bottom: 6px; }
.title { font-weight: 700; color: #f1edf6; }
.body { color: var(--muted); margin-top: 8px; white-space: pre-wrap; }
#side { border-left: 1px solid #2c2733; background: var(--panel); padding: 18px; overflow: auto; }
#side h1 { font-size: 18px; margin: 0 0 8px; }
#side .meta { color: var(--muted); margin-bottom: 14px; }
#content { white-space: pre-wrap; color: #cfc7d8; }
#editTitle, #editContent {
  width: 100%%; background: #211d28; color: var(--fg); border: 1px solid #4b4058;
  border-radius: 6px; padding: 9px 10px; font: inherit;
}
#editTitle { margin-bottom: 10px; font-weight: 700; }
#editContent { min-height: 58vh; resize: vertical; white-space: pre-wrap; }
#toolbar { position: sticky; top: 0; background: var(--panel); padding-bottom: 12px; margin-bottom: 12px; border-bottom: 1px solid #2c2733; }
button { background: #2d2735; color: var(--fg); border: 1px solid #4b4058; border-radius: 6px; padding: 7px 10px; cursor: pointer; }
</style>
</head>
<body>
<div id=\"app\">
  <div id=\"canvasWrap\"><div id=\"canvas\"></div></div>
  <aside id=\"side\">
    <div id=\"toolbar\"><button id=\"fit\">Ir para selecionado</button></div>
    <h1>Seleciona um node</h1>
    <input id=\"editTitle\" hidden>
    <div class=\"meta\">Tree canvas experimental</div>
    <div id=\"content\"></div>
    <textarea id=\"editContent\" hidden></textarea>
  </aside>
</div>
<script>
const apiBase = 'http://127.0.0.1:%s';
const nodes = %s;
const byId = new Map(nodes.map(n => [n.id, n]));
const children = new Map();
const levels = new Map();
for (const n of nodes) {
  if (!children.has(n.parent || 'root')) children.set(n.parent || 'root', []);
  children.get(n.parent || 'root').push(n);
  if (!levels.has(n.level)) levels.set(n.level, []);
  levels.get(n.level).push(n);
}
const canvas = document.getElementById('canvas');
const wrap = document.getElementById('canvasWrap');
const nodeEls = new Map();
const columnEls = new Map();
let selected = null;
let editing = false;
function centerNode(n) {
  const el = nodeEls.get(n.id);
  const column = columnEls.get(n.level);
  if (!el || !column) return;
  const top = el.offsetTop - column.offsetTop - (column.clientHeight / 2) + (el.offsetHeight / 2);
  column.scrollTo({ top: Math.max(0, top), behavior: 'smooth' });
}
function centerColumn(level) {
  const column = columnEls.get(level);
  if (!column) return;
  const left = column.offsetLeft - (wrap.clientWidth / 2) + (column.clientWidth / 2);
  wrap.scrollTo({ left: Math.max(0, left), behavior: 'smooth' });
}
function ancestors(n) {
  const result = [];
  let cur = n;
  while (cur && cur.parent) {
    cur = byId.get(cur.parent);
    if (cur) result.push(cur);
  }
  return result;
}
function showNode(n, el) {
  if (editing) return;
  document.querySelectorAll('.node').forEach(x => x.classList.remove('selected', 'path', 'child-target'));
  selected = n;
  const target = el || nodeEls.get(n.id);
  target?.classList.add('selected');
  for (const parent of ancestors(n)) nodeEls.get(parent.id)?.classList.add('path');
  const firstChild = (children.get(n.id) || [])[0];
  if (firstChild) nodeEls.get(firstChild.id)?.classList.add('child-target');
  document.querySelector('#side h1').textContent = n.title;
  document.querySelector('#side .meta').textContent = `h${n.level} • ${n.id}`;
  document.querySelector('#content').textContent = n.content || '';
  centerNode(n);
  for (const parent of ancestors(n)) centerNode(parent);
  if (firstChild) centerNode(firstChild);
  centerColumn(n.level);
}
function beginEdit() {
  if (!selected || editing) return;
  editing = true;
  document.querySelector('#side h1').hidden = true;
  document.querySelector('#content').hidden = true;
  const title = document.getElementById('editTitle');
  const content = document.getElementById('editContent');
  title.hidden = false;
  content.hidden = false;
  title.value = selected.title || '';
  content.value = selected.content || '';
  content.focus();
}
async function postAction(action, extra = {}) {
  if (!selected) return;
  const response = await fetch(apiBase + '/action', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ action, id: selected.id, ...extra })
  });
  const data = await response.json();
  if (!data.ok) {
    alert(data.error || 'Erro no Cardflow canvas');
    return;
  }
  if (data.selected) localStorage.setItem('cardflowCanvasSelected', data.selected);
  location.reload();
}
function saveEdit() {
  if (!editing || !selected) return;
  postAction('update', {
    title: document.getElementById('editTitle').value,
    content: document.getElementById('editContent').value
  });
}
for (const level of [...levels.keys()].sort((a, b) => a - b)) {
  const column = document.createElement('section');
  column.className = 'column';
  column.dataset.level = level;
  column.innerHTML = `<div class=\"column-title\">h${level}</div>`;
  columnEls.set(level, column);
  for (const n of levels.get(level)) {
    const el = document.createElement('div');
    el.className = 'node';
    el.innerHTML = `<div class=\"level\">h${n.level}</div><div class=\"title\"></div><div class=\"body\"></div>`;
    el.querySelector('.title').textContent = n.title;
    el.querySelector('.body').textContent = n.content || '';
    el.addEventListener('click', () => showNode(n, el));
    nodeEls.set(n.id, el);
    column.appendChild(el);
  }
  canvas.appendChild(column);
}
function moveSelection(direction) {
  if (!selected && nodes[0]) return showNode(nodes[0]);
  if (!selected) return;
  const siblings = children.get(selected.parent || 'root') || [];
  const index = siblings.findIndex(n => n.id === selected.id);
  let next = null;
  if (direction === 'parent' && selected.parent) next = byId.get(selected.parent);
  if (direction === 'child') next = (children.get(selected.id) || [])[0];
  if (direction === 'prev' && index > 0) next = siblings[index - 1];
  if (direction === 'next' && index >= 0 && index < siblings.length - 1) next = siblings[index + 1];
  if (next) showNode(next);
}
window.addEventListener('keydown', e => {
  if (editing) {
    if ((e.key === 'Enter' && (e.ctrlKey || e.metaKey)) || (e.key === 'q' && !['INPUT', 'TEXTAREA'].includes(document.activeElement.tagName))) {
      saveEdit();
      e.preventDefault();
    }
    if (e.key === 'Escape') {
      document.activeElement.blur();
      e.preventDefault();
    }
    return;
  }
  if (['INPUT', 'TEXTAREA'].includes(document.activeElement.tagName)) return;
  const keys = {
    ArrowLeft: 'parent',
    h: 'parent',
    ArrowRight: 'child',
    l: 'child',
    ArrowUp: 'prev',
    k: 'prev',
    ArrowDown: 'next',
    j: 'next'
  };
  if (e.key === 'c') {
    postAction('create-sibling');
    e.preventDefault();
    return;
  }
  if (e.key === 'n') {
    postAction('create-child');
    e.preventDefault();
    return;
  }
  if (e.key === 'i') {
    beginEdit();
    e.preventDefault();
    return;
  }
  const direction = keys[e.key];
  if (!direction) return;
  moveSelection(direction);
  e.preventDefault();
});
document.getElementById('fit').addEventListener('click', () => {
  if (selected) showNode(selected);
});
const remembered = localStorage.getItem('cardflowCanvasSelected');
const initial = remembered ? byId.get(remembered) : nodes[0];
if (initial) showNode(initial, nodeEls.get(initial.id));
</script>
</body>
</html>"
       (or port "")
       (json-encode nodes))))

  (defun meu/org-cardflow-canvas ()
    "Gera e abre uma view HTML experimental de canvas para o Org atual."
    (interactive)
    (require 'json)
    (let* ((port (meu/org-cardflow-canvas--ensure-server))
           (source (meu/org-cardflow-canvas--source-buffer))
           (nodes (meu/org-cardflow-canvas--nodes source)))
      (setq meu/org-cardflow-canvas-source source)
      (with-temp-file meu/org-cardflow-canvas-file
        (insert (meu/org-cardflow-canvas--html nodes port)))
      (browse-url-of-file meu/org-cardflow-canvas-file)))

  (defalias 'cardflow-canvas #'meu/org-cardflow-canvas)

  ;; -----------------------------
  ;; Keybinds
  ;; -----------------------------

  (evil-define-key 'normal meu/org-sidebar-mode-map
    (kbd "<down>")  #'meu/org-sidebar-next-sibling
    (kbd "<up>")    #'meu/org-sidebar-prev-sibling
    (kbd "<right>") #'meu/org-sidebar-first-child
    (kbd "<left>")  #'meu/org-sidebar-parent
    (kbd "RET")     #'meu/org-sidebar-sync
    (kbd "i")       #'meu/org-sidebar-edit
    (kbd "c")       #'meu/org-insert-sibling
    (kbd "n")       #'meu/org-insert-child
    (kbd "S-<up>")   #'meu/org-move-subtree-up
    (kbd "S-<down>") #'meu/org-move-subtree-down)

  (evil-define-key 'normal org-mode-map
    (kbd "q")
    (lambda ()
      (interactive)
      (when (string= (buffer-name) meu/org-card-buffer)
        (meu/org-sidebar-return))))
