;;; lisp/java-gerar.el -*- lexical-binding: t; -*-

;; Java ao estilo do IntelliJ, com o jdtls via eglot:
;;
;; - `SPC c g' (Alt+Insert): menu so com os "Generate..." do jdtls: getters e
;;   setters, toString, equals/hashCode, construtores, override/implementar
;;   metodos. Os que no VS Code abrem uma janela para escolher campos ou
;;   metodos perguntam aqui no minibuffer (RET vazio = todos).
;; - Ao gravar um .java, organiza os imports (tira os que nao se usam, junta
;;   os que faltam e ordena), como o "Optimize imports on the fly".
;;
;; O jdtls so oferece toString/equals/construtores/override se o cliente
;; disser que sabe mostrar essa escolha: e o que `fabio/jdtls-init-options'
;; anuncia (usado no `eglot-server-programs' do config.el). Os pedidos
;; java/check*Status e java/generate* sao os mesmos que o vscode-java usa.

(require 'cl-lib)

(defvar fabio/jdtls-init-options
  '(:extendedClientCapabilities
    (:generateToStringPromptSupport t
     :hashCodeEqualsPromptSupport t
     :generateConstructorsPromptSupport t
     :overrideMethodsPromptSupport t))
  "initializationOptions para o jdtls ativar os Generate com escolha.")

;;; Escolhas no minibuffer

(defun fabio/java--escolher (prompt itens nome-fn &optional pre)
  "Escolhe varios de ITENS (vetor) por NOME-FN.
RET vazio devolve PRE, os que o jdtls marca com isSelected, ou todos."
  (let* ((lista (append itens nil))
         (pre (or pre (cl-remove-if-not (lambda (i) (eq (plist-get i :isSelected) t))
                                        lista)))
         (nomes (mapcar nome-fn lista))
         (escolha (completing-read-multiple
                   (format "%s (RET vazio = %s): " prompt (if pre "sugeridos" "todos"))
                   nomes nil t)))
    (vconcat (if escolha
                 (cl-remove-if-not (lambda (i) (member (funcall nome-fn i) escolha)) lista)
               (or pre lista)))))

(defun fabio/java--campo (f)
  (format "%s %s" (plist-get f :type) (plist-get f :name)))

(defun fabio/java--metodo (m)
  (format "%s(%s)  — %s" (plist-get m :name)
          (string-join (append (plist-get m :parameters) nil) ", ")
          (plist-get m :declaringClass)))

;;; Comandos "Prompt" do jdtls

(defun fabio/java--formatar-alteracoes (fn)
  "Chama FN e formata so o texto que ela mudou no buffer.
O jdtls gera com tabs e sem linhas em branco entre metodos; o
`eglot-format' usa os espacos do buffer e o estilo do projeto."
  (let (ini fim)
    (let ((after-change-functions
           (cons (lambda (b e _)
                   (if ini
                       (progn (when (< b ini) (set-marker ini b))
                              (when (> e fim) (set-marker fim e)))
                     (setq ini (copy-marker b) fim (copy-marker e t))))
                 after-change-functions)))
      (funcall fn))
    (when ini
      (condition-case nil
          ;; O eglot passa o `tab-width' como tamanho do tab ao formatador.
          (let ((tab-width (if (and (boundp 'c-basic-offset) (integerp c-basic-offset))
                               c-basic-offset
                             4)))
            (eglot-format ini fim))
        (error nil))
      (fabio/java--separar-membros ini fim)
      (set-marker ini nil)
      (set-marker fim nil))))

(defun fabio/java--separar-membros (ini fim)
  "Linha em branco entre membros (e depois dos imports) entre INI e FIM.
Olha tambem para a linha antes de INI, para separar do campo anterior."
  (save-excursion
    (goto-char ini)
    (forward-line -1)
    (while (and (< (point) fim) (not (eobp)))
      (if (and (looking-at-p ".*[;}][ \t]*$")
               (save-excursion
                 (forward-line 1)
                 ;; Anotacao, ou metodo/classe (abre `{'); campos seguidos ficam juntos.
                 (looking-at-p "[ \t]*\\(@\\|\\(public\\|protected\\|private\\)\\_>.*{[ \t]*$\\)")))
          (progn (end-of-line) (insert "\n") (forward-line 1))
        (forward-line 1)))))

(defun fabio/java--aplicar (server edit)
  (when edit
    (fabio/java--formatar-alteracoes
     (lambda () (eglot--apply-workspace-edit server edit this-command)))))

