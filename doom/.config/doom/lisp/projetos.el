;;; lisp/projetos.el -*- lexical-binding: t; -*-

;; "Open project" (dashboard e SPC p p) sem ter de adicionar projetos a mao:
;; antes de mostrar a lista, procura projetos nas pastas abaixo e tira os que
;; ja nao existem. Demora uns centesimos de segundo.

(after! projectile
  ;; Marcadores que o Doom nao traz: Maven e o main.py do `novo py' (o Doom so
  ;; conhece gradle, pyproject.toml, requirements.txt e setup.py).
  (dolist (f '("pom.xml" "main.py"))
    (add-to-list 'projectile-project-root-files f))

  ;; .NET: pasta com *.csproj ou *.sln (os root-files nao aceitam wildcards).
  (defun fabio/projectile-root-dotnet (dir)
    (locate-dominating-file
     dir (lambda (d) (directory-files d nil "\\.\\(?:csproj\\|sln\\)\\'" t 1))))
  (add-to-list 'projectile-project-root-functions #'fabio/projectile-root-dotnet 'append)

  ;; Marcador de "pasta e um projeto" (regex num unico directory-files).
  (defconst fabio/projeto-marcador-re
    "\\`\\(?:pom\\.xml\\|build\\.gradle\\(?:\\.kts\\)?\\|settings\\.gradle\\|main\\.py\\|.*\\.\\(?:csproj\\|sln\\)\\)\\'")
  (defun fabio/projeto-marcado-p (d)
    (and (file-directory-p d)
         (directory-files d nil fabio/projeto-marcador-re t 1)))

  ;; Projeto adicionado a mao (SPC p a): o projectile guarda o caminho em
  ;; `projectile-known-projects', mas a RAIZ e recalculada a cada abertura a
  ;; partir do ficheiro (bottom-up), e a lista nao conta para esse calculo. Por
  ;; isso dentro da Faculdade caia sempre no .git de topo e nao na pasta que
  ;; adicionei. Isto reconhece a pasta adicionada (ou uma com .projectile) como
  ;; raiz tambem, nao so as que tem marcador de build.
  (defun fabio/projeto-conhecido-p (d)
    "Pasta D esta na lista `projectile-known-projects'?"
    (and (bound-and-true-p projectile-known-projects)
         (let ((dt (file-truename (file-name-as-directory (expand-file-name d)))))
           (seq-some (lambda (p)
                       (string= dt (file-truename
                                    (file-name-as-directory (expand-file-name p)))))
                     projectile-known-projects))))

  (defun fabio/projeto-raiz-p (d)
    "D e raiz de projeto: marcador de build, .projectile, ou projeto conhecido."
    (and (file-directory-p d)
         (or (fabio/projeto-marcado-p d)
             (file-exists-p (expand-file-name ".projectile" d))
             (fabio/projeto-conhecido-p d))))

  ;; A Faculdade toda e UM repo git (~/Documents/Faculdade/.git). O projectile
  ;; resolve a raiz por VCS (bottom-up) ANTES dos root-files, por isso qualquer
  ;; projeto la dentro (ex.: PDI/PdI_GrupoX) resolvia para a Faculdade e o pom.xml
  ;; nunca contava. Aqui, dentro da Faculdade, a raiz e a pasta do proprio projeto
  ;; (marcador de build, .projectile, ou pasta adicionada a mao), nao o git de topo.
  ;; file-truename nos dois lados: /home e /var/home (symlink) tem de bater certo.
  ;; Prepende (corre primeiro); fora da Faculdade devolve nil e segue o normal.
  (defun fabio/projectile-root-faculdade (dir)
    (let ((fac (file-truename (expand-file-name "~/Documents/Faculdade/")))
          (d   (file-name-as-directory (file-truename (expand-file-name dir)))))
      (when (string-prefix-p fac d)
        (locate-dominating-file dir #'fabio/projeto-raiz-p))))
  (add-to-list 'projectile-project-root-functions #'fabio/projectile-root-faculdade)

  ;; (pasta . profundidade): o projectile so olha exatamente a essa profundidade,
  ;; dai Faculdade/UC/projeto (2) e Faculdade/UC/aula/projeto (3).
  (setq projectile-project-search-path
        '(("~/Documents/Faculdade" . 2)
          ("~/Documents/Faculdade" . 3)
          ("~/Documents" . 1)
          ("~/Documents/into_sparta_life_old/01_projects" . 1)
          ("~/Documents/into_sparta_life_old/01_projects" . 2)))

  ;; Descoberta propria: o projectile-discover para no primeiro repo git (a
  ;; Faculdade) e nao desce. Esta desce ate MAX niveis e adiciona TODA a pasta
  ;; com marcador, sem ligar ao git de topo. Resolve a Faculdade/PDI/PdI_GrupoX.
  (defun fabio/descobrir-marcados (base max)
    (setq base (file-truename (expand-file-name base)))
    (when (file-directory-p base)
      (let ((fila (list (cons base 0))))
        (while fila
          (let* ((atual (pop fila)) (dir (car atual)) (nivel (cdr atual)))
            (when (fabio/projeto-marcado-p dir)
              (projectile-add-known-project dir))
            (when (< nivel max)
              (dolist (sub (directory-files dir t "\\`[^.]" t))
                (when (and (file-directory-p sub) (not (file-symlink-p sub))
                           (not (member (file-name-nondirectory sub)
                                        '("node_modules" "target" "bin" "obj"))))
                  (push (cons sub (1+ nivel)) fila)))))))))

  (defadvice! fabio/projectile-atualizar-projetos-a (&rest _)
    "Descobre projetos novos e esquece os apagados antes de escolher um."
    :before #'projectile-switch-project
    (let ((inhibit-message t))
      (projectile-cleanup-known-projects)
      (projectile-discover-projects-in-search-path)
      (fabio/descobrir-marcados "~/Documents/Faculdade" 3)
      ;; A Faculdade (git-root sem marcador proprio) nao e um projeto: tira-a.
      (let ((fac (file-truename (expand-file-name "~/Documents/Faculdade/"))))
        (setq projectile-known-projects
              (seq-remove (lambda (p)
                            (string= (file-truename (expand-file-name p)) fac))
                          projectile-known-projects))))))

;; O botao "Open project" do dashboard chama a acao via `cmd!!', que passa o
;; proprio botao como prefix arg. O projectile ve isso como C-u e abre o menu
;; `projectile-dispatch' em vez de `projectile-find-file'. Sem prefix arg aqui.
(defun fabio/abrir-projeto ()
  "Escolhe um projeto e abre um ficheiro dele (sem `projectile-dispatch')."
  (interactive)
  (let ((current-prefix-arg nil))
    (projectile-switch-project)))

(when (boundp '+dashboard-menu-sections)
  (when-let ((s (assoc "Open project" +dashboard-menu-sections)))
    (setcdr s (plist-put (cdr s) :action 'fabio/abrir-projeto))))
