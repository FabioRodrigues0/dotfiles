;;; lisp/novo-ficheiro.el -*- lexical-binding: t; -*-

;; Novo ficheiro ao estilo do IntelliJ (New > Java Class...), em `SPC f n'.
;;
;; 1. Ve que linguagens o projeto usa (pom.xml, *.csproj, pyproject.toml...,
;;    e a extensao do ficheiro atual) e mostra so os tipos dessas. Sem nada
;;    detetado pergunta primeiro a linguagem; "Outra linguagem..." mostra o resto.
;; 2. Pede o nome. `model/Pessoa' (ou `model.Pessoa' em Java) cria em subpasta.
;; 3. Pede a pasta, ja preenchida com o sitio mais provavel (pasta do ficheiro
;;    atual, src/main/java/<package>, tests/...). DEL apaga ate a pasta de cima;
;;    escrever um nome que nao existe cria a pasta.
;;
;; O conteudo (package, include guard, ...) e escrito no disco antes de abrir,
;; para os file-templates do Doom nao meterem o template deles por cima.

(require 'cl-lib)
(require 'subr-x)

(defvar fabio/novo-ficheiro-linguagens
  '((java   "Java"   ("pom.xml" "build.gradle" "build.gradle.kts" "settings.gradle")
            ("java"))
    (csharp "C#"     ("*.csproj" "*.sln") ("cs"))
    (python "Python" ("pyproject.toml" "requirements.txt" "setup.py" ".venv") ("py"))
    (web    "Web"    ("package.json" "*.html") ("html" "css" "js" "ts"))
    (c      "C"      ("CMakeLists.txt" "*.c") ("c" "h"))
    (typst  "Typst"  ("*.typ") ("typ")))
  "(ID NOME MARCADORES EXTENSOES).
Um MARCADOR na raiz do projeto, ou o ficheiro atual ter uma das EXTENSOES,
ativa a linguagem.")

;;; Utilitarios

(defun fabio/novo--snake (s)
  "ContaBancaria / conta-bancaria -> conta_bancaria."
  (let ((case-fold-search nil))
    (downcase (replace-regexp-in-string
               "\\([a-z0-9]\\)\\([A-Z]\\)" "\\1_\\2"
               (replace-regexp-in-string "[- ]+" "_" s)))))

(defun fabio/novo--camel (s)
  "conta_bancaria / contaBancaria -> ContaBancaria."
  (mapconcat (lambda (p) (concat (upcase (substring p 0 1)) (substring p 1)))
             (split-string s "[-_ ]+" t) ""))

(defun fabio/novo--subst (tpl nome)
  (string-replace "{{nome}}" nome tpl))

(defun fabio/novo--java-package (dir)
  "Package Java de DIR (a parte depois de src/<algo>/java/), ou nil."
  (let ((d (file-name-as-directory (expand-file-name dir))))
    (when (string-match "/src/[^/]+/java/\\(.+\\)\\'" d)
      (string-join (split-string (match-string 1 d) "/" t) "."))))

(defun fabio/novo--descer (dir)
  "Desce por DIR enquanto so tiver uma subpasta e nenhum ficheiro.
Num projeto Maven src/main/java da src/main/java/pt/project."
  (let ((dir (file-name-as-directory dir)))
    (while (let ((filhos (and (file-directory-p dir)
                              (directory-files dir t "\\`[^.]"))))
             (and (= (length filhos) 1) (file-directory-p (car filhos))))
      (setq dir (file-name-as-directory
                 (car (directory-files dir t "\\`[^.]")))))
    dir))

;;; Pastas por defeito

(defun fabio/novo--dentro-p (dir root)
  (and dir root (file-in-directory-p dir root)))

(defun fabio/novo--pasta-geral (root atual)
  (if (or (null root) (fabio/novo--dentro-p atual root)) atual root))

(defun fabio/novo--pasta-java (sitio)
  "Pasta para Java em src/SITIO/java, espelhando a do ficheiro atual."
  (lambda (root atual)
    (cond
     ((string-match "/src/\\(?:main\\|test\\)/java/\\(.*\\)\\'" atual)
      (let ((modulo (substring atual 0 (1+ (match-beginning 0))))
            (resto (match-string 1 atual)))
        (expand-file-name resto (expand-file-name (format "src/%s/java/" sitio) modulo))))
     (root
      (let ((base (expand-file-name (format "src/%s/java/" sitio) root)))
        (if (file-directory-p base)
            (fabio/novo--descer base)
          (fabio/novo--pasta-geral root atual))))
     (t atual))))

(defun fabio/novo--pasta-csharp (root atual)
  "Pasta atual se estiver no projeto, senao a pasta do .csproj."
  (if (or (null root) (fabio/novo--dentro-p atual root))
      atual
    (or (cl-find-if (lambda (d) (directory-files d nil "\\.csproj\\'"))
                    (cons root (cl-remove-if-not #'file-directory-p
                                                 (directory-files root t "\\`[^.]"))))
        root)))

(defun fabio/novo--pasta-testes-py (root atual)
  (if root (expand-file-name "tests/" root) atual))

;;; Tipos de ficheiro

(defun fabio/novo--java (tpl &optional sufixo)
  "Tipo Java com corpo TPL; SUFIXO e acrescentado ao nome (FooTest)."
  (lambda (nome dir)
    (let ((nome (if (and sufixo (not (string-suffix-p sufixo nome)))
                    (concat nome sufixo)
                  nome))
          (pkg (fabio/novo--java-package dir)))
      (list (cons (concat nome ".java")
                  (concat (if pkg (format "package %s;\n\n" pkg) "")
                          (fabio/novo--subst tpl nome)))))))

(defun fabio/novo--simples (ext tpl &optional nome-fn)
  "Um ficheiro NOME.EXT com TPL; NOME-FN transforma o nome (snake_case...)."
  (lambda (nome _dir)
    (let ((base (if nome-fn (funcall nome-fn nome) nome)))
      (list (cons (concat base "." ext) (fabio/novo--subst tpl nome))))))

(defun fabio/novo--c-header (nome)
  (let ((guard (upcase (concat (fabio/novo--snake nome) "_H"))))
    (format "#ifndef %s\n#define %s\n\n$0\n\n#endif /* %s */\n" guard guard guard)))

(defvar fabio/novo-ficheiro-tipos
  `((java "Classe"
          ,(fabio/novo--java "public class {{nome}} {\n    $0\n}\n")
          ,(fabio/novo--pasta-java "main") t)
    (java "Interface"
          ,(fabio/novo--java "public interface {{nome}} {\n    $0\n}\n")
          ,(fabio/novo--pasta-java "main") t)
    (java "Enum"
          ,(fabio/novo--java "public enum {{nome}} {\n    $0\n}\n")
          ,(fabio/novo--pasta-java "main") t)
    (java "Record"
          ,(fabio/novo--java "public record {{nome}}($0) {\n}\n")
          ,(fabio/novo--pasta-java "main") t)
    (java "Classe abstrata"
          ,(fabio/novo--java "public abstract class {{nome}} {\n    $0\n}\n")
          ,(fabio/novo--pasta-java "main") t)
    (java "Classe com main"
          ,(fabio/novo--java "public class {{nome}} {\n\n    public static void main(String[] args) {\n        $0\n    }\n}\n")
          ,(fabio/novo--pasta-java "main") t)
    (java "Exceção"
          ,(fabio/novo--java "public class {{nome}} extends Exception {\n\n    public {{nome}}(String mensagem) {\n        super(mensagem);$0\n    }\n}\n")
          ,(fabio/novo--pasta-java "main") t)
    (java "Teste JUnit"
          ,(fabio/novo--java "import static org.junit.jupiter.api.Assertions.*;\n\nimport org.junit.jupiter.api.Test;\n\nclass {{nome}} {\n\n    @Test\n    void test() {\n        $0\n    }\n}\n" "Test")
          ,(fabio/novo--pasta-java "test") t)

    (csharp "Classe"
            ,(fabio/novo--simples "cs" "public class {{nome}}\n{\n    $0\n}\n")
            fabio/novo--pasta-csharp t)
    (csharp "Interface"
            ,(fabio/novo--simples "cs" "public interface {{nome}}\n{\n    $0\n}\n")
            fabio/novo--pasta-csharp t)
    (csharp "Enum"
            ,(fabio/novo--simples "cs" "public enum {{nome}}\n{\n    $0\n}\n")
            fabio/novo--pasta-csharp t)
    (csharp "Record"
            ,(fabio/novo--simples "cs" "public record {{nome}}($0);\n")
            fabio/novo--pasta-csharp t)
    (csharp "Struct"
            ,(fabio/novo--simples "cs" "public struct {{nome}}\n{\n    $0\n}\n")
            fabio/novo--pasta-csharp t)

    (python "Módulo"
            ,(fabio/novo--simples "py" "$0" #'fabio/novo--snake)
            fabio/novo--pasta-geral)
    (python "Classe"
            ,(lambda (nome _dir)
               (list (cons (concat (fabio/novo--snake nome) ".py")
                           (format "class %s:\n    def __init__(self) -> None:\n        $0\n"
                                   (fabio/novo--camel nome)))))
            fabio/novo--pasta-geral)
    (python "Script com main"
            ,(fabio/novo--simples "py" "def main() -> None:\n    $0\n\n\nif __name__ == \"__main__\":\n    main()\n"
                                  #'fabio/novo--snake)
            fabio/novo--pasta-geral)
    (python "Teste pytest"
            ,(lambda (nome _dir)
               (let ((s (string-remove-prefix "test_" (fabio/novo--snake nome))))
                 (list (cons (format "test_%s.py" s)
                             (format "def test_%s() -> None:\n    $0\n" s)))))
            fabio/novo--pasta-testes-py)
    (python "Pacote"
            ,(lambda (nome _dir)
               (list (cons (concat (fabio/novo--snake nome) "/__init__.py") "$0")))
            fabio/novo--pasta-geral)

    (web "HTML"
         ,(fabio/novo--simples "html" "<!DOCTYPE html>\n<html lang=\"pt\">\n<head>\n    <meta charset=\"UTF-8\">\n    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">\n    <title>{{nome}}</title>\n</head>\n<body>\n    $0\n</body>\n</html>\n")
         fabio/novo--pasta-geral)
    (web "CSS" ,(fabio/novo--simples "css" "$0") fabio/novo--pasta-geral)
    (web "JavaScript" ,(fabio/novo--simples "js" "$0") fabio/novo--pasta-geral)

    (c "Ficheiro .c"
       ,(fabio/novo--simples "c" "#include <stdio.h>\n\n$0")
       fabio/novo--pasta-geral)
    (c "Header .h"
       ,(lambda (nome _dir) (list (cons (concat nome ".h") (fabio/novo--c-header nome))))
       fabio/novo--pasta-geral)
    (c "Par .c + .h"
       ,(lambda (nome _dir)
          (list (cons (concat nome ".c") (format "#include \"%s.h\"\n\n$0" nome))
                (cons (concat nome ".h")
                      (string-replace "$0" "" (fabio/novo--c-header nome)))))
       fabio/novo--pasta-geral)

    (typst "Documento"
           ,(fabio/novo--simples "typ" "= {{nome}}\n\n$0")
           fabio/novo--pasta-geral))
  "(LINGUAGEM NOME FICHEIROS PASTA PONTOS).
FICHEIROS: (lambda (nome dir)) -> lista de (caminho-relativo . conteudo); o
primeiro e o que abre e `$0' marca o cursor. PASTA: (lambda (root atual)) ->
pasta por defeito. PONTOS: `a.b.Nome' tambem cria subpastas (Java, C#).")

(defvar fabio/novo-ficheiro-qualquer
  (list 'outro "Ficheiro qualquer"
        (lambda (nome _dir) (list (cons nome "$0")))
        #'fabio/novo--pasta-geral nil)
  "Sempre disponivel: o nome leva a extensao.")

;;; Detecao

(defun fabio/novo--raiz ()
  (or (and (fboundp 'doom-project-root) (doom-project-root))
      (when-let ((p (project-current))) (project-root p))))

(defun fabio/novo--linguagens (root ficheiro)
  "Linguagens detetadas em ROOT e pela extensao de FICHEIRO."
  (let ((ext (and ficheiro (file-name-extension ficheiro))))
    (cl-loop for (id _nome marcadores exts) in fabio/novo-ficheiro-linguagens
             when (or (member ext exts)
                      (and root
                           (cl-some (lambda (m)
                                      (if (string-match-p "\\*" m)
                                          (file-expand-wildcards (expand-file-name m root))
                                        (file-exists-p (expand-file-name m root))))
                                    marcadores)))
             collect id)))

(defun fabio/novo--rotulo (tipo)
  (format "%s › %s" (or (nth 1 (assq (car tipo) fabio/novo-ficheiro-linguagens)) "Outro")
          (nth 1 tipo)))

(defun fabio/novo--tipos-de (langs)
  (cl-remove-if-not (lambda (tp) (memq (car tp) langs)) fabio/novo-ficheiro-tipos))

(defun fabio/novo--escolher-tipo (langs)
  "Escolhe o tipo, mostrando primeiro so os das LANGS detetadas."
  (let* ((outra "Outra linguagem…")
         (tipos (append (fabio/novo--tipos-de langs) (list fabio/novo-ficheiro-qualquer)))
         (escolha (if langs
                      (completing-read "Novo ficheiro: "
                                       (append (mapcar #'fabio/novo--rotulo tipos) (list outra))
                                       nil t)
                    outra)))
    (if (not (equal escolha outra))
        (cl-find escolha tipos :key #'fabio/novo--rotulo :test #'equal)
      (let* ((nomes (append (mapcar #'cadr fabio/novo-ficheiro-linguagens) '("Outro")))
             (lang (completing-read "Linguagem: " nomes nil t))
             (id (car (cl-find lang fabio/novo-ficheiro-linguagens :key #'cadr :test #'equal)))
             (tipos (fabio/novo--tipos-de (list id))))
        (if (null id)
            fabio/novo-ficheiro-qualquer
          (cl-find (completing-read (format "%s › " lang) (mapcar #'cadr tipos) nil t)
                   tipos :key #'cadr :test #'equal))))))

;;; Criar

(defun fabio/novo-ficheiro-criar (tipo nome dir)
  "Cria os ficheiros de TIPO com NOME em DIR e abre o primeiro."
  (let* ((dir (file-name-as-directory (expand-file-name dir)))
         (ficheiros (funcall (nth 2 tipo) nome dir))
         (caminhos (mapcar (lambda (f) (expand-file-name (car f) dir)) ficheiros)))
    (when-let ((existe (cl-find-if #'file-exists-p caminhos)))
      (user-error "Já existe: %s" (abbreviate-file-name existe)))
    (let (abrir cursor)
      (cl-loop for (_rel . conteudo) in ficheiros
               for caminho in caminhos
               do (let ((pos (string-search "$0" conteudo)))
                    (make-directory (file-name-directory caminho) t)
                    (with-temp-file caminho
                      (insert (string-replace "$0" "" conteudo)))
                    (unless abrir
                      (setq abrir caminho cursor pos))))
      (find-file abrir)
      (goto-char (1+ (or cursor 0)))
      (when (bound-and-true-p evil-local-mode)
        (evil-insert-state))
      abrir)))

;;;###autoload
(defun fabio/novo-ficheiro ()
  "Novo ficheiro do tipo certo para o projeto, com package/namespace/guard."
  (interactive)
  (let* ((root (fabio/novo--raiz))
         (atual (file-name-as-directory
                 (expand-file-name (if buffer-file-name
                                       (file-name-directory buffer-file-name)
                                     default-directory))))
         (tipo (or (fabio/novo--escolher-tipo (fabio/novo--linguagens root buffer-file-name))
                   (user-error "Tipo desconhecido")))
         (entrada (string-trim (read-string (format "%s — nome: " (fabio/novo--rotulo tipo)))))
         ;; `model/Pessoa', e em Java/C# `model.Pessoa', criam subpastas.
         (partes (split-string (if (nth 4 tipo) (subst-char-in-string ?. ?/ entrada) entrada)
                               "/" t))
         (nome (car (last partes)))
         (base (funcall (nth 3 tipo) root atual))
         (sugestao (file-name-as-directory
                    (expand-file-name (string-join (butlast partes) "/") base))))
    (when (string-empty-p (or nome "")) (user-error "Nome vazio"))
    (when (and (nth 4 tipo) (not (string-match-p "\\`[[:alpha:]_$][[:alnum:]_$]*\\'" nome)))
      (user-error "Nome inválido para %s: %s" (fabio/novo--rotulo tipo) nome))
    (let ((dir (read-directory-name
                (format "Pasta para %s: " (car (car (funcall (nth 2 tipo) nome sugestao))))
                sugestao sugestao nil)))
      (fabio/novo-ficheiro-criar tipo nome dir))))

(map! :leader :desc "Novo ficheiro (tipo)" "f n" #'fabio/novo-ficheiro)
