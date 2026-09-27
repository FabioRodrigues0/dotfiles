;;; lisp/java-csharp.el -*- lexical-binding: t; -*-

;; Java e C# ao estilo de lisp/python-web.el. O LSP (jdtls, csharp-ls) e o
;; format on save (spotless/google-java-format, csharpier) ficam no config.el
;; e no Doom; `g h' (eldoc-box) ja funciona em qualquer buffer com eglot.
;;
;; Ferramentas (fora do Emacs):
;;   dotnet tool install -g csharpier

;; Regua como no Python: 80 no Java (checkstyle sun_checks do `novo java'),
;; 100 no C# (largura por defeito do csharpier).
(setq-hook! '(java-mode-hook java-ts-mode-hook) fill-column 80)
(setq-hook! '(csharp-mode-hook csharp-ts-mode-hook) fill-column 100)
(add-hook! '(java-mode-hook java-ts-mode-hook csharp-mode-hook csharp-ts-mode-hook)
           #'display-fill-column-indicator-mode)

;; Correr o projeto a partir do Emacs com a funcao `correr' do fish
;; (Gradle, Maven, dotnet, Python...). Em comint para o Scanner/ReadLine
;; conseguirem ler input.
(defun fabio/correr ()
  "Corre o projeto do ficheiro atual com `correr' (fish)."
  (interactive)
  (save-some-buffers t)
  (compile "correr" t))

(map! :after cc-mode :map java-mode-map
      :localleader :desc "Correr projeto" "r" #'fabio/correr)
(map! :after csharp-mode :map csharp-mode-map
      :localleader :desc "Correr projeto" "r" #'fabio/correr)
(map! :after python :map python-base-mode-map
      :localleader :desc "Correr projeto" "r" #'fabio/correr)
