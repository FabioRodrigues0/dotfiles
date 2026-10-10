;;; org-config.el -*- lexical-binding: t; -*-

(after! org
  ;; -----------------------------
  ;; Org-Modern
  ;; -----------------------------
  (add-hook 'org-mode-hook #'org-modern-mode)

  (setq org-modern-star 'replace
        org-modern-hide-stars nil
        org-modern-table nil
        org-modern-todo t
        org-modern-tag t
        org-modern-priority t
        org-modern-block-fringe nil))
