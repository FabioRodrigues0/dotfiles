# herdr: sessões e navegação

## Estado atual (feito)

Cada projeto = uma **sessão** do herdr (`herdr --session <nome>`, servidor próprio).
Vantagem: parar (`herdr session stop <nome>`) liberta a RAM toda dessa sessão (emacs
incluído). Workspaces num só servidor não davam isto — ficavam todos vivos (N× emacs).

Trocar/criar sessões faz-se pelas **tabs do Ghostty** (uma sessão por tab), não por
atalhos do herdr.

### Porquê tabs do Ghostty e não atalho do herdr

O herdr **não tem switch-client**: de dentro duma pane, `herdr session attach` só abre
a outra sessão **aninhada** (confirmado — a API não tem detach/attach/switch, só
`is_detached`). Não dá saltar entre servidores em ecrã inteiro por tecla do herdr.
O Ghostty apanha as teclas antes do herdr e, no Linux, o herdr só usa `alt+...`, por
isso `super+...` ficou livre para o Ghostty.

### Teclas (ghostty/.config/ghostty/config)

| Tecla | Ação |
|---|---|
| `alt+t` | nova tab (sessão) |
| `alt+o` | tab overview (switcher visual) |
| `alt+shift+→` / `alt+shift+←` | tab próxima / anterior |
| (fechar) | pelo rato |

Em `alt` (não super, que o Fabio não ajeita) e só em combinações que o herdr não usa
(o herdr ocupa quase todos os `alt+...`; por isso sem números). O `herdr` tinha `new_tab`
em `alt+t` → desligado (`new_tab = []`), senão criava uma tab do herdr em vez da do Ghostty.

Nova sessão: `alt+t` → `abrir <pasta>` (cria) ou `sessoes` (fzf escolhe existente).
Funções fish: `fish/.config/fish/functions/{abrir,sessoes,abrir-escolher}.fish`.

### Plugins herdr-fold

- `tab-layout` e `sidebar`: **disabled** (impunham workspace-na-atual + sidebar/file-tree).
- `sessions-view` (AI Sessions) e `Full Setup` (macOS, inerte no Linux): enabled.
- Plugin próprio `herdr-sessoes` (tentativa com workspaces): descartado (não hibernava).

## Para testar depois

- **Alternativa no Emacs** (`doom/.config/doom/lisp/sessoes.el`): cada projeto é um
  workspace do Doom (sessão) com tabs próprias (tab-bar): 1 = código, 2 = terminal
  para arrancar a AI; `M-1..M-9` trocam de tab, `SPC a t` abre mais (terminal/claude/
  codex, várias AIs ao mesmo tempo). Sessões gravadas e restauradas com as tabs; cada
  claude retoma a sua conversa (`--session-id`/`--resume`), um claude arrancado à mão
  volta com `--continue`. Listadas no dashboard; `SPC a k` para a sessão e liberta a
  RAM. Testar no dia-a-dia e comparar.

## Notas / limitações

- Enquanto saltas entre sessões, as que estão abertas continuam a correr; só poupas
  RAM parando as idle à mão (`herdr session stop`).
- `alt+s`/`alt+a` ficam livres dentro do herdr (ver comentário no `config.toml`).
