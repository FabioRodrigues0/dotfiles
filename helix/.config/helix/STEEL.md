# Helix + Steel (plugins) — para experimentar depois

Estado (nov 2026): o sistema de plugins **Steel** ainda **não está no Helix estável**.
Vive no fork do autor, `mattwparas/helix`, branch `steel-event-system` (PR upstream
[#8675](https://github.com/helix-editor/helix/pull/8675), ainda aberto). Para já ficámos
no Helix do Homebrew (`hx 25.07`); esta nota é só o caminho para incorporar quando quiseres.

## O que muda ao incorporar

- O `hx` deixa de ser o do Homebrew e passa a ser um compilado à mão (`~/.cargo/bin/hx`).
- Perdes o `brew upgrade helix`: as atualizações passam a ser `git pull` + recompilar.
- Ganhas `forge` (gestor de plugins Steel) e a config em Scheme (`~/.config/helix/init.scm`).

## Como compilar (tens rust pelo mise)

```fish
git clone https://github.com/mattwparas/helix ~/src/helix-steel
cd ~/src/helix-steel
git checkout steel-event-system
cargo xtask steel     # compila e instala hx, forge e o steel-language-server em ~/.cargo/bin
```

Depois garante que o `~/.cargo/bin` vem antes do `/opt/homebrew/bin` no PATH (ou
`brew unlink helix`), confirma com `which hx`. As runtime queries/themes ficam em
`~/.config/helix/runtime` (o `cargo xtask steel` trata disto, ou `hx --grammar fetch`).

## Config em Steel

- `~/.config/helix/init.scm` — ponto de entrada (equivalente "scriptável" do config).
- Plugins instalam-se com `forge` (ex.: `forge pkg install --git <url>`).
- Exemplos da comunidade: `hxwiki` (wiki tipo vimwiki), statusline custom, code-actions-on-save.

## Reverter

`brew link helix` (ou tirar `~/.cargo/bin` da frente do PATH) e voltas ao Helix estável.
O `config.toml`/`language.toml` deste repo continuam a valer nos dois.
