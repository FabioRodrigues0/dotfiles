;;; package --- summary org-typst-preview.el -*- lexical-binding: t; -*-
;;; Commentary:
;;;
(require 'org)
(require 'org-element)
(require 'subr-x)
(require 'cl-lib)

(setenv "PATH"
        (concat (getenv "PATH")
                ":"
                (expand-file-name "~/.local/share/mise/shims")))

(add-to-list 'exec-path
             (expand-file-name "~/.local/share/mise/shims"))
;;; Code:
(defvar meu/org-typst-preview-dir
  (expand-file-name "org-typst-preview/" temporary-file-directory))

(defvar-local meu/org-typst-preview-silent-errors nil
  "Se non-nil, ignora erros individuais de preview Typst neste buffer.")

(defun meu/org-typst--buffer-output ()
  "Retorna e limpa o output do buffer de compilação Typst."
  (with-current-buffer (get-buffer-create "*org-typst-preview*")
    (prog1 (string-trim (buffer-string))
      (erase-buffer))))

(defun meu/org-typst--delete-file-if-exists (file)
  "Remove FILE se existir, ignorando erros."
  (when (and file (file-exists-p file))
    (ignore-errors
      (delete-file file))))

(defun meu/org-typst-clear-previews ()
  "Remove todos os previews Typst do buffer atual."
  (interactive)
  (remove-overlays (point-min) (point-max) 'meu/org-typst-preview t))

(defun meu/org-typst--make-doc (body _display)
  "Cria documento Typst mínimo para BODY com fundo transparente."
  (concat
   "#set page(width: auto, height: auto, margin: 0pt, fill: none)\n"
   (format "#set text(size: 14pt, fill: rgb(\"%s\"))\n"
           (meu/org-typst--theme-fg))
   "$ " body " $"))

(defun meu/org-typst--compile-to-svg (body display)
  "Compila BODY como Typst para SVG.
DISPLAY indica se veio de math display ou inline."
  (make-directory meu/org-typst-preview-dir t)
  (let* ((doc (meu/org-typst--make-doc body display))
         (hash (secure-hash 'sha1
                            (concat doc
                                    (if display ":display:theme-v1" ":inline:theme-v1"))))
         (typ-file (expand-file-name (concat hash ".typ") meu/org-typst-preview-dir))
         (svg-file (expand-file-name (concat hash ".svg") meu/org-typst-preview-dir)))
    (unless (file-exists-p svg-file)
      (with-temp-file typ-file
        (insert doc))
      (meu/org-typst--buffer-output)
      (let ((exit-code
             (call-process "typst" nil "*org-typst-preview*" t
                           "compile" typ-file svg-file)))
        (unless (= exit-code 0)
          (meu/org-typst--delete-file-if-exists svg-file)
          (user-error "Erro Typst:\n%s"
                      (meu/org-typst--buffer-output)))))
    svg-file))

(defun meu/org-typst--overlay (beg end body display)
  "Cria overlay entre BEG e END com preview de BODY.
DISPLAY indica se é fórmula display."
  (let* ((svg (meu/org-typst--compile-to-svg body display))
         (display-spec
          `(image :type svg
            :file ,svg
            :ascent center))
         (ov (make-overlay beg end)))
    (overlay-put ov 'meu/org-typst-preview t)
    (overlay-put ov 'meu/org-typst-display display-spec)
    (overlay-put ov 'meu/org-typst-display-math display)
    (overlay-put ov 'display display-spec)
    (when display
      (overlay-put ov 'after-string "\n"))
    (overlay-put ov 'evaporate t)))


(defun meu/org-typst--strip-delimiters (value)
  "Remove delimitadores de math de VALUE. Devolve cons (BODY . DISPLAY)."
  (let ((v (string-trim value)))
    (cond
     ((string-prefix-p "$$" v)
      (cons (string-trim (substring v 2 -2)) t))
     ((string-prefix-p "$" v)
      (cons (string-trim (substring v 1 -1)) nil))
     ((string-prefix-p "\\[" v)
      (cons (string-trim (substring v 2 -2)) t))
     ((string-prefix-p "\\(" v)
      (cons (string-trim (substring v 2 -2)) nil))
     (t
      (cons v nil)))))

(defun meu/org-typst--previewable-fragment-p (body)
  "Retorna non-nil se BODY parece ser um fragmento Typst isolado."
  (and body
       (> (length body) 0)
       (not (string-match-p ":PROPERTIES:" body))
       ;; No Cardflow sidebar o Org parser pode apanhar texto truncado entre
       ;; dólares soltos e tentar compilá-lo como matemática.
       (not (and (string= (buffer-name) "*org-sidebar*")
                 (or (string-match-p "●" body)
                     (string-match-p "\n" body))))))

(defun meu/org-typst--line-in-table-p (pos)
  "Retorna non-nil se POS estiver numa linha de tabela Org."
  (save-excursion
    (goto-char pos)
    (beginning-of-line)
    (looking-at-p "[ \t]*|")))

(defun meu/org-typst--fallback-overlay (beg end label)
  "Esconde região BEG END com um fallback discreto LABEL."
  (let ((ov (make-overlay beg end)))
    (overlay-put ov 'meu/org-typst-preview t)
    (overlay-put ov 'display
                 (propertize label
                             'face
                             'font-lock-comment-face))
    (overlay-put ov 'evaporate t)))

(defun meu/org-typst-preview-buffer ()
  "Renderiza fragments Typst em fragments matemáticos Org."
  (interactive)
  (unless (derived-mode-p 'org-mode)
    (user-error "Isto é para org-mode"))

  (meu/org-typst-clear-previews)

  (org-element-map (org-element-parse-buffer) 'latex-fragment
    (lambda (frag)
      (let* ((value (org-element-property :value frag))
             (beg (org-element-property :begin frag))
             (end (save-excursion
                    (goto-char (org-element-property :end frag))
                    (skip-chars-backward " \t\r\n")
                    (point)))
             (parsed (meu/org-typst--strip-delimiters value))
             (body (car parsed))
             (display (cdr parsed)))
        (when (meu/org-typst--previewable-fragment-p body)
          (unless (and (string= (buffer-name) "*org-sidebar*")
                       (meu/org-typst--line-in-table-p beg))
            (condition-case err
                (meu/org-typst--overlay beg end body display)
              (error
               (if (and meu/org-typst-preview-silent-errors
                        (string= (buffer-name) "*org-sidebar*"))
                   (meu/org-typst--fallback-overlay beg end "[Typst]")
                 (unless meu/org-typst-preview-silent-errors
                   (message "Typst preview erro ignorado: %s" err)))))))))
  (meu/org-typst-preview-src-blocks)))


(defun meu/org-typst-toggle-preview ()
  "Liga/desliga previews Typst no buffer atual."
  (interactive)
  (if (cl-some (lambda (ov)
                 (overlay-get ov 'meu/org-typst-preview))
               (overlays-in (point-min) (point-max)))
      (meu/org-typst-clear-previews)
    (meu/org-typst-preview-buffer)))

(defun meu/org-typst-open-preview-at-point ()
  "Mostra o texto original se o cursor estiver num preview Typst."
  (interactive)
  (dolist (ov (overlays-at (point)))
    (when (overlay-get ov 'meu/org-typst-preview)
      (overlay-put ov 'display nil)
      (overlay-put ov 'meu/org-typst-open t))))

(defun meu/org-typst-close-open-previews ()
  "Fecha previews abertos quando o cursor sai deles, recompilando se mudou."
  (dolist (ov (overlays-in (point-min) (point-max)))
    (when (and (overlay-get ov 'meu/org-typst-preview)
               (overlay-get ov 'meu/org-typst-open)
               (not (and (>= (point) (overlay-start ov))
                         (<= (point) (overlay-end ov)))))
      (let* ((beg (overlay-start ov))
             (end (overlay-end ov))
             (raw (buffer-substring-no-properties beg end))
             (display (overlay-get ov 'meu/org-typst-display-math))
             (body
              (cond
               ((string-match-p "\\`\\$\\$" raw)
                (string-trim (substring raw 2 -2)))
               ((string-match-p "\\`\\$" raw)
                (string-trim (substring raw 1 -1)))
               (t raw))))
        (condition-case err
            (let ((new-display
                   `(image :type svg
                     :file ,(meu/org-typst--compile-to-svg body display)
                     :ascent center)))
              (overlay-put ov 'display new-display)
              (overlay-put ov 'meu/org-typst-display new-display)
              (overlay-put ov 'meu/org-typst-open nil))
          (error
           (overlay-put ov 'display nil)
           (overlay-put ov 'meu/org-typst-open t)
           (message "Typst preview mantém fonte por erro: %s"
                    (error-message-string err))))))))

(defun meu/org-typst-preview-post-command ()
  "Abrir preview no cursor e fechar previews fora do cursor."
  (meu/org-typst-close-open-previews)
  (meu/org-typst-open-preview-at-point))


(add-hook 'org-mode-hook
          (lambda ()
            (add-hook 'post-command-hook
                      #'meu/org-typst-preview-post-command
                      nil
                      t)

            ;; render automático ao abrir buffer
            (when (derived-mode-p 'org-mode)
              (run-with-idle-timer
               0.2 nil
               (lambda (buf)
                 (when (buffer-live-p buf)
                   (with-current-buffer buf
                     (meu/org-typst-preview-buffer))))
               (current-buffer)))))

(defun meu/org-typst--theme-fg ()
  "Devolve a cor foreground atual do tema em formato #RRGGBB."
  (let ((fg (face-attribute 'default :foreground nil t)))
    (if (and (stringp fg) (string-prefix-p "#" fg))
        fg
      "#ffffff")))

(defun meu/org-typst--theme-bg ()
  "Devolve a cor background atual do tema em formato #RRGGBB."
  (let ((bg (face-attribute 'default :background nil t)))
    (if (and (stringp bg) (string-prefix-p "#" bg))
        bg
      "#000000")))

(defun meu/org-typst-block-preamble ()
  "Preamble Typst usado automaticamente em blocos src typst."
  (let ((fg (meu/org-typst--theme-fg)))
    (format
     "#import \"@preview/cetz:0.3.3\"
#import \"@preview/cetz:0.3.3\": canvas, draw
#import \"@local/physics-draw:0.1.0\": *

#let theme-fg = rgb(\"%s\")

#set page(width: auto, height: auto, margin: 4pt, fill: none)
#set text(fill: theme-fg)

"
     fg)))

(defun meu/org-typst-preview-src-blocks ()
  "Renderiza blocos src typst como SVG inline."
  (interactive)
  (unless (derived-mode-p 'org-mode)
    (user-error "Isto é para org-mode"))

  (org-element-map (org-element-parse-buffer) 'src-block
    (lambda (block)
      (let ((lang (org-element-property :language block)))
        (when (and lang (string= (downcase lang) "typst"))
          (let* ((body (org-element-property :value block))
                 (beg (org-element-property :begin block))
                 (end (org-element-property :end block)))
            (condition-case err
                (let* ((svg (meu/org-typst--compile-src-block-to-svg body))
                       (display-spec
                        `(image :type svg
                          :file ,svg
                          :ascent center))
                       (ov (make-overlay beg end)))
                  (overlay-put ov 'meu/org-typst-preview t)
                  (overlay-put ov 'meu/org-typst-display display-spec)
                  (overlay-put ov 'display display-spec)
                  (overlay-put ov 'after-string "\n")
                  (overlay-put ov 'evaporate t))
              (error
               (if (and meu/org-typst-preview-silent-errors
                        (string= (buffer-name) "*org-sidebar*"))
                   (meu/org-typst--fallback-overlay beg end "[bloco Typst]")
                 (unless meu/org-typst-preview-silent-errors
                   (message "Typst src preview erro ignorado: %s" err)))))))))))

(defun meu/org-typst--compile-src-block-to-svg (body)
  "Compila BODY de um bloco src typst para SVG."
  (make-directory meu/org-typst-preview-dir t)
  (let* ((full-body (concat (meu/org-typst-block-preamble) body))
         (hash (secure-hash 'sha1 full-body))
         (typ-file (expand-file-name
                    (concat "src-" hash ".typ")
                    meu/org-typst-preview-dir))
         (svg-file (expand-file-name
                    (concat "src-" hash ".svg")
                    meu/org-typst-preview-dir)))
    (unless (file-exists-p svg-file)
      (with-temp-file typ-file
        (insert full-body))
      (meu/org-typst--buffer-output)
      (let ((exit-code
             (call-process "typst" nil "*org-typst-preview*" t
                           "compile" typ-file svg-file)))
        (unless (= exit-code 0)
          (meu/org-typst--delete-file-if-exists svg-file)
          (user-error "Erro Typst src block:\n%s"
                      (meu/org-typst--buffer-output)))))
    svg-file))

(provide 'org-typst-preview)

;;; org-typst-preview.el ends here
