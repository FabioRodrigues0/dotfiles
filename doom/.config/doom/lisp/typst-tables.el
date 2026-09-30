;;; typst-tables.el --- Tabelas Typst legíveis no código -*- lexical-binding: t; -*-

;; Em `#table(...)' e `#grid(...)':
;; - `fabio/typst-table-colors-mode' pinta cada célula com a cor da sua coluna
;;   (o cabeçalho fica a negrito), para se perceber onde acaba cada coluna.
;; - `fabio/typst-table-align' põe cada linha da tabela numa linha do ficheiro
;;   e alinha as colunas como uma grelha.

(require 'treesit)
(require 'subr-x)

(defface fabio/typst-table-col-1 '((t (:foreground "#a0c7cf"))) "Coluna 1 de uma tabela Typst.")
(defface fabio/typst-table-col-2 '((t (:foreground "#b8a6f0"))) "Coluna 2 de uma tabela Typst.")
(defface fabio/typst-table-col-3 '((t (:foreground "#e0b27a"))) "Coluna 3 de uma tabela Typst.")
(defface fabio/typst-table-col-4 '((t (:foreground "#8fd4a4"))) "Coluna 4 de uma tabela Typst.")
(defface fabio/typst-table-col-5 '((t (:foreground "#e89ab8"))) "Coluna 5 de uma tabela Typst.")

(defvar fabio/typst-table-col-faces
  '(fabio/typst-table-col-1 fabio/typst-table-col-2 fabio/typst-table-col-3
    fabio/typst-table-col-4 fabio/typst-table-col-5)
  "Faces usadas por coluna, em ciclo.")

(defvar fabio/typst-table-align-max-width 40
  "Células mais largas do que isto não empurram o alinhamento da coluna.")

;; ── Leitura da tabela a partir da árvore tree-sitter ────────────────────────

(defun fabio/typst-table--call-name (node)
  "Nome da função chamada por NODE (ex.: \"table\", \"table.header\")."
  (when-let* ((item (treesit-node-child-by-field-name node "item")))
    (treesit-node-text item t)))

(defun fabio/typst-table--nodes ()
  "Todos os nós `call' de table/grid no buffer."
  (let ((root (treesit-buffer-root-node 'typst)))
    (mapcar #'cdr
            (seq-filter
             (lambda (cap)
               (member (fabio/typst-table--call-name (cdr cap)) '("table" "grid")))
             (treesit-query-capture root '((call) @c))))))

(defun fabio/typst-table--args (call)
  "O nó `group' com os argumentos de CALL."
  (seq-find (lambda (n) (equal (treesit-node-type n) "group"))
            (treesit-node-children call t)))

(defun fabio/typst-table--columns (args)
  "Número de colunas pedido em `columns:', ou nil se não der para saber."
  (when-let* ((tagged (seq-find
                       (lambda (n)
                         (and (equal (treesit-node-type n) "tagged")
                              (equal (treesit-node-text
                                      (treesit-node-child-by-field-name n "field") t)
                                     "columns")))
                       (treesit-node-children args t)))
              (value (car (last (treesit-node-children tagged t)))))
    (pcase (treesit-node-type value)
      ("number" (string-to-number (treesit-node-text value t)))
      ("group" (length (treesit-node-children value t))))))

(defun fabio/typst-table--cells (args)
  "Lista de (NÓ . HEADER?) com as células de ARGS, pela ordem."
  (let (cells)
    (dolist (n (treesit-node-children args t))
      (pcase (treesit-node-type n)
        ("content" (push (cons n nil) cells))
        ("call"
         (let ((name (fabio/typst-table--call-name n)))
           (cond
            ((string-match-p "\\.\\(header\\|footer\\)\\'" name)
             (dolist (c (treesit-node-children (fabio/typst-table--args n) t))
               (when (member (treesit-node-type c) '("content" "call"))
                 (push (cons c (string-suffix-p "header" name)) cells))))
            ((string-suffix-p ".cell" name) (push (cons n nil) cells)))))))
    (nreverse cells)))

;; ── Cores por coluna ────────────────────────────────────────────────────────

(defvar-local fabio/typst-table--timer nil)

(defun fabio/typst-table--colorize ()
  "Refaz as cores das colunas em todas as tabelas do buffer."
  (remove-overlays (point-min) (point-max) 'fabio/typst-table t)
  (when (treesit-parser-list nil 'typst)
    (dolist (call (fabio/typst-table--nodes))
      (when-let* ((args (fabio/typst-table--args call)))
        (let ((ncols (or (fabio/typst-table--columns args) 1))
              (i 0))
          (dolist (cell (fabio/typst-table--cells args))
            (let* ((face (nth (mod (mod i ncols) (length fabio/typst-table-col-faces))
                              fabio/typst-table-col-faces))
                   (ov (make-overlay (treesit-node-start (car cell))
                                     (treesit-node-end (car cell)))))
              (overlay-put ov 'fabio/typst-table t)
              (overlay-put ov 'face (if (cdr cell) (list :weight 'bold face) face))
              (overlay-put ov 'priority 10))
            (setq i (1+ i))))))))

(defun fabio/typst-table--schedule (&rest _)
  (when (timerp fabio/typst-table--timer)
    (cancel-timer fabio/typst-table--timer))
  (let ((buf (current-buffer)))
    (setq fabio/typst-table--timer
          (run-with-idle-timer
           0.3 nil
           (lambda ()
             (when (buffer-live-p buf)
               (with-current-buffer buf
                 (when fabio/typst-table-colors-mode
                   (fabio/typst-table--colorize)))))))))

(define-minor-mode fabio/typst-table-colors-mode
  "Pinta as células das tabelas Typst com uma cor por coluna."
  :lighter nil
  (if fabio/typst-table-colors-mode
      (progn
        (add-hook 'after-change-functions #'fabio/typst-table--schedule nil t)
        (fabio/typst-table--schedule))
    (remove-hook 'after-change-functions #'fabio/typst-table--schedule t)
    (remove-overlays (point-min) (point-max) 'fabio/typst-table t)))

;; ── Alinhar em grelha ───────────────────────────────────────────────────────

(defun fabio/typst-table--pad (texts widths)
  "Junta TEXTS com \", \" e alinha cada um à largura da sua coluna em WIDTHS."
  (let ((last (1- (length texts))))
    (string-join
     (seq-map-indexed
      (lambda (text i)
        (let ((cell (concat text ",")))
          (if (= i last)
              cell
            (concat cell (make-string (max 1 (- (1+ (nth i widths)) (string-width text))) ?\s)))))
      texts)
     "")))

(defun fabio/typst-table-align ()
  "Alinha em grelha a tabela Typst onde está o cursor.
Cada linha da tabela fica numa linha do ficheiro, com as colunas alinhadas."
  (interactive)
  (let* ((call (treesit-parent-until
                (treesit-node-at (point) 'typst)
                (lambda (n)
                  (and (equal (treesit-node-type n) "call")
                       (member (fabio/typst-table--call-name n) '("table" "grid"))))
                t))
         (args (and call (fabio/typst-table--args call)))
         (ncols (and args (fabio/typst-table--columns args))))
    (unless args (user-error "O cursor não está dentro de um #table ou #grid"))
    (unless ncols (user-error "Não consegui perceber quantas colunas tem (columns:)"))
    (let (named header header-name rows)
      (dolist (n (treesit-node-children args t))
        (let ((text (treesit-node-text n t)))
          (pcase (treesit-node-type n)
            ("tagged" (push text named))
            ("content" (push text rows))
            ("call"
             (let ((name (fabio/typst-table--call-name n)))
               (cond
                ((string-suffix-p ".header" name)
                 (setq header-name name
                       header (mapcar (lambda (c) (treesit-node-text c t))
                                      (treesit-node-children (fabio/typst-table--args n) t))))
                ((string-suffix-p ".cell" name) (push text rows))
                (t (user-error "Não sei alinhar tabelas com %s" name)))))
            (_ (user-error "Não sei alinhar tabelas com %s (ex.: comentários)"
                           (treesit-node-type n))))))
      (setq named (nreverse named)
            rows (seq-partition (nreverse rows) ncols))
      (when (seq-some (lambda (r) (seq-some (lambda (c) (string-search "\n" c)) r))
                      (append (list header) rows))
        (user-error "Há células com várias linhas; não dá para alinhar"))
      (let* ((widths (mapcar
                      (lambda (i)
                        (seq-max
                         (cons 0 (seq-filter
                                  (lambda (w) (<= w fabio/typst-table-align-max-width))
                                  (mapcar (lambda (r) (string-width (or (nth i r) "")))
                                          (cons header rows))))))
                      (number-sequence 0 (1- ncols))))
             (base (save-excursion (goto-char (treesit-node-start call))
                                   (current-indentation)))
             (indent (make-string (+ base typst-ts-indent-offset) ?\s))
             (lines (append
                     (mapcar (lambda (s) (concat s ",")) named)
                     (when header
                       (list (concat header-name "(" (string-join header ", ") "),")))
                     (mapcar (lambda (r) (fabio/typst-table--pad r widths)) rows))))
        (save-excursion
          (goto-char (treesit-node-start args))
          (let ((start (point)) (end (treesit-node-end args)))
            (delete-region start end)
            (insert "(\n"
                    (mapconcat (lambda (l) (concat indent (string-trim-right l))) lines "\n")
                    "\n" (make-string base ?\s) ")")))))))

(add-hook 'typst-ts-mode-hook #'fabio/typst-table-colors-mode)

(after! typst-ts-mode
  (map! :map typst-ts-mode-map
        :localleader
        :desc "Alinhar tabela" "t a" #'fabio/typst-table-align
        :desc "Cores nas tabelas" "t c" #'fabio/typst-table-colors-mode))

(provide 'typst-tables)
;;; typst-tables.el ends here
