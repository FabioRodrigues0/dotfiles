;;; org-config.el -*- lexical-binding: t; -*-

(after! org
  ;; -----------------------------
  ;; Org-Modern
  ;; -----------------------------
  (add-hook 'org-mode-hook #'org-modern-mode)
  (add-hook 'org-agenda-finalize-hook #'org-modern-agenda)

  (setq org-modern-star 'replace
        org-modern-hide-stars nil
        org-modern-table nil
        org-modern-todo t
        org-modern-tag t
        org-modern-priority t
        org-modern-block-fringe nil)
  ;; -----------------------------
  ;; Agenda
  ;; -----------------------------
  (setq org-directory "~/org/")
  (map! :leader
        :desc "Org Capture"
        "x" #'org-capture)
  (setq org-agenda-files '("~/Documents/into_sparta_life/00_jornal/inbox.org"
                           "~/Documents/into_sparta_life/00_jornal/tarefas.org"
                           "~/Documents/into_sparta_life/00_jornal/habitos.org"
                           "~/Documents/into_sparta_life/00_jornal/agenda.org"))

  ;; Estados de uma tarefa
  (setq org-todo-keywords
        '((sequence "TODO(t)" "EM CURSO(e)" "À ESPERA(a)" "|" "FEITO(f)" "CANCELADO(c)")))

  ;; Captura rápida (SPC X no Doom)
  (setq org-capture-templates
        '(("t" "Tarefa" entry (file "~/org/tarefas.org")
           "* TODO %?\n  %U\n")
          ("e" "Evento" entry (file "~/org/agenda.org")
           "* %?\n  %^T\n")
          ("n" "Nota rápida" entry (file "~/org/inbox.org")
           "* %?\n  %U\n")))

  ;; -----------------------------
  ;; Agenda visual simples
  ;; -----------------------------

  (setq org-agenda-span 'week
        org-agenda-start-on-weekday 1
        org-agenda-start-day nil
        org-agenda-use-time-grid nil
        org-deadline-warning-days 7
        org-agenda-skip-scheduled-if-done t
        org-agenda-skip-deadline-if-done t
        org-agenda-skip-timestamp-if-done t)

  ;; -----------------------------
  ;; Org Super Agenda
  ;; -----------------------------

  (use-package! org-super-agenda
    :after org-agenda
    :config
    (org-super-agenda-mode 1)

    ;; helpers para filtrar datas
    (defun meu/org-agenda--today ()
      "Dia atual em formato absoluto do calendário."
      (calendar-absolute-from-gregorian (calendar-current-date)))

    (defun meu/org-agenda--date-diff (prop)
      "Diferença em dias entre hoje e a data da propriedade PROP."
      (when-let ((value (org-entry-get nil prop)))
        (- (org-time-string-to-absolute value)
           (meu/org-agenda--today))))

    (defun meu/org-agenda-skip-not-alert ()
      "Ignora tarefas que não são alertas relevantes."
      (let ((deadline-diff (meu/org-agenda--date-diff "DEADLINE"))
            (scheduled-diff (meu/org-agenda--date-diff "SCHEDULED")))
        (if (or
             ;; deadline atrasada ou até 7 dias
             (and deadline-diff
                  (<= deadline-diff 7))

             ;; scheduled atrasado ou até 2 dias
             (and scheduled-diff
                  (<= scheduled-diff 2)))
            nil
          (or (outline-next-heading) (point-max)))))

    (setq org-agenda-custom-commands
          '(("e" "Estudo - semana + alertas + tarefas sem data"

             ;; 1. Agenda semanal normal
             ((agenda ""
                      ((org-agenda-overriding-header "Semana")
                       (org-agenda-span 'week)
                       (org-agenda-start-on-weekday 1)
                       (org-agenda-start-day nil)
                       (org-agenda-use-time-grid nil)

                       ;; evita prewarnings repetidos na semana
                       (org-deadline-warning-days 0)

                       ;; sem grupos super-agenda aqui
                       (org-super-agenda-groups nil)))

              ;; 2. Alertas só uma vez
              (alltodo ""
                       ((org-agenda-overriding-header "Alertas de hoje")
                        (org-agenda-skip-function
                         #'meu/org-agenda-skip-not-alert)

                        (org-super-agenda-groups
                         '((:name "Atrasado"
                            :deadline past
                            :scheduled past
                            :face error)

                           (:name "A acabar em breve"
                            :deadline future
                            :face warning)

                           (:name "Agendado em breve"
                            :scheduled future
                            :face warning)

                           (:discard (:anything t))))))

              ;; 3. Tarefas sem data
              (alltodo ""
                       ((org-agenda-overriding-header "Tarefas sem data")

                        ;; só TODOs sem SCHEDULED nem DEADLINE
                        (org-agenda-skip-function
                         '(org-agenda-skip-entry-if 'scheduled 'deadline))

                        (org-super-agenda-groups
                         '((:name "Projetos"
                            :tag "projects")

                           (:name "Faculdade"
                            :tag ("AM2" "FIS" "SO" "BD"))

                           (:name "Outras tarefas"
                            :todo "TODO")

                           (:discard (:anything t))))))))))))

