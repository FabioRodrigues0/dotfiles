# Emacs: coisas a trazer dos JetBrains

## Já feito

| IntelliJ | Emacs | Onde |
|---|---|---|
| New > Java Class… | `SPC f n`: tipo de ficheiro conforme o projeto, nome, pasta sugerida | `lisp/novo-ficheiro.el` |
| Open project (lista automática) | `SPC p p` e o dashboard descobrem os projetos sozinhos | `lisp/projetos.el` |
| Generate (Alt+Insert) | `SPC c g` em Java: getters/setters, toString, equals/hashCode, construtores, override/implementar métodos | `lisp/java-gerar.el` |
| Optimize imports | Ao gravar um `.java` (e `SPC c o` à mão) | `lisp/java-gerar.el` |

## Já existe no Doom (só saber a tecla)

- Search Everywhere / Recent files: `SPC SPC`, `SPC f r`, `SPC ,`
- Structure (métodos do ficheiro): `SPC s i`
- Rename / Alt+Enter: `SPC c r` / `SPC c a`
- Histórico de um ficheiro: `SPC g t` (git-timemachine)

## Para depois

Por ordem do que deve fazer mais diferença.

1. **Correr o teste/ficheiro no cursor** (Ctrl+Shift+F10). Já há `correr` para
   o projeto (`lisp/java-csharp.el`). Falta "este teste JUnit/pytest" e
   "esta classe com main", com o resultado no compile buffer.
2. **Debugger** (breakpoints, step over). Ativar `:tools debugger` no
   `init.el` (dape) e instalar os adaptadores: java-debug (plugin do jdtls),
   debugpy, netcoredbg. O maior ganho, mas o que dá mais trabalho a testar.
3. **Inlay hints** (nomes dos parâmetros nas chamadas). `eglot-inlay-hints-mode`
   em Java e C#; o jdtls suporta.
4. **Bases de dados (DataGrip)**. Já há `ligar`/`desligar` das BDs da
   disciplina em Docker (fish). Guardar as ligações em `sql-connection-alist`
   e correr o `.sql` aberto contra o contentor, com resultado em tabela.
5. **Árvore do projeto** (Cmd+1). treemacs (`:ui treemacs`) ou sidebar do dired.
6. **Multi-cursor** (Alt+J). `:editor multiple-cursors`.

## Notas

- O jdtls só oferece toString/equals/construtores/override se o cliente
  anunciar `extendedClientCapabilities` (ver `fabio/jdtls-init-options`). Os
  pedidos `java/check*Status` e `java/generate*` são os do vscode-java; se
  numa versão nova do jdtls algum deixar de funcionar, é aí que se vê.
- O código gerado é formatado pelo jdtls só na parte que mudou e leva uma
  linha em branco entre membros; os projetos com Spotless voltam a formatar
  ao gravar.
