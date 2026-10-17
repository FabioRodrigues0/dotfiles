;;; lisp/diagnosticos.el -*- lexical-binding: t; -*-

;; Erros/avisos do flycheck (eglot via flycheck-eglot) mostrados no fim de
;; cada linha, a ocupar o espaco vazio a direita do fill-column.

(use-package! flyover
  :hook (flycheck-mode . flyover-mode)
  :config
  (setq flyover-checkers '(flycheck)
        flyover-levels '(error warning info)
        flyover-show-at-eol t
        flyover-show-virtual-line nil
        flyover-show-error-id t      ; ex. [E402], util para o "# noqa"
        flyover-wrap-messages nil    ; uma linha so, nao empurra o codigo
        flyover-display-mode 'always))

;; Em modo insert as mensagens desaparecem para nao distrair; voltam ao sair.
(defvar-local +flyover--pausado nil)

(defun +flyover-pausar-h ()
  (when (bound-and-true-p flyover-mode)
    (setq +flyover--pausado t)
    (flyover-mode -1)))

(defun +flyover-retomar-h ()
  (when +flyover--pausado
    (setq +flyover--pausado nil)
    (flyover-mode 1)))

(add-hook 'evil-insert-state-entry-hook #'+flyover-pausar-h)
(add-hook 'evil-insert-state-exit-hook #'+flyover-retomar-h)