(defun fabio/java--tostring (server ctx)
  (let ((st (eglot--request server :java/checkToStringStatus ctx)))
    (when (or (eq (plist-get st :exists) :json-false)
              (null (plist-get st :exists))
              (y-or-n-p (format "%s ja tem toString(). Substituir? " (plist-get st :type))))
      (fabio/java--aplicar
       server (eglot--request
               server :java/generateToString
               `(:context ,ctx
                 :fields ,(fabio/java--escolher "Campos no toString"
                                                (plist-get st :fields) #'fabio/java--campo)))))))

(defun fabio/java--hashcode-equals (server ctx)
  (let* ((st (eglot--request server :java/checkHashCodeEqualsStatus ctx))
         (existentes (append (plist-get st :existingMethods) nil)))
    (when (or (null existentes)
              (y-or-n-p (format "%s ja tem %s. Substituir? " (plist-get st :type)
                                (string-join existentes " e "))))
      (fabio/java--aplicar
       server (eglot--request
               server :java/generateHashCodeEquals
               `(:context ,ctx
                 :fields ,(fabio/java--escolher "Campos no equals/hashCode"
                                                (plist-get st :fields) #'fabio/java--campo)
                 :regenerate ,(if existentes t :json-false)))))))

(defun fabio/java--construtores (server ctx)
  (let* ((st (eglot--request server :java/checkConstructorsStatus ctx))
         (supers (append (plist-get st :constructors) nil))
         (super (if (cdr supers)
                    (let ((nomes (mapcar #'fabio/java--metodo supers)))
                      (nth (cl-position (completing-read "Construtor do super: " nomes nil t)
                                        nomes :test #'equal)
                           supers))
                  (car supers)))
         (campos (plist-get st :fields)))
    (fabio/java--aplicar
     server (eglot--request
             server :java/generateConstructors
             `(:context ,ctx
               :constructors ,(if super (vector super) [])
               :fields ,(if (seq-empty-p campos)
                            []
                          (fabio/java--escolher "Campos no construtor" campos
                                                #'fabio/java--campo
                                                (append campos nil))))))))

(defun fabio/java--override (server ctx)
  (let* ((st (eglot--request server :java/listOverridableMethods ctx))
         (metodos (plist-get st :methods))
         (por-implementar (cl-remove-if-not
                           (lambda (m) (eq (plist-get m :unimplemented) t))
                           (append metodos nil))))
    (fabio/java--aplicar
     server (eglot--request
             server :java/addOverridableMethods
             `(:context ,ctx
               :overridableMethods ,(fabio/java--escolher
                                     "Métodos" metodos #'fabio/java--metodo
                                     por-implementar))))))

(defvar fabio/java--comandos
  '(("java.action.generateToStringPrompt" . fabio/java--tostring)
    ("java.action.hashCodeEqualsPrompt" . fabio/java--hashcode-equals)
    ("java.action.generateConstructorsPrompt" . fabio/java--construtores)
    ("java.action.overrideMethodsPrompt" . fabio/java--override))
  "Comandos que o jdtls espera que o cliente trate (no VS Code abrem uma janela).")

(with-eval-after-load 'eglot
  (cl-defmethod eglot-execute :around (server action)
    "Trata os comandos java.action.*Prompt do jdtls no minibuffer."
    (if-let* ((cmd (plist-get action :command))
              ((stringp cmd))
              (fn (cdr (assoc cmd fabio/java--comandos))))
        (funcall fn server (aref (plist-get action :arguments) 0))
      (cl-call-next-method))))

;;; Menu Generate (Alt+Insert)

(defun fabio/java-gerar ()
  "Menu com os Generate/Override do jdtls no ponto, como o Alt+Insert."
  (interactive)
  (eglot-server-capable-or-lose :codeActionProvider)
  (let* ((server (eglot--current-server-or-lose))
         (bounds (if (use-region-p)
                     (list (region-beginning) (region-end))
                   (list (point) (point))))
         (acoes (eglot--request
                 server :textDocument/codeAction
                 (eglot--code-action-params :beg (car bounds) :end (cadr bounds))))
         (acoes (cl-loop for a across acoes
                         for titulo = (plist-get a :title)
                         for tipo = (or (plist-get a :kind) "")
                         when (or (string-prefix-p "source.generate" tipo)
                                  (string-prefix-p "source.overrideMethods" tipo)
                                  (string-match-p "\\`\\(Generate\\|Override\\|Add unimplemented\\)"
                                                  titulo))
                         collect (cons titulo a)))
         ;; O jdtls as vezes repete o mesmo titulo (Generate Constructors...).
         (acoes (cl-remove-duplicates acoes :key #'car :test #'equal :from-end t)))
    (unless acoes
      (user-error "Nada para gerar aqui (poe o cursor dentro da classe)"))
    (let ((acao (cdr (assoc (completing-read "Gerar: " acoes nil t) acoes))))
      (fabio/java--formatar-alteracoes (lambda () (eglot-execute server acao))))))

;;; Organizar imports ao gravar

(defun fabio/java-organizar-imports ()
  "Organiza os imports do buffer (tira, junta e ordena)."
  (interactive)
  (when-let* ((server (eglot-current-server))
              (acoes (eglot--request
                      server :textDocument/codeAction
                      (eglot--code-action-params :beg (point-min) :end (point-min)
                                                 :only "source.organizeImports"))))
    (cl-loop for a across acoes
             when (equal (plist-get a :kind) "source.organizeImports")
             do (fabio/java--formatar-alteracoes (lambda () (eglot-execute server a))))))

(defun fabio/java-organizar-imports-ao-gravar-h ()
  (when (derived-mode-p 'java-mode 'java-ts-mode)
    (if (eglot-managed-p)
        (add-hook 'before-save-hook #'fabio/java--organizar-silencioso nil t)
      (remove-hook 'before-save-hook #'fabio/java--organizar-silencioso t))))

(defun fabio/java--organizar-silencioso ()
  ;; Nunca impedir a gravacao por causa do jdtls.
  (condition-case err
      (fabio/java-organizar-imports)
    (error (message "Organizar imports falhou: %s" (error-message-string err)))))

(add-hook 'eglot-managed-mode-hook #'fabio/java-organizar-imports-ao-gravar-h)

(map! :after cc-mode :map java-mode-map
      :leader
      :desc "Gerar (Alt+Insert)" "c g" #'fabio/java-gerar
      :desc "Organizar imports" "c o" #'fabio/java-organizar-imports)
(map! :after java-ts-mode :map java-ts-mode-map
      :leader
      :desc "Gerar (Alt+Insert)" "c g" #'fabio/java-gerar
      :desc "Organizar imports" "c o" #'fabio/java-organizar-imports)
