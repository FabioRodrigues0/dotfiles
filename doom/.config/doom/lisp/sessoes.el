;;; lisp/sessoes.el -*- lexical-binding: t; -*-

;; Sessoes por projeto, a imitar o herdr (ver herdr/.config/herdr/IDEIAS.md):
;;
;; - Cada projeto e um workspace do Doom (`:ui workspaces', persp-mode) = uma
;;   sessao. Abrir um projeto (SPC p p, dashboard, SPC a s) vai para a sessao
;;   dele; se nao houver, cria-a.
;; - Cada sessao tem as suas tabs (tab-bar do Emacs, uma barra por workspace):
;;   comeca com 1 = codigo e 2 = terminal (fish na pasta do projeto, para
;;   arrancar a AI que se quiser). M-1..M-9 saltam entre tabs, como no herdr.
;;   Podem abrir-se mais tabs de terminal/AI (SPC a t): varias AIs ao mesmo tempo.
;; - As sessoes ficam guardadas: tabs, janelas e ficheiros abertos. As tabs de
;;   AI retomam a conversa delas (claude --resume <id>; codex resume --last).
;;   Um claude/codex arrancado a mao num terminal tambem e detetado ao gravar.
;; - Parar uma sessao (SPC a k) grava-a e mata os buffers dela (terminais,
;;   eglot...), libertando a RAM, como o `herdr session stop'.
;; - O dashboard mostra as sessoes guardadas (● = aberta agora).
;;
;; Teclas:
;;   M-1..M-9  ir para a tab N (tambem dentro do terminal)
;;   SPC a t   nova tab (terminal, claude ou codex)
;;   SPC a x   fechar tab (mata o terminal dela)
;;   SPC a r   mudar o nome da tab
;;   SPC a s   escolher sessao          SPC a n  abrir projeto (nova sessao)
;;   SPC a w   gravar sessao            SPC a k  parar sessao (liberta RAM)
;;   SPC a d   apagar sessao
;; Os workspaces do Doom deixam de estar em M-1..M-9 (continuam em SPC TAB).

(require 'cl-lib)

;;; Configuracao

(defvar fabio/ai-comandos
  '(("claude"
     :novo (lambda (id) (format "claude --session-id %s" id))
     :retomar (lambda (id)
                (if (and id (file-expand-wildcards
                             (expand-file-name (format "~/.claude/projects/*/%s.jsonl" id))))
                    (format "claude --resume %s" id)
                  (if id (format "claude --session-id %s" id) "claude --continue"))))
    ("codex"
     :novo (lambda (_id) "codex")
     :retomar (lambda (_id) "codex resume --last")))
  "AIs que se podem abrir numa tab. :novo e :retomar recebem o id da conversa
da tab (um UUID; nil se a AI foi arrancada a mao) e devolvem o comando.
Os comandos correm no fish (`fish -C'), por isso ao sair da AI fica a shell.")

(defvar fabio/sessoes-ficheiro (expand-file-name "sessoes.eld" doom-data-dir)
  "Indice das sessoes: nome -> pasta do projeto, tabs e ultima utilizacao.
Os ficheiros abertos ficam no ficheiro de workspaces do Doom.")

;;; Indice das sessoes

(defun fabio/sessoes--ler ()
  "Lista de (NOME :root ROOT :tabs TABS :usado TEMPO)."
  (when (file-exists-p fabio/sessoes-ficheiro)
    (ignore-errors
      (with-temp-buffer
        (insert-file-contents fabio/sessoes-ficheiro)
        (read (current-buffer))))))

(defun fabio/sessoes--escrever (sessoes)
  (make-directory (file-name-directory fabio/sessoes-ficheiro) t)
  (with-temp-file fabio/sessoes-ficheiro
    (let ((print-length nil) (print-level nil))
      (prin1 sessoes (current-buffer)))))

(defun fabio/sessao--info (nome)
  (cdr (assoc nome (fabio/sessoes--ler))))

(defun fabio/sessao--atualizar (nome &rest props)
  "Junta PROPS a entrada NOME do indice (cria-a se nao existir)."
  (let* ((sessoes (fabio/sessoes--ler))
         (info (cdr (assoc nome sessoes))))
    (while props
      (setq info (plist-put info (pop props) (pop props))))
    (fabio/sessoes--escrever
     (cons (cons nome info) (cl-remove nome sessoes :key #'car :test #'equal)))))

(defun fabio/sessoes--ordenadas ()
  "Sessoes do indice, as usadas mais recentemente primeiro.
Esquece as de projetos cuja pasta ja nao existe."
  (let* ((sessoes (fabio/sessoes--ler))
         (vivas (cl-remove-if-not
                 (lambda (s) (file-directory-p (plist-get (cdr s) :root)))
                 sessoes)))
    (unless (= (length vivas) (length sessoes))
      (fabio/sessoes--escrever vivas))
    (sort vivas (lambda (a b) (> (or (plist-get (cdr a) :usado) 0)
                                 (or (plist-get (cdr b) :usado) 0))))))

(defun fabio/sessao--nome (root)
  "Nome da sessao de ROOT: a pasta, ou pai/pasta se o nome ja for de outro projeto."
  (let* ((root (file-name-as-directory root))
         (base (file-name-nondirectory (directory-file-name root)))
         (outro (plist-get (fabio/sessao--info base) :root)))
    (if (or (null outro) (file-equal-p outro root))
        base
      (concat (file-name-nondirectory
               (directory-file-name (file-name-directory (directory-file-name root))))
              "/" base))))

(defun fabio/sessao--ficheiro-ws ()
  (expand-file-name +workspaces-data-file persp-save-dir))

(defun fabio/sessao--guardada-p (nome)
  "Non-nil se os ficheiros da sessao NOME estao no ficheiro de workspaces."
  (let ((f (fabio/sessao--ficheiro-ws)))
    (and (file-exists-p f)
         (member nome (persp-list-persp-names-in-file f)))))

(defun fabio/sessao-atual ()
  "Nome da sessao do workspace atual, ou nil (ex.: workspace main)."
  (let ((nome (and (bound-and-true-p persp-mode) (+workspace-current-name))))
    (and nome (fabio/sessao--info nome) nome)))

(defun fabio/sessao--root (nome)
  (plist-get (fabio/sessao--info nome) :root))

;;; Terminais (ghostel), um por tab

;; Locais do buffer do terminal; permanentes porque o ghostel-mode limpa as
;; variaveis locais ao arrancar.
(defvar-local fabio/term-sessao nil "Sessao a que o terminal pertence.")
(defvar-local fabio/term-tab nil "Nome da tab do terminal.")
(defvar-local fabio/term-ai nil "AI arrancada pela tab (nil = so shell).")
(defvar-local fabio/term-id nil "Id da conversa da AI desta tab.")
(dolist (v '(fabio/term-sessao fabio/term-tab fabio/term-ai fabio/term-id))
  (put v 'permanent-local t))

(defun fabio/term--buffers (sessao)
  (cl-remove-if-not
   (lambda (b) (equal (buffer-local-value 'fabio/term-sessao b) sessao))
   (buffer-list)))

(defun fabio/term--da-tab (sessao tab)
  (cl-find-if (lambda (b) (equal (buffer-local-value 'fabio/term-tab b) tab))
              (fabio/term--buffers sessao)))

(defun fabio/tab--nomes ()
  (mapcar (lambda (tab) (alist-get 'name tab)) (tab-bar-tabs)))

(defun fabio/tab--nome-livre (base)
  "BASE, ou \"BASE 2\", \"BASE 3\"... se ja houver tab com esse nome."
  (let ((nomes (fabio/tab--nomes)) (n 1) (nome base))
    (while (member nome nomes)
      (setq n (1+ n) nome (format "%s %d" base n)))
    nome))

(defun fabio/uuid ()
  (let ((s (md5 (format "%s%s%s" (random) (float-time) (emacs-pid)))))
    (format "%s-%s-4%s-a%s-%s" (substring s 0 8) (substring s 8 12)
            (substring s 13 16) (substring s 17 20) (substring s 20 32))))

(defun fabio/term--insert-quando-pronto (buf &optional tentativas)
  "Poe BUF em insert state assim que o terminal tiver desenhado.
Antes disso o evil-ghostel nao sabe onde esta o cursor e da erro."
  (let ((tentativas (or tentativas 10)))
    (run-with-timer
     0.05 nil
     (lambda ()
       (when (and (buffer-live-p buf) (eq (window-buffer) buf))
         (with-current-buffer buf
           (cond ((not (bound-and-true-p evil-local-mode)))
                 ((bound-and-true-p ghostel--cursor-pos)
                  (ignore-errors (evil-insert-state)))
                 ((> tentativas 0)
                  (fabio/term--insert-quando-pronto buf (1- tentativas))))))))))

(defun fabio/term--criar (sessao root &optional ai id retomar tab)
  "Abre um terminal da SESSAO na tab atual (janela unica) e devolve o buffer.
AI e o nome de uma AI de `fabio/ai-comandos' (nil = so o fish); ID o id da
conversa; com RETOMAR continua-a. TAB e o nome da tab (por defeito, o da AI)."
  (require 'ghostel)
  (let* ((tab (or tab (fabio/tab--nome-livre (or ai "terminal"))))
         (buf (generate-new-buffer (format "*%s:%s*" sessao tab)))
         ;; Id novo so para conversas novas; uma AI arrancada a mao (sem id)
         ;; retoma com --continue.
         (id (or id (and ai (not retomar) (fabio/uuid))))
         (fn (and ai (plist-get (cdr (assoc ai fabio/ai-comandos))
                                (if retomar :retomar :novo))))
         (cmd (and fn (funcall fn id)))
         (default-directory (file-name-as-directory root)))
    (delete-other-windows)
    (switch-to-buffer buf nil t)
    (with-current-buffer buf
      (setq default-directory (file-name-as-directory root)))
    (ghostel-exec buf fabio/fish-shell (and cmd (list "-C" cmd)))
    (with-current-buffer buf
      (setq fabio/term-sessao sessao fabio/term-tab tab
            fabio/term-ai ai fabio/term-id id)
      ;; Sair do Emacs/parar a sessao sem perguntar pelo processo (o ghostel
      ;; pergunta num hook local, se houver um comando a correr).
      (setq-local ghostel-query-before-killing nil)
      (when (processp ghostel--process)
        (set-process-query-on-exit-flag ghostel--process nil)))
    (when (bound-and-true-p persp-mode)
      (persp-add-buffer buf (get-current-persp) nil nil))
    (tab-bar-rename-tab tab)
    (fabio/term--insert-quando-pronto buf)
    buf))

(defun fabio/term--ai-a-correr (buf)
  "AI a correr no terminal BUF: (AI . ID) ou nil.
Ve os processos filhos da shell, para apanhar tambem uma AI arrancada a mao."
  (let* ((pid (buffer-local-value 'ghostel--pid buf))
         (procs (and pid (mapcar (lambda (p) (cons p (process-attributes p)))
                                 (list-system-processes))))
         (pais (list pid))
         (achada nil))
    ;; Descendentes da shell, 4 niveis (sh -> fish -> claude/node ...).
    (dotimes (_ 4)
      (let ((filhos (cl-remove-if-not
                     (lambda (p) (memq (alist-get 'ppid (cdr p)) pais)) procs)))
        (dolist (p filhos)
          (let ((args (or (alist-get 'args (cdr p)) "")))
            (dolist (ai fabio/ai-comandos)
              (when (and (not achada)
                         (string-match-p (format "\\(?:^\\|/\\)%s\\(?:\\s-\\|$\\)" (car ai)) args))
                (setq achada (car ai))))))
        (setq pais (mapcar #'car filhos))))
    (cond ((null achada) nil)
          ;; A AI da tab: o id e o dela.
          ((equal achada (buffer-local-value 'fabio/term-ai buf))
           (cons achada (buffer-local-value 'fabio/term-id buf)))
          (t (cons achada nil)))))

;;; Tabs

(defun fabio/tab-nova (ai)
  "Abre uma tab nova nesta sessao com um terminal (AI nil) ou uma AI."
  (interactive
   (list (let ((x (completing-read "Nova tab: "
                                   (cons "terminal" (mapcar #'car fabio/ai-comandos))
                                   nil t)))
           (unless (equal x "terminal") x))))
  (let ((nome (or (fabio/sessao-atual) (user-error "Nao estas numa sessao (SPC a s ou SPC p p)"))))
    (let ((tab-bar-new-tab-to 'rightmost))
      (tab-bar-new-tab))
    (fabio/term--criar nome (fabio/sessao--root nome) ai)))

(defun fabio/tab-fechar ()
  "Fecha a tab atual; se for de terminal, mata-o."
  (interactive)
  (when (<= (length (tab-bar-tabs)) 1)
    (user-error "E a unica tab"))
  (let ((buf (window-buffer)))
    (tab-bar-close-tab)
    (when (buffer-local-value 'fabio/term-sessao buf)
      (fabio/term--matar buf))))

(defun fabio/tab-renomear (nome)
  (interactive (list (read-string "Nome da tab: ")))
  (let ((buf (window-buffer)))
    (tab-bar-rename-tab nome)
    (when (buffer-local-value 'fabio/term-sessao buf)
      (with-current-buffer buf (setq fabio/term-tab nome)))))

(defun fabio/tab-ir (n)
  "Vai para a tab N."
  (when (<= n (length (tab-bar-tabs)))
    (tab-bar-select-tab n)))

(dotimes (i 9)
  (let ((n (1+ i)))
    (defalias (intern (format "fabio/tab-%d" n))
      (lambda () (interactive) (fabio/tab-ir n))
      (format "Vai para a tab %d." n))))

(defun fabio/tab--ao-entrar-h (&rest _)
  "Ao entrar numa tab de terminal, fica logo pronto a escrever e limpa o ponto."
  (let ((buf (window-buffer)))
    (when (buffer-local-value 'fabio/term-sessao buf)
      (fabio/term-estado-definir nil buf)
      (fabio/term--insert-quando-pronto buf))))

;;; Gravar/restaurar as tabs

(defun fabio/tabs--meta (nome)
  "Descricao gravavel das tabs da sessao NOME (que tem de estar aberta)."
  (let* ((persp (+workspace-get nome t))
         (atual (eq persp (get-current-persp)))
         (tabs (if atual (tab-bar-tabs) (persp-parameter 'tab-bar-tabs persp))))
    (if (null tabs)
        (list (list :tipo 'codigo :nome "codigo"
                    :ws (and atual (window-state-get (frame-root-window) t))))
      (mapcar
       (lambda (tab)
         (let* ((tname (alist-get 'name tab))
                (term (fabio/term--da-tab nome tname)))
           (if term
               (let ((ai (fabio/term--ai-a-correr term)))
                 (list :tipo 'term :nome tname :ai (car ai) :id (cdr ai)))
             (let ((ws (if (eq (car tab) 'current-tab)
                           (and atual (window-state-get (frame-root-window) t))
                         (alist-get 'ws tab))))
               (list :tipo 'codigo :nome tname
                     ;; So se for legivel de volta.
                     :ws (ignore-errors (read (prin1-to-string ws)) ws))))))
       tabs))))

(defun fabio/tabs--restaurar (nome root tabs)
  "Volta a criar as TABS gravadas da sessao NOME, a comecar pela atual."
  (let ((primeira t))
    (dolist (tab tabs)
      (if primeira
          (setq primeira nil)
        (let ((tab-bar-new-tab-to 'rightmost))
          (tab-bar-new-tab)))
      (pcase (plist-get tab :tipo)
        ('term
         (fabio/term--criar nome root (plist-get tab :ai) (plist-get tab :id) t
                            (plist-get tab :nome)))
        (_
         (delete-other-windows)
         (when-let ((ws (plist-get tab :ws)))
           (with-demoted-errors "Erro a restaurar janelas: %S"
             (window-state-put ws (frame-root-window) 'safe)))
         (tab-bar-rename-tab (plist-get tab :nome)))))
    (tab-bar-select-tab 1)))

;;; Sessoes

(defun fabio/sessao-abrir (root)
  "Vai para a sessao do projeto ROOT: ativa, guardada ou nova."
  (let* ((root (file-name-as-directory (file-truename root)))
         (nome (fabio/sessao--nome root))
         (default-directory root)
         (tabs (plist-get (fabio/sessao--info nome) :tabs))
         (estado
          (cond ((+workspace-exists-p nome) 'ativa)
                ((or tabs (fabio/sessao--guardada-p nome)) 'guardada)
                (t 'nova))))
    (fabio/sessao--atualizar nome :root root :usado (float-time))
    (pcase estado
      ('ativa (+workspace-switch nome))
      ('guardada
       (when (fabio/sessao--guardada-p nome)
         (+workspace-load nome)
         ;; As tabs sao restauradas por nos; nao deixar o Doom por as dele.
         (set-persp-parameter 'tab-bar-tabs nil (+workspace-get nome)))
       (+workspace-switch nome t)
       (fabio/tabs--restaurar nome root
                              (or tabs (list (list :tipo 'codigo :nome "codigo")
                                             (list :tipo 'term :nome "terminal")))))
      ('nova
       (+workspace-switch nome t)
       (let ((dired (dired-noselect root)))
         (persp-add-buffer dired (get-current-persp) nil nil)
         (switch-to-buffer dired))
       (tab-bar-rename-tab "codigo")
       ;; Tab 2: terminal para arrancar a AI que se quiser.
       (let ((tab-bar-new-tab-to 'rightmost))
         (tab-bar-new-tab))
       (fabio/term--criar nome root nil nil nil "terminal")
       (tab-bar-select-tab 1)))
    (set-persp-parameter '+workspace-project root (+workspace-get nome))
    (unless (eq estado 'ativa)
      (fabio/sessao-guardar nome))
    (+workspace/display)
    (when (eq estado 'nova)
      (condition-case nil
          (doom-project-find-file root)
        (quit nil)))))

(defun fabio/sessao-abrir-projeto (&optional dir)
  "`projectile-switch-project-action': abre o projeto na sua sessao."
  (fabio/sessao-abrir (or (and (fboundp 'projectile-project-root)
                               (projectile-project-root (or dir default-directory)))
                          dir
                          default-directory)))

(defun fabio/sessao-guardar (&optional nome)
  "Grava a sessao NOME (por defeito a atual): tabs, janelas e ficheiros."
  (interactive)
  (let ((nome (or nome (fabio/sessao-atual))))
    (if (not (and nome (+workspace-exists-p nome) (fabio/sessao--info nome)))
        (when (called-interactively-p 'any)
          (user-error "Nao estas numa sessao"))
      (fabio/sessao--gravar nome)
      (when (called-interactively-p 'any)
        (message "Sessao '%s' gravada" nome)))))

(defun fabio/sessao--gravar (nome)
  "Grava as tabs da sessao NOME no indice e os ficheiros no ficheiro do Doom."
  (let ((persp (+workspace-get nome t)))
    (fabio/sessao--atualizar nome :tabs (fabio/tabs--meta nome))
    (when (and persp (persp-frames-with-persp persp))
      (persp-save-state persp))
    ;; As tabs guardadas pelo Doom no workspace tem window-configurations,
    ;; que nao se podem escrever em ficheiro; nao precisamos delas la.
    (let ((velhas (persp-parameter 'tab-bar-tabs persp)))
      (set-persp-parameter 'tab-bar-tabs nil persp)
      (unwind-protect (+workspace-save nome)
        (set-persp-parameter 'tab-bar-tabs velhas persp)))))

(defun fabio/sessoes-guardar-todas (&rest _)
  "Grava todas as sessoes abertas (ao sair do Emacs)."
  (when (bound-and-true-p persp-mode)
    (dolist (nome (+workspace-list-names))
      (when (fabio/sessao--info nome)
        (with-demoted-errors "Erro a gravar sessao: %S"
          (fabio/sessao--gravar nome))))
    ;; Idem para o autosave do Doom (Reload last session).
    (dolist (p (+workspace-list))
      (when (perspective-p p)
        (set-persp-parameter 'tab-bar-tabs nil p)))))

(defun fabio/sessao--ler-nome (prompt &optional so-ativas)
  (let* ((nomes (mapcar #'car (fabio/sessoes--ordenadas)))
         (nomes (if so-ativas (cl-remove-if-not #'+workspace-exists-p nomes) nomes))
         (atual (fabio/sessao-atual)))
    (unless nomes (user-error "Nao ha sessoes"))
    (completing-read prompt nomes nil t nil nil (and (member atual nomes) atual))))

(defun fabio/term--matar (buf)
  "Mata o terminal BUF sem perguntas."
  (when (buffer-live-p buf)
    (with-current-buffer buf
      (setq-local kill-buffer-query-functions nil))
    (kill-buffer buf)))

(defvar fabio/sessao--a-fechar nil
  "Non-nil enquanto se para/apaga uma sessao: nao gravar ao sair do workspace
(os terminais ja morreram e gravava-se a sessao sem as tabs deles).")

(defun fabio/sessao--matar-terminais (nome)
  (mapc #'fabio/term--matar (fabio/term--buffers nome)))

(defun fabio/sessao-parar (nome)
  "Grava e fecha a sessao NOME (mata os buffers dela, terminais incluidos)."
  (interactive (list (fabio/sessao--ler-nome "Parar sessao: " t)))
  (fabio/sessao-guardar nome)
  (let ((fabio/sessao--a-fechar t))
    (fabio/sessao--matar-terminais nome)
    (+workspace/kill nome))
  (fabio/dashboard-atualizar))

(defun fabio/sessao-apagar (nome)
  "Esquece a sessao NOME (o projeto fica; perde-se o estado guardado)."
  (interactive (list (fabio/sessao--ler-nome "Apagar sessao: ")))
  (when (yes-or-no-p (format "Apagar a sessao '%s'? " nome))
    (when (+workspace-exists-p nome)
      (let ((fabio/sessao--a-fechar t))
        (fabio/sessao--matar-terminais nome)
        (+workspace/kill nome)))
    (ignore-errors (+workspace-delete nome))
    (fabio/sessoes--escrever
     (cl-remove nome (fabio/sessoes--ler) :key #'car :test #'equal))
    (fabio/dashboard-atualizar)
    (message "Sessao '%s' apagada" nome)))

(defun fabio/sessao--resumo (info)
  "Ex.: \"claude, codex\" (as AIs das tabs) ou \"\"."
  (mapconcat #'identity
             (delete-dups (delq nil (mapcar (lambda (tab) (plist-get tab :ai))
                                            (plist-get info :tabs))))
             ", "))

(defun fabio/sessoes ()
  "Escolhe uma sessao (● = aberta) e vai para ela."
  (interactive)
  (let* ((sessoes (fabio/sessoes--ordenadas))
         (completion-extra-properties
          `(:annotation-function
            ,(lambda (nome)
               (let ((info (cdr (assoc nome sessoes))))
                 (format "  %s %-14s %s"
                         (if (+workspace-exists-p nome) "●" " ")
                         (fabio/sessao--resumo info)
                         (abbreviate-file-name (plist-get info :root)))))))
         (nome (fabio/sessao--ler-nome "Sessao: ")))
    (fabio/sessao-abrir (plist-get (cdr (assoc nome sessoes)) :root))))

;;; Estado do agente na tab (como o herdr)

;; Um ponto colorido ao lado da tab mostra o estado da AI dessa tab sem ter de la
;; entrar: amarelo a correr, vermelho precisa de permissao/input, verde terminou.
;; Como o ghostel nao ve a campainha, e a propria AI que anuncia o estado: os hooks
;; do Claude Code (~/.claude/settings.json, guardados por GHOSTEL=1) escrevem um
;; `OSC 9 ghostel-status:ESTADO' para o /dev/tty, que o ghostel entrega aqui via
;; `ghostel-notification-function'. O ponto limpa-se ao entrar na tab.

;; A shell do terminal fica com GHOSTEL=1, para os hooks so dispararem aqui dentro
;; (no Ghostty normal a variavel nao existe e nao se emite nada).
(with-eval-after-load 'ghostel
  (add-to-list 'ghostel-environment "GHOSTEL=1"))

(defvar-local fabio/term-estado nil
  "Estado da AI no terminal: `correr', `atencao', `feito' ou nil.")
(put 'fabio/term-estado 'permanent-local t)

(defconst fabio/term-estado-cores
  '((correr  . "#e0af68")               ; amarelo
    (atencao . "#f7768e")               ; vermelho
    (feito   . "#9ece6a"))              ; verde (TokyoNight)
  "Cor do ponto por estado.")

(defun fabio/term--redesenhar-tabs ()
  (when (fboundp 'tab-bar--update-tab-bar-lines)
    (tab-bar--update-tab-bar-lines t))
  (force-mode-line-update t))

(defun fabio/term-estado-definir (estado &optional buf)
  "Marca ESTADO no terminal BUF (por defeito o atual) e redesenha a tab-bar.
Nao faz nada se o estado ja for esse."
  (with-current-buffer (or buf (current-buffer))
    (unless (eq fabio/term-estado estado)
      (setq fabio/term-estado estado)
      (fabio/term--redesenhar-tabs))))

(defun fabio/term-notificacao (title body)
  "Handler de OSC 9. BODY \"ghostel-status:ESTADO\" pinta a tab; o resto segue
para a notificacao normal do ghostel."
  (if (and (stringp body) (string-prefix-p "ghostel-status:" body))
      (let ((e (intern (substring body (length "ghostel-status:")))))
        (fabio/term-estado-definir (and (assq e fabio/term-estado-cores) e)))
    (ghostel-default-notify title body)))

(with-eval-after-load 'ghostel
  (setq ghostel-notification-function #'fabio/term-notificacao))

(defun fabio/tab--formato (tab i)
  "Formato da tab com um ponto colorido se o terminal dela tiver estado.
Nao mostra na tab selecionada (ja se esta a ve-la)."
  (let ((base (tab-bar-tab-name-format-default tab i)))
    (if-let* (((not (eq (car tab) 'current-tab)))
              (buf (fabio/term--da-tab (fabio/sessao-atual) (alist-get 'name tab)))
              (estado (buffer-local-value 'fabio/term-estado buf))
              (cor (alist-get estado fabio/term-estado-cores)))
        (concat base (propertize " ●" 'face (list :foreground cor)))
      base)))

;;; Ligacoes ao Doom

(setq tab-bar-show 1                    ; so com 2+ tabs
      tab-bar-tab-hints t               ; numero antes do nome (M-N)
      tab-bar-close-button-show nil
      tab-bar-new-button-show nil
      tab-bar-new-tab-choice t
      tab-bar-tab-name-format-function #'fabio/tab--formato)

(after! persp-mode
  ;; Depois do persp-mode: a ligacao do Doom (tabs por workspace) e feita
  ;; no tab-bar-mode-hook que ele define.
  (tab-bar-mode 1)
  (add-hook 'tab-bar-tab-post-select-functions #'fabio/tab--ao-entrar-h)
  ;; SPC p p, dashboard "Open project", etc. abrem o projeto na sua sessao.
  (setq projectile-switch-project-action #'fabio/sessao-abrir-projeto)
  ;; Gravar a sessao que se deixa ao trocar de workspace.
  (add-hook 'persp-before-deactivate-functions
            (defun fabio/sessao-guardar-ao-sair-h (&rest _)
              (when-let ((nome (and (not fabio/sessao--a-fechar)
                                    (fabio/sessao-atual))))
                (with-demoted-errors "Erro a gravar sessao: %S"
                  (fabio/sessao--gravar nome))))
            -50)
  ;; Antes do persp-mode se desligar ao sair do Emacs.
  (add-hook 'kill-emacs-hook #'fabio/sessoes-guardar-todas -50))

(defconst fabio/tab-teclas (mapcar (lambda (n) (format "M-%d" n)) (number-sequence 1 9)))

(after! ghostel
  ;; M-1..M-9 passam do terminal para o Emacs (mudar de tab).
  (let ((novas (cl-remove-if (lambda (k) (member k ghostel-keymap-exceptions))
                             fabio/tab-teclas)))
    (when novas
      (customize-set-variable 'ghostel-keymap-exceptions
                              (append novas ghostel-keymap-exceptions))))
  ;; Cmd+C / Cmd+V no terminal, como no Ghostty. O s-v tem de ir pelo
  ;; `ghostel-paste' (bracketed paste para o processo); o `yank' normal so
  ;; escreveria no buffer do render, sem chegar ao programa. O `ghostel-paste'
  ;; le de `current-kill', por isso apanha o clipboard do sistema na mesma.
  (map! :map ghostel-mode-map
        "s-v" #'ghostel-paste
        "s-c" #'kill-ring-save))

;; Descarregar o modulo nativo do ghostel sem perguntar (nao ha zig).
(setq ghostel-module-auto-install 'download)

;; M-N = tab N (no lugar dos workspaces do Doom, que ficam em SPC TAB).
;; No terminal chegam ao Emacs pelas excecoes do ghostel acima.
(map! :g "M-1" #'fabio/tab-1
      :g "M-2" #'fabio/tab-2
      :g "M-3" #'fabio/tab-3
      :g "M-4" #'fabio/tab-4
      :g "M-5" #'fabio/tab-5
      :g "M-6" #'fabio/tab-6
      :g "M-7" #'fabio/tab-7
      :g "M-8" #'fabio/tab-8
      :g "M-9" #'fabio/tab-9)

(map! :leader
      (:prefix-map ("a" . "sessoes/tabs")
       :desc "Nova tab (terminal/AI)" "t" #'fabio/tab-nova
       :desc "Fechar tab"             "x" #'fabio/tab-fechar
       :desc "Mudar nome da tab"      "r" #'fabio/tab-renomear
       :desc "Escolher sessao"        "s" #'fabio/sessoes
       :desc "Abrir projeto"          "n" #'fabio/abrir-projeto
       :desc "Gravar sessao"          "w" #'fabio/sessao-guardar
       :desc "Parar sessao"           "k" #'fabio/sessao-parar
       :desc "Apagar sessao"          "d" #'fabio/sessao-apagar))

;;; Dashboard

(defun fabio/dashboard-atualizar ()
  (when (fboundp '+dashboard-reload)
    (+dashboard-reload t)))

(defun fabio/dashboard-widget-sessoes ()
  "Lista das sessoes no dashboard (● = aberta)."
  (when-let ((sessoes (seq-take (fabio/sessoes--ordenadas) 9)))
    (insert "\n")
    (+dashboard-insert
     (with-temp-buffer
       (insert (propertize "Sessoes" 'face '+dashboard-menu-title) "\n")
       (dolist (s sessoes)
         (let* ((nome (car s))
                (root (plist-get (cdr s) :root)))
           (insert "  ")
           (insert-text-button
            (format "%s %-26s %-14s %s"
                    (if (and (bound-and-true-p persp-mode) (+workspace-exists-p nome)) "●" "○")
                    (truncate-string-to-width nome 26 nil nil "…")
                    (truncate-string-to-width (fabio/sessao--resumo (cdr s)) 14 nil nil "…")
                    (truncate-string-to-width (abbreviate-file-name root) 40 nil nil "…"))
            'action (lambda (_) (fabio/sessao-abrir root))
            'face '+dashboard-menu-desc
            'follow-link t
            'help-echo (format "Abrir sessao %s" nome))
           (insert "\n")))
       (string-trim-right (buffer-string))))))

(when (boundp '+dashboard-functions)
  (unless (memq #'fabio/dashboard-widget-sessoes +dashboard-functions)
    (let ((pos (1+ (or (cl-position '+dashboard-widget-shortmenu +dashboard-functions) 0))))
      (setq +dashboard-functions
            (append (seq-take +dashboard-functions pos)
                    (list #'fabio/dashboard-widget-sessoes)
                    (seq-drop +dashboard-functions pos))))))

(when (boundp '+dashboard-menu-sections)
  (unless (assoc "Sessoes" +dashboard-menu-sections)
    (let ((pos (1+ (or (cl-position "Open project" +dashboard-menu-sections
                                    :key #'car :test #'equal)
                       0))))
      (setq +dashboard-menu-sections
            (append (seq-take +dashboard-menu-sections pos)
                    '(("Sessoes"
                       :icon (nerd-icons-octicon "nf-oct-stack" :face '+dashboard-menu-title)
                       :action fabio/sessoes))
                    (seq-drop +dashboard-menu-sections pos))))))
