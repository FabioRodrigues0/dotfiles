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

  ;; (pasta . profundidade): o projectile so olha exatamente a essa profundidade,
  ;; dai Faculdade/UC/projeto (2) e Faculdade/UC/aula/projeto (3).
  (setq projectile-project-search-path
        '(("~/Documents/Faculdade" . 2)
          ("~/Documents/Faculdade" . 3)
          ("~/Documents" . 1)
          ("~/Documents/into_sparta_life_old/01_projects" . 1)
          ("~/Documents/into_sparta_life_old/01_projects" . 2)))

  (defadvice! fabio/projectile-atualizar-projetos-a (&rest _)
    "Descobre projetos novos e esquece os apagados antes de escolher um."
    :before #'projectile-switch-project
    (let ((inhibit-message t))
      (projectile-cleanup-known-projects)
      (projectile-discover-projects-in-search-path))))
