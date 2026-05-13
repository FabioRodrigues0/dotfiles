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
  (setq org-agenda-files '("~/org/inbox.org"
                           "~/org/tarefas.org"
                           "~/org/habitos.org"
                           "~/org/agenda.org"))

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
