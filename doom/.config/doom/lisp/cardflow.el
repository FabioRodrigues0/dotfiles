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

  ;; -----------------------------
  ;; Sidebar mode
  ;; -----------------------------

  (defvar meu/org-sidebar-mode-map (make-sparse-keymap))

  (define-derived-mode meu/org-sidebar-mode special-mode "OrgSidebar"
    "Sidebar virtual para navegar headings Org."
    (setq buffer-read-only t)
    (setq-local cursor-type nil)
    (setq-local truncate-lines nil)
    (setq-local word-wrap t)
    (display-line-numbers-mode -1)
    (visual-line-mode 1)
    (evil-normalize-keymaps))

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
           (max-lines 3)
           (shown-lines (seq-take clean-lines max-lines))
           (has-more (> (length clean-lines) max-lines)))
      (if (null shown-lines)
          ""
        (concat
         (string-join shown-lines "\n")
         (when has-more "\n…")))))

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

        (when (fboundp 'org-fold-hide-drawer-all)
          (org-fold-hide-drawer-all)))

      (when (window-live-p meu/org-card-window)
        (with-selected-window meu/org-card-window
          (switch-to-buffer meu/org-card-buffer)))))

  ;; -----------------------------
  ;; Sidebar render
  ;; -----------------------------

  (defun meu/org-render-sidebar ()
    "Renderiza headings + preview virtual."
    (let ((source (or meu/org-source-buffer (current-buffer)))
          (buf (get-buffer-create meu/org-sidebar-buffer)))
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
                    (indent (make-string (* 2 (1- level)) ?\s))
                    (marker (point-marker))
                    (face (intern (format "org-level-%d" (min level 8))))
                    line-start
                    line-end
                    ov)
               (with-current-buffer buf
                 (setq line-start (point))

                 (insert indent)
                 (insert (propertize "● " 'face 'font-lock-keyword-face))
                 (insert (propertize title 'face face))
                 (insert "\n")

                 (setq line-end (point))

                 (put-text-property line-start line-end 'meu/org-marker marker)
                 (put-text-property line-start line-end 'meu/org-level level)

                 ;; preview virtual; não aparece no node selecionado
                 (unless (or (string-empty-p snippet)
                             (and meu/org-current-pos
                                  (= (marker-position marker) meu/org-current-pos)))
                   (setq ov (make-overlay line-end line-end))
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
  ;; Helpers
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
            (let ((m (meu/org-sidebar-current-marker)))
              (when (and m (= (marker-position m) target-pos))
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

        (with-selected-window meu/org-sidebar-window
          (meu/org-render-sidebar)
          (switch-to-buffer meu/org-sidebar-buffer)
          (meu/org-sidebar-goto-marker meu/org-current-pos)))))

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
               (buffer-live-p meu/org-source-buffer))
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
        (meu/org-sidebar-return)))))
