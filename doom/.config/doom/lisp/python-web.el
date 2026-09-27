;;; lisp/python-web.el -*- lexical-binding: t; -*-

;; Python + HTML/CSS, adaptado dos dotfiles do dunossauro
;; (dotfiles-main/dotfiles/emacs.d/config/{lsp,code,html}-config.el).
;;
;; Ferramentas (fora do Emacs):
;;   mise use -g uv@latest node@lts
;;   uv tool install ruff && uv tool install zuban && uv tool install rassumfrassum
;;   npm i -g vscode-langservers-extracted   # html/css/json LSP

;; O Emacs de GUI nao herda o PATH do fish: uv tools ficam em ~/.local/bin e o
;; node/npm globais nos shims do mise.
(dolist (dir (list (expand-file-name "~/.local/share/mise/shims")
                   (expand-file-name "~/.local/bin")))
  (when (file-directory-p dir)
    (add-to-list 'exec-path dir)
    (setenv "PATH" (concat dir ":" (getenv "PATH")))))

;;; Python

;; Como o dunossauro: `rass' (rassumfrassum) junta varios LSPs num so.
;; zuban -> completions, tipos, go-to-definition, rename
;; ruff  -> lint e format
(after! eglot
  (add-to-list 'eglot-server-programs
               '((python-mode python-ts-mode)
                 . ("rass" "--quiet-server" "--" "zuban" "server" "--" "ruff" "server"))))

;; Ativa a .venv do projeto antes do eglot arrancar, para o zuban ver os
;; pacotes instalados (o `lsp!' do modulo python corre em 'append, depois deste).
(defun fabio/python-activate-project-venv-h ()
  (when-let* ((root (locate-dominating-file default-directory ".venv"))
              (venv (expand-file-name ".venv" root)))
    (when (file-directory-p venv)
      (pyvenv-activate venv))))

(add-hook 'python-mode-local-vars-hook #'fabio/python-activate-project-venv-h)
(add-hook 'python-ts-mode-local-vars-hook #'fabio/python-activate-project-venv-h)

;; PEP 8: regua nos 79 caracteres.
(setq-hook! '(python-mode-hook python-ts-mode-hook) fill-column 79)
(add-hook 'python-base-mode-hook #'display-fill-column-indicator-mode)

;; Format on save com ruff (quando o LSP nao estiver ativo).
(after! apheleia
  (setf (alist-get 'python-mode apheleia-mode-alist) '(ruff-isort ruff)
        (alist-get 'python-ts-mode apheleia-mode-alist) '(ruff-isort ruff)))

;;; Documentacao em popup (eldoc-box, como no config do dunossauro)

(use-package! eldoc-box
  :after eglot
  :custom
  (eldoc-box-max-pixel-width 600)
  (eldoc-box-max-pixel-height 400)
  :config
  (map! :map eglot-mode-map
        :n "g h" #'eldoc-box-help-at-point))

;;; HTML / CSS

;; O modulo `web' ja traz web-mode + emmet (TAB expande `div.card>ul>li*3').
;; Aqui fica o preview ao vivo do dunossauro: impatient-mode + simple-httpd.
(defun fabio/html-live-preview ()
  "Abre o buffer atual no browser, atualizando a cada tecla."
  (interactive)
  (require 'impatient-mode)
  (httpd-start)
  (impatient-mode 1)
  (browse-url (format "http://localhost:%d/imp/live/%s/"
                      httpd-port (url-hexify-string (buffer-name)))))

(map! :after web-mode
      :map web-mode-map
      :localleader
      :desc "Preview ao vivo" "v" #'fabio/html-live-preview)
