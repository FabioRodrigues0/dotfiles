;;; cardflow.el -*- lexical-binding: t; -*-

(after! org
  (require 'subr-x)

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