(defun meu/org-convert-latex-delimiters-to-dollar ()
  "Converte \\(...\\) para $...$ e \\[...\\] para $$...$$ no buffer Org atual.
Ignora blocos de código porque usa o parser do Org."
  (interactive)
  (unless (derived-mode-p 'org-mode)
    (user-error "Este comando é para org-mode"))

  (require 'org-element)

  (let (fragments)
    ;; Recolher fragments primeiro
    (org-element-map (org-element-parse-buffer) 'latex-fragment
      (lambda (frag)
        (let ((value (org-element-property :value frag))
              (beg (org-element-property :begin frag))
              (end (save-excursion
                     (goto-char (org-element-property :end frag))
                     (skip-chars-backward " \t\r\n")
                     (point))))
          (push (list beg end value) fragments))))

    ;; Substituir de trás para a frente para não estragar posições
    (setq fragments
          (sort fragments
                (lambda (a b) (> (car a) (car b)))))

    (save-excursion
      (dolist (frag fragments)
        (pcase-let ((`(,beg ,end ,value) frag))
          (let ((v (string-trim value)))
            (cond
             ;; \[ ... \] -> $$ ... $$
             ((and (string-prefix-p "\\[" v)
                   (string-suffix-p "\\]" v))
              (let ((body (string-trim (substring v 2 -2))))
                (goto-char beg)
                (delete-region beg end)
                (insert "$$\n" body "\n$$")))

             ;; \( ... \) -> $ ... $
             ((and (string-prefix-p "\\(" v)
                   (string-suffix-p "\\)" v))
              (let ((body (string-trim (substring v 2 -2))))
                (goto-char beg)
                (delete-region beg end)
                (insert "$" body "$")))))))))

  (message "Conversão de delimitadores concluída."))
(defun meu/org-normalize-inline-dollar-math ()
  "Remove espaços internos em fragments inline $ ... $ para ficarem $...$."
  (interactive)
  (unless (derived-mode-p 'org-mode)
    (user-error "Este comando é para org-mode"))

  (save-excursion
    (goto-char (point-min))

    ;; apanha apenas inline math numa linha, não $$...$$
    (while (re-search-forward "\\(^\\|[^$]\\)\\$[ \t]+\\([^$\n]+?\\)[ \t]+\\$" nil t)
      (unless (org-in-src-block-p t)
        (let ((prefix (match-string 1))
              (body (string-trim (match-string 2)))
              (beg (match-beginning 0))
              (end (match-end 0)))
          (goto-char beg)
          (delete-region beg end)
          (insert prefix "$" body "$"))))))

(message "Inline math normalizado.")
