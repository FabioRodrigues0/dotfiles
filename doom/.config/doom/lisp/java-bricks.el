;;; lisp/java-bricks.el -*- lexical-binding: t; -*-

;; Bricks (~/Documents/into_sparta_life_old/01_projects/bricks), a minha lib
;; Java estilo Compose sobre JavaFX.
;;
;; - Snippets `b...' em snippets/java-mode (tambem no java-ts-mode): cada um
;;   chama `fabio/bricks-import' e o import entra logo no topo do ficheiro.
;; - Muitos nomes do Bricks colidem com JavaFX/AWT/JDK (Button, Text, Image,
;;   Modifier, Effect, Calendar...): o jdtls oferecia esses primeiro e o
;;   organize imports nao escolhia nenhum. Em projetos que dependem do Bricks,
;;   `fabio/bricks-jdtls-config' esconde esses tipos da completacao e do
;;   organize imports.
;; - Se mesmo assim nao aparecer nada do Bricks: confirmar o `requires
;;   fabiorodrigues.bricks;' no module-info.java (snippet `bmodule').

(require 'cl-lib)

;;; Imports a partir dos snippets

(defvar-local fabio/bricks--imports-pendentes nil)

(defun fabio/bricks--tem-import-p (classe)
  "Non-nil se CLASSE (nome completo) ja esta importada ou no mesmo pacote."
  (let ((pacote (file-name-sans-extension classe)))
    (save-excursion
      (goto-char (point-min))
      (or (re-search-forward
           (format "^import[ \t]+\\(%s\\|%s\\.\\*\\)[ \t]*;"
                   (regexp-quote classe) (regexp-quote pacote))
           nil t)
          (re-search-forward
           (format "^package[ \t]+%s[ \t]*;" (regexp-quote pacote))
           nil t)))))

(defun fabio/bricks--inserir-import (classe)
  "Insere `import CLASSE;' depois do ultimo import (ou do package)."
  (unless (fabio/bricks--tem-import-p classe)
    (save-excursion
      (goto-char (point-min))
      (let ((ultimo nil))
        (while (re-search-forward "^import[ \t].*;[ \t]*$" nil t)
          (setq ultimo (point)))
        (cond (ultimo
               (goto-char ultimo)
               (insert "\nimport " classe ";"))
              ((re-search-forward "^package[ \t].*;[ \t]*$" nil t)
               (insert "\n\nimport " classe ";"))
              (t
               (goto-char (point-min))
               (insert "import " classe ";\n\n")))))))

(defun fabio/bricks--aplicar-imports (buf)
  (when (buffer-live-p buf)
    (with-current-buffer buf
      (let ((classes (reverse fabio/bricks--imports-pendentes)))
        (setq fabio/bricks--imports-pendentes nil)
        (mapc #'fabio/bricks--inserir-import classes)))))

(defun fabio/bricks-import (&rest classes)
  "Importa CLASSES e devolve \"\".
Nomes do Bricks podem vir curtos (\"components.Column\"); os outros
completos (\"java.util.List\").
Para usar em snippets como `(fabio/bricks-import ...)`. Os imports so
entram depois de o snippet ser expandido: mexer no buffer a meio da
expansao estragava as posicoes do yasnippet."
  (dolist (c classes)
    (let ((completa (if (string-match-p "\\`\\(core\\|components\\|style\\|data\\)\\." c)
                        (concat "fabiorodrigues.bricks." c)
                      c)))
      (cl-pushnew completa fabio/bricks--imports-pendentes :test #'equal)))
  (run-at-time 0 nil #'fabio/bricks--aplicar-imports (current-buffer))
  "")

;;; jdtls: esconder os tipos que colidem com o Bricks

(defconst fabio/bricks--tipos-filtrados
  [;; Valores por defeito do jdtls (o setting substitui-os, nao acrescenta)
   "java.awt.*" "com.sun.*" "sun.*" "jdk.*" "org.graalvm.*"
   "io.micrometer.shaded.*"
   ;; Colidem com nomes do Bricks
   "javafx.scene.control.*"           ; Button, TextField, Checkbox, Slider...
   "javafx.scene.text.Text"
   "javafx.scene.image.Image"
   "javafx.scene.effect.*"            ; Effect
   "javax.swing.*"                    ; Icon, Box, Spacer...
   "javax.management.*"               ; Notification
   "java.lang.reflect.Modifier"
   "java.lang.Thread.State"
   "java.util.Calendar"]
  "java.completion.filteredTypes em projetos que usam o Bricks.")

(defvar fabio/bricks--cache-projetos (make-hash-table :test #'equal))

(defun fabio/bricks-projeto-p (raiz)
  "Non-nil se o projeto em RAIZ depende do Bricks.
A propria lib nao conta (precisa dos tipos JavaFX que aqui se escondem)."
  (let ((raiz (file-name-as-directory (expand-file-name raiz))))
    (pcase (gethash raiz fabio/bricks--cache-projetos 'nao-visto)
      ('nao-visto
       (puthash raiz (fabio/bricks--detetar raiz) fabio/bricks--cache-projetos))
      (v v))))

(defun fabio/bricks--detetar (raiz)
  (let ((case-fold-search t))
    (cl-some
     (lambda (par)
       (let ((f (expand-file-name (car par) raiz)))
         (when (file-readable-p f)
           (with-temp-buffer
             (insert-file-contents f)
             (re-search-forward (cdr par) nil t)))))
     '(("build.gradle" . "fabiorodrigues0?:bricks:")
       ("build.gradle.kts" . "fabiorodrigues0?:bricks:")
       ("pom.xml" . "<dependency>[ \t\n]*<groupId>[^<]*fabiorodrigues[^<]*</groupId>[ \t\n]*<artifactId>bricks</artifactId>")
       ("src/main/java/module-info.java" . "requires[ \t]+\\(transitive[ \t]+\\)?fabiorodrigues\\.bricks")))))

(defun fabio/bricks-jdtls-config (server)
  "Parte :java do `eglot-workspace-configuration' para SERVER."
  (when-let* ((proj (eglot--project server))
              ((fabio/bricks-projeto-p (project-root proj))))
    `(:java (:completion (:filteredTypes ,fabio/bricks--tipos-filtrados)))))
