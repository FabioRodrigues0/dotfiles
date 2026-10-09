# Emacs: manutenção

## Atualizar

| Comando | O que faz |
|---|---|
| `doom sync` (`SPC h r s`) | Aplica a config: instala/remove pacotes conforme `init.el`/`packages.el`. **Não atualiza nada.** Correr depois de mexer no `init.el` ou `packages.el`. |
| `doom sync -u` | Atualiza só os pacotes (o Doom fica igual). |
| `doom upgrade` | Atualiza o Doom (`git pull` em `~/.config/emacs`) e depois todos os pacotes. |
| `brew upgrade --cask emacs-plus-app` | Atualiza o próprio Emacs (o `doom upgrade` não lhe mexe). Depois: `doom sync`. |

Depois de um upgrade: `doom doctor` e testar o que se usa mais. O que mais
facilmente parte são as coisas que usam funções internas de pacotes:
`SPC c g` no Java (`lisp/java-gerar.el`, eglot) e as portas fixas do
typst-preview (`config.el`).

## Upgrade de 2026-10-09 (Doom de maio -> 2.2.4)

- Durante o upgrade aparece `Error loading profile: ... doom-version`: é o
  ficheiro gerado pela versão antiga (`.local/etc/@/init.*.el`); o próprio
  upgrade regenera-o. Se ficar no fim, `doom sync`.
- O straight pergunta o que fazer quando o Doom troca a origem de um pacote
  ("remote origin has URL ... but recipe specifies ..."). Escolher **4**
  (apagar o remote e recriar com o URL certo). Aconteceu com:
  - dirvish: `alexluigit` -> `latiagertrutis` (fork mantido, o original parou)
  - helpful: `Wilfred` -> `hlissner`
- Os módulos do Doom saíram do repositório principal para
  `~/.config/emacs/sources/doom+` (submódulo). O `init.el` fica igual; se algum
  módulo der erro no arranque, é por aqui.

## `doom doctor`: avisos que ficam de propósito

- **Symbola**: não existe no brew. No macOS usa-se o Apple Symbols
  (`doom-symbol-font` no `config.el`); o doctor avisa na mesma porque só
  procura o nome "Symbola". No Linux: pacote `fonts-symbola`.
- **Shell fish**: `shell-file-name` é o fish porque o `correr` (`SPC m r`) é
  uma função do fish. Trocar para bash parte isso.
- **cmake**: só para compilar o vterm; uso o Ghostty.
- **black, pipenv, nose, pytest**: uso ruff e uv; o pytest vai por projeto.
- **clang-format (Java)**: uso Spotless / google-java-format.
- **ktlint, glslang, stylelint, js-beautify, shfmt, shellcheck**: linguagens
  que não uso no Emacs (shfmt/shellcheck só se mexer muito nos `novo-*.sh`).

Instalados para o doctor: `coreutils` (gls para o dired/dirvish), `aspell`.

## Pendente

**Emacs 31.** Tenho o 30.2 (build 104, maio); o cask estável já vai no 31.1.
O tap `d12frosted/emacs-plus` está ativo (builds quase diários). Esperar uns
dias com o Doom 2.2.4 a funcionar e só depois:

```
brew trust d12frosted/emacs-plus      # o brew recusa casks de taps não confiados
brew upgrade --cask emacs-plus-app
doom sync
doom doctor
```

Sem o `brew trust`, o `brew outdated` não mostra o Emacs (falha em silêncio).
