;;; lisp/navegar-indentacao.el -*- lexical-binding: t; -*-

;; Navegar pelo codigo por niveis de indentacao, como o Cardflow fazia com os
;; headings do Org. So no modo normal do evil; no insert as setas sao as normais.
;;
;;   <down>   proxima linha ao mesmo nivel (irmao), sem sair do bloco pai
;;   <up>     linha anterior ao mesmo nivel
;;   <right>  entra no bloco: primeira linha mais indentada logo a seguir
;;   <left>   sai do bloco: linha de cima com menos indentacao (pai)
;;
;; Linhas em branco e linhas so com fechos (`}', `)', `];' ...) sao ignoradas,
;; senao o `}' de um bloco contava como irmao da linha que o abre.
;; `SPC t n' liga/desliga no buffer atual.

(defvar fabio/navegar-indentacao-ignorar
  "^[ \t]*\\(?:[])}]+[;,]?\\)?[ \t]*$"
  "Linhas que nao contam como nodes: vazias ou so com fechos.")

(defun fabio/navegar-indentacao--node-p ()
  "Non-nil se a linha atual conta para a navegacao."
  (save-excursion
    (beginning-of-line)
    (not (looking-at-p fabio/navegar-indentacao-ignorar))))

(defun fabio/navegar-indentacao--procurar (dir parar-p aceitar-p)
  "Anda linha a linha na direcao DIR (1 ou -1) a partir da linha atual.
Para cada node chama ACEITAR-P e PARAR-P com a indentacao dele e a da linha
de partida. Devolve a posicao do primeiro aceite, ou nil se PARAR-P vier
primeiro ou o buffer acabar."
  (let ((origem (current-indentation))
        resultado)
    (save-excursion
      (while (and (not resultado)
                  (zerop (forward-line dir)))
        (when (fabio/navegar-indentacao--node-p)
          (let ((ind (current-indentation)))
            (cond
             ((funcall aceitar-p ind origem)
              (back-to-indentation)
              (setq resultado (point)))
             ((funcall parar-p ind origem)
              (setq resultado 'parar)))))))
    (and (integerp resultado) resultado)))

(defun fabio/navegar-indentacao--ir (pos msg)
  (if pos
      (progn (evil-set-jump) (goto-char pos))
    (message "%s" msg)))

(defun fabio/navegar-indentacao-proximo ()
  "Proxima linha ao mesmo nivel de indentacao, dentro do mesmo bloco."
  (interactive)
  (fabio/navegar-indentacao--ir
   (fabio/navegar-indentacao--procurar 1 #'< #'=)
   "Ultimo deste nivel"))

(defun fabio/navegar-indentacao-anterior ()
  "Linha anterior ao mesmo nivel de indentacao, dentro do mesmo bloco."
  (interactive)
  (fabio/navegar-indentacao--ir
   (fabio/navegar-indentacao--procurar -1 #'< #'=)
   "Primeiro deste nivel"))

(defun fabio/navegar-indentacao-entrar ()
  "Primeira linha mais indentada logo a seguir (entrar no bloco)."
  (interactive)
  (fabio/navegar-indentacao--ir
   (fabio/navegar-indentacao--procurar 1 #'<= #'>)
   "Sem bloco para entrar"))

(defun fabio/navegar-indentacao-sair ()
  "Linha de cima com menos indentacao (sair para o bloco pai)."
  (interactive)
  (fabio/navegar-indentacao--ir
   (fabio/navegar-indentacao--procurar -1 #'ignore #'<)
   "Ja no nivel de topo"))

(defvar fabio/navegar-indentacao-mode-map (make-sparse-keymap))

(define-minor-mode fabio/navegar-indentacao-mode
  "Setas no modo normal navegam por niveis de indentacao."
  :lighter " ⇅"
  :keymap fabio/navegar-indentacao-mode-map
  (evil-normalize-keymaps))

(map! :map fabio/navegar-indentacao-mode-map
      :n "<down>"  #'fabio/navegar-indentacao-proximo
      :n "<up>"    #'fabio/navegar-indentacao-anterior
      :n "<right>" #'fabio/navegar-indentacao-entrar
      :n "<left>"  #'fabio/navegar-indentacao-sair)

(map! :leader
      :desc "Navegar por indentacao" "t n" #'fabio/navegar-indentacao-mode)

(add-hook 'prog-mode-hook #'fabio/navegar-indentacao-mode)
