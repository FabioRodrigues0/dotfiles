#!/bin/bash

################################################################################
# novo-typst.sh
#
# Invocado via:  novo typst <nome> [titulo] [FLAGS]
#
# FLAGS:
#   --separado          Conteúdo em ficheiros separados (default — relatórios longos)
#   --junto             Tudo num só main.typ (relatórios curtos)
#   --autores "N1, N2"  Autores
#   --disc "UC"         Unidade curricular
#   --orient "Prof."    Orientador
#   --no-md             Sem ficheiro .md
#   --instalar          (Re)instala o template @local e sai
#   --help
#
# Template armazenado centralmente em @local — não duplicado por projeto.
# Linux : ~/.local/share/typst/packages/local/ispgaya-relatorio/0.1.0/
# macOS : ~/Library/Application Support/typst/packages/local/ispgaya-relatorio/0.1.0/
################################################################################

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

# Captura qualquer erro e mostra linha + comando
trap 'echo -e "${RED}❌ Erro na linha $LINENO: $BASH_COMMAND${NC}" >&2' ERR

# ── Constantes do pacote ──────────────────────────────────────────────────────
PKG_NAME="ispgaya-relatorio"
PKG_VERSION="0.1.0"
ASSETS_DIR="$HOME/.config/fish/scripts/assets"
LOGO_PATH="$ASSETS_DIR/logo_faculdade.png"
INSTITUICAO="Instituto Superior Politécnico Gaya"
CURSO="Engenharia Informática"

# ── Flags ─────────────────────────────────────────────────────────────────────
NOME_PROJETO=""
TITULO=""
AUTORES=""
DISCIPLINA=""
ORIENTADOR=""
FLAG_SEPARADO=true    # default
FLAG_NO_MD=false
FLAG_INSTALAR=false

print_error()   { echo -e "${RED}❌ ERRO: $1${NC}" >&2; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_info()    { echo -e "${CYAN}ℹ️  $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_header()  {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
}

################################################################################
# Path do diretório @local (detecta OS)
################################################################################

_get_local_pkg_dir() {
    local base
    case "$(uname -s)" in
        Darwin*) base="$HOME/Library/Application Support/typst/packages/local" ;;
        Linux*)  base="${XDG_DATA_HOME:-$HOME/.local/share}/typst/packages/local" ;;
        *)       base="$HOME/.local/share/typst/packages/local" ;;
    esac
    echo "$base/$PKG_NAME/$PKG_VERSION"
}

_get_install_typst_cmd() {
    case "$(uname -s)" in
        Darwin*)  echo "brew install typst" ;;
        Linux*)
            if   command -v pacman  &>/dev/null; then echo "sudo pacman -S typst"
            elif command -v apt-get &>/dev/null; then echo "sudo apt install typst"
            elif command -v dnf     &>/dev/null; then echo "sudo dnf install typst"
            else echo "cargo install typst-cli"
            fi ;;
        *) echo "https://github.com/typst/typst/releases" ;;
    esac
}

show_help() {
    cat << EOF
╔═══════════════════════════════════════════════════════════╗
║       NOVO TYPST — Relatório Académico ISPGAYA            ║
╚═══════════════════════════════════════════════════════════╝

USO:
    novo typst <nome> [titulo] [FLAGS]
    novo typst --instalar           # instala/atualiza o template @local

MODOS DE CONTEÚDO:
    --separado    Ficheiros separados por secção  [default — relatórios longos]
    --junto       Tudo num só main.typ            [relatórios curtos]

OUTROS FLAGS:
    --autores "Nome1, Nome2"
    --disc    "Unidade Curricular"
    --orient  "Prof. Nome"
    --no-md
    --help

EXEMPLOS:
    novo typst relatorio_04 "Relatório 4" --disc "AM2"
    novo typst relatorio_04 "Relatório 4" --autores "Fábio, Rodrigo" --junto
    novo typst --instalar

LOGO (uma vez por máquina):
    cp logo_faculdade.png $ASSETS_DIR/

ESTRUTURA --separado:
    relatorio_04/
    ├── main.typ
    ├── conteudo/
    │   ├── introducao.typ
    │   ├── desenvolvimento.typ
    │   └── conclusao.typ
    ├── assets/imagens/
    ├── biblio.bib
    └── relatorio_04.md

ESTRUTURA --junto:
    relatorio_04/
    ├── main.typ          ← tudo aqui
    ├── assets/imagens/
    ├── biblio.bib
    └── relatorio_04.md

TEMPLATE @local:
    $(_get_local_pkg_dir)/
EOF
}

################################################################################
# Parse de argumentos
################################################################################

parse_arguments() {
    [ "$1" = "--help" ] || [ "$1" = "-h" ] && { show_help; exit 0; }
    [ "$1" = "--instalar" ] && { FLAG_INSTALAR=true; return; }

    [ $# -lt 1 ] && { print_error "Argumentos insuficientes"; echo ""; show_help; exit 1; }

    NOME_PROJETO="$1"; shift

    [[ $# -gt 0 && "$1" != --* ]] && { TITULO="$1"; shift; } || TITULO="$NOME_PROJETO"

    while [ $# -gt 0 ]; do
        case "$1" in
            --separado)        FLAG_SEPARADO=true ;;
            --junto)           FLAG_SEPARADO=false ;;
            --autores) shift;  AUTORES="$1" ;;
            --disc)    shift;  DISCIPLINA="$1" ;;
            --orient)  shift;  ORIENTADOR="$1" ;;
            --no-md)           FLAG_NO_MD=true ;;
            --instalar)        FLAG_INSTALAR=true ;;
            --help|-h)         show_help; exit 0 ;;
            *) print_error "Flag desconhecida: $1"; echo ""; show_help; exit 1 ;;
        esac
        shift
    done
}

################################################################################
# Instalar/atualizar o template no diretório @local
################################################################################

install_local_template() {
    local PKG_DIR
    PKG_DIR="$(_get_local_pkg_dir)"

    print_header "A instalar template @local"
    print_info "Destino: $PKG_DIR"

    # mkdir com -p lida com paths com espaços desde que quoted
    mkdir -p "$PKG_DIR" || {
        print_error "Não foi possível criar o diretório: $PKG_DIR"
        exit 1
    }

    # ── typst.toml ────────────────────────────────────────────────────────────
    cat > "$PKG_DIR/typst.toml" << EOF
[package]
name        = "$PKG_NAME"
version     = "$PKG_VERSION"
entrypoint  = "lib.typ"
authors     = ["Fábio Rodrigues"]
description = "Template para relatórios académicos do ISPGAYA (guião 2025)"
compiler    = "0.11.0"
EOF

    # ── lib.typ ───────────────────────────────────────────────────────────────
    # Logo hardcoded no template — path fixa, sempre presente
    cat > "$PKG_DIR/lib.typ" << TYPST_EOF
// ════════════════════════════════════════════════════════════════════════════
// ispgaya-relatorio — Template académico ISPGAYA
// @local/$PKG_NAME:$PKG_VERSION
//
// Guião de Redação e Formatação de Trabalhos Académicos do ISPGAYA
// 2.ª edição, fevereiro 2025
//
// Margens : Top 2,54 | Esq 3,81 | Dir 2,54 | Inf 2,54  (cm)
// Fonte   : Times New Roman 12pt
// Espaç.  : 1,5 linhas | Parágrafo: 1,25cm indent
// Págs.   : romana (índice) → árabe (corpo), canto inf. direito
//
// Exporta:
//   relatorio(...)      — função de show rule principal
//   secao_sem_numero(t) — heading sem numeração (Introdução / Conclusão)
//   nota_fonte(body)    — nota de fonte em figuras e tabelas
// ════════════════════════════════════════════════════════════════════════════

#let INSTITUICAO = "$INSTITUICAO"
#let CURSO = "$CURSO"
#let LOGO_PATH = "$LOGO_PATH"

// ── Heading sem numeração (Introdução / Conclusão — guião 3.1) ───────────────
#let secao_sem_numero(titulo) = {
  pagebreak(weak: true)
  v(1em)
  text(size: 14pt, weight: "bold")[#titulo]
  v(0.5em)
}

// ── Nota de fonte para figuras e tabelas (guião 3.2.4) ───────────────────────
// Uso: #nota_fonte[Retirado de Autor (2024, p. 10).]
#let nota_fonte(body) = {
  v(0.2em)
  text(size: 10pt, style: "italic")[Nota. #body]
}

// ── Função principal ─────────────────────────────────────────────────────────
#let relatorio(
  titulo: "",
  subtitulo: "",
  autores: (),
  numeros: (),
  disciplina: "",
  orientador: "",
  data: "",
  body,
) = {

  set document(title: titulo, author: autores)

  // Página base
  set page(
    paper: "a4",
    margin: (top: 2.54cm, left: 3.81cm, right: 2.54cm, bottom: 2.54cm),
  )

  // Tipografia — Times New Roman 12pt (guião 3.1)
  set text(font: "Times New Roman", size: 12pt, lang: "pt")

  // Parágrafos — 1,5 linhas, indent 1,25cm (guião 3.1)
  set par(
    justify:           true,
    leading:           0.65em,
    spacing:           1.2em,
    first-line-indent: 1.25cm,
  )

  // Headings numerados (guião 3.1 — exceto Introdução/Conclusão)
  set heading(numbering: "1.1.")

  show heading.where(level: 1): it => {
    pagebreak(weak: true)
    v(1em)
    text(size: 14pt, weight: "bold", it)
    v(0.5em)
  }
  show heading.where(level: 2): it => {
    v(0.8em)
    text(size: 13pt, weight: "bold", it)
    v(0.4em)
  }
  show heading.where(level: 3): it => {
    v(0.5em)
    text(size: 12pt, weight: "bold", it)
    v(0.25em)
  }

  // Figuras — número + título em cima, alinhado à esquerda, 10pt itálico
  set figure(numbering: "1", gap: 0.5em)
  show figure.caption: it => {
    set text(size: 10pt, style: "italic")
    align(left)[
      #it.supplement #it.counter.display(it.numbering)
      #linebreak()
      #it.body
    ]
  }

  // Código
  show raw.where(block: true): block.with(
    fill: luma(245), inset: (x: 1em, y: 0.75em), radius: 4pt, width: 100%,
  )
  show raw.where(block: false): box.with(
    fill: luma(245), inset: (x: 0.3em, y: 0.15em), radius: 3pt,
  )

  // ── CAPA ─────────────────────────────────────────────────────────────────
  page(
    numbering: none,
    margin: (top: 2.54cm, bottom: 2.54cm, left: 2.54cm, right: 2.54cm),
  )[
    #align(center)[
      #v(2cm)
      #if LOGO_PATH != "" {
        image(LOGO_PATH, width: 30%)
        v(1.5cm)
      } else { v(1.5cm) }

      #text(size: 18pt, weight: "bold")[#INSTITUICAO]
      #v(0.3cm)
      #text(size: 13pt)[#CURSO]
      #v(2cm)

      #text(size: 22pt, weight: "bold")[#titulo]
      #if subtitulo != "" { v(0.3cm); text(size: 14pt)[#subtitulo] }
      #v(1cm)

      #for (i, autor) in autores.enumerate() {
        text(size: 13pt)[#autor]
        if i < numeros.len() {
          text(size: 11pt, fill: luma(100))[ — n.º #numeros.at(i)]
        }
        linebreak()
      }
      #v(0.8cm)
      #if disciplina != "" { text(size: 12pt)[#disciplina]; linebreak() }
      #if orientador != "" {
        v(0.3cm)
        text(size: 11pt, fill: luma(80))[Orientado por #orientador]
      }
      #v(1fr)
      #text(size: 12pt)[#data]
      #v(0.5cm)
    ]
  ]

  // ── ÍNDICE (numeração romana — guião 3.2.4) ───────────────────────────────
  set page(numbering: "i", number-align: bottom + right)
  counter(page).update(1)
  outline(title: [Índice], depth: 3, indent: 1.5em)

  // Reset do counter de headings — o outline incrementa-o internamente
  counter(heading).update(0)

  // ── CORPO (numeração árabe — guião 3.2.4) ────────────────────────────────
  pagebreak()
  set page(
    numbering: "1",
    number-align: bottom + right,
    header: context {
      if here().page() > 1 [
        #grid(
          columns: (1fr, 1fr),
          align(left,  text(size: 9pt, fill: luma(120))[#titulo]),
          align(right, text(size: 9pt, fill: luma(120))[#disciplina]),
        )
        #line(length: 100%, stroke: 0.4pt + luma(200))
        #v(-0.3em)
      ]
    },
  )
  counter(page).update(1)

  body
}
TYPST_EOF

    print_success "Template instalado em: $PKG_DIR"
    echo ""
    echo "Para usar nos relatórios:"
    echo "  #import \"@local/${PKG_NAME}:${PKG_VERSION}\": relatorio, secao_sem_numero, nota_fonte"
    echo ""
}

################################################################################
# Validações
################################################################################

validate_environment() {
    if ! command -v typst &>/dev/null; then
        print_error "Typst não está instalado!"
        echo "  $(_get_install_typst_cmd)"; exit 1
    fi

    local PKG_DIR; PKG_DIR="$(_get_local_pkg_dir)"
    if [ ! -f "$PKG_DIR/lib.typ" ]; then
        print_warning "Template @local não encontrado — a instalar automaticamente..."
        install_local_template
    fi

    if [ -d "$NOME_PROJETO" ]; then
        print_error "Diretório '$NOME_PROJETO' já existe!"
        exit 1
    fi

    if [ ! -f "$LOGO_PATH" ]; then
        print_warning "Logo não encontrado em: $LOGO_PATH"
        echo "         mkdir -p $ASSETS_DIR && cp logo_faculdade.png $ASSETS_DIR/"
    fi

    return 0
}

################################################################################
# Helpers de geração
################################################################################

_data_pt() {
    date +"%B de %Y" | sed \
        -e 's/January/Janeiro/'    -e 's/February/Fevereiro/' \
        -e 's/March/Março/'        -e 's/April/Abril/' \
        -e 's/May/Maio/'           -e 's/June/Junho/' \
        -e 's/July/Julho/'         -e 's/August/Agosto/' \
        -e 's/September/Setembro/' -e 's/October/Outubro/' \
        -e 's/November/Novembro/'  -e 's/December/Dezembro/'
}

_autores_typst() {
    if [ -n "$AUTORES" ]; then
        echo "($(echo "$AUTORES" | sed 's/,\s*/", "/g' | sed 's/^/"/' | sed 's/$/"/'))"
    else
        echo '("Fábio Rodrigues")'
    fi
}

_biblio_bib() {
    cat << 'EOF'
% Referências bibliográficas — BibTeX (APA 7ª edição)
% Exportar do Zotero como Better BibTeX
%
% Ativar em main.typ:
%   #bibliography("biblio.bib", style: "apa", title: "Referências Bibliográficas")
%
% @book{sobrenome2024,
%   author    = {Sobrenome, Nome},
%   title     = {Título do Livro},
%   year      = {2024},
%   publisher = {Editora},
% }
% @article{sobrenome2024a,
%   author  = {Sobrenome, Nome},
%   title   = {Título},
%   journal = {Revista},
%   year    = {2024},
%   volume  = {1},
%   pages   = {1--10},
%   doi     = {10.xxxx/xxxxx},
% }
% @online{sobrenome2024b,
%   author  = {Sobrenome, Nome},
%   title   = {Título},
%   year    = {2024},
%   url     = {https://exemplo.com},
%   urldate = {2024-04-20},
% }
EOF
}

################################################################################
# Criar projeto — SEPARADO (default)
################################################################################

create_separado() {
    print_header "Criando Relatório (separado)"

    mkdir -p "$NOME_PROJETO"/{conteudo,assets/imagens}
    cd "$NOME_PROJETO"

    local DATA; DATA="$(_data_pt)"
    local AUTORES_T; AUTORES_T="$(_autores_typst)"
    local DISC="${DISCIPLINA:-Disciplina}"
    local ORIENT="${ORIENTADOR:-}"

    # ── main.typ ──────────────────────────────────────────────────────────────
    cat > main.typ << EOF
#import "@local/${PKG_NAME}:${PKG_VERSION}": relatorio

#show: relatorio.with(
  titulo:      "${TITULO}",
  subtitulo:   "",                      // apagar se não usar
  autores:     ${AUTORES_T},
  numeros:     ("000000",),             // nº de aluno por autor
  disciplina:  "${DISC}",
  orientador:  "${ORIENT}",            // apagar se não tiver orientador
  data:        "${DATA}",
)

// ── Conteúdo ──────────────────────────────────────────────────────────────────

#include "conteudo/introducao.typ"
#include "conteudo/desenvolvimento.typ"
#include "conteudo/conclusao.typ"

// ── Referências bibliográficas ────────────────────────────────────────────────
// #bibliography("biblio.bib", style: "apa", title: "Referências Bibliográficas")
EOF
    print_info "main.typ criado"

    # ── typst.toml de projeto (diz ao LSP para usar main.typ como raiz) ──────
    cat > typst.toml << 'EOF'
[project]
main = "main.typ"
EOF

    # ── .zed/settings.json (Zed: tinymist sempre compila main.typ) ───────────
    mkdir -p .zed
    cat > .zed/settings.json << 'EOF'
{
  "lsp": {
    "tinymist": {
      "settings": {
        "exportPdf": "onType",
        "rootPath": "."
      }
    }
  }
}
EOF
    print_info "typst.toml + .zed/settings.json criados"

    # ── conteudo/introducao.typ ───────────────────────────────────────────────
    # Importa secao_sem_numero do @local para funcionar em scope isolado
    cat > conteudo/introducao.typ << EOF
#import "@local/${PKG_NAME}:${PKG_VERSION}": secao_sem_numero

#secao_sem_numero[Introdução]

// Enquadramento do tema
// Objetivos
// Estrutura do relatório
EOF

    # ── conteudo/desenvolvimento.typ ──────────────────────────────────────────
    cat > conteudo/desenvolvimento.typ << EOF
// Substituir "Desenvolvimento" pelo título real do capítulo
= Desenvolvimento

== Secção

Conteúdo.

=== Subsecção

Conteúdo.

// ── Figura ────────────────────────────────────────────────────────────────────
// #import "@local/${PKG_NAME}:${PKG_VERSION}": nota_fonte
// #figure(
//   image("../assets/imagens/exemplo.png", width: 80%),
//   caption: [Título da figura],
// )
// #nota_fonte[Retirado de Autor (2024, p. 5).]

// ── Tabela ────────────────────────────────────────────────────────────────────
// #figure(
//   table(
//     columns: (auto, auto, auto),
//     [Col 1], [Col 2], [Col 3],
//     [L 1],   [Dado],  [Dado],
//   ),
//   caption: [Título da tabela],
// )
// #nota_fonte[Elaboração própria.]

// ── Equação ───────────────────────────────────────────────────────────────────
// \$ f(x, y) = x^2 + x y \$
EOF

    # ── conteudo/conclusao.typ ────────────────────────────────────────────────
    cat > conteudo/conclusao.typ << EOF
#import "@local/${PKG_NAME}:${PKG_VERSION}": secao_sem_numero

#secao_sem_numero[Conclusão]

// Síntese do trabalho
// Objetivos alcançados / por cumprir
// Limitações e trabalho futuro
// Sem citações nem referências (guião 3.2.2)
EOF

    _biblio_bib > biblio.bib
    print_info "conteudo/ + biblio.bib criados"
}

################################################################################
# Criar projeto — JUNTO
################################################################################

create_junto() {
    print_header "Criando Relatório (junto)"

    mkdir -p "$NOME_PROJETO"/assets/imagens
    cd "$NOME_PROJETO"

    local DATA; DATA="$(_data_pt)"
    local AUTORES_T; AUTORES_T="$(_autores_typst)"
    local DISC="${DISCIPLINA:-Disciplina}"
    local ORIENT="${ORIENTADOR:-}"

    local LOGO_PARAM=""  # removido — logo está hardcoded no template via --instalar

    cat > main.typ << EOF
#import "@local/${PKG_NAME}:${PKG_VERSION}": relatorio, secao_sem_numero, nota_fonte

#show: relatorio.with(
  titulo:      "${TITULO}",
  subtitulo:   "",
  autores:     ${AUTORES_T},
  numeros:     ("000000",),
  disciplina:  "${DISC}",
  orientador:  "${ORIENT}",
  data:        "${DATA}",
)

// ════════════════════════════════════════════════════════════════════════════
// Introdução
// ════════════════════════════════════════════════════════════════════════════

#secao_sem_numero[Introdução]

// Enquadramento do tema.
// Objetivos.
// Estrutura do relatório.


// ════════════════════════════════════════════════════════════════════════════
// Desenvolvimento
// ════════════════════════════════════════════════════════════════════════════

= Desenvolvimento

== Secção

Conteúdo.

=== Subsecção

Conteúdo.

// ── Figura ─────────────────────────────────────────────────────────────────
// #figure(
//   image("assets/imagens/exemplo.png", width: 80%),
//   caption: [Título da figura],
// )
// #nota_fonte[Retirado de Autor (2024, p. 5).]

// ── Equação ────────────────────────────────────────────────────────────────
// \$ f(x, y) = x^2 + x y \$


// ════════════════════════════════════════════════════════════════════════════
// Conclusão
// ════════════════════════════════════════════════════════════════════════════

#secao_sem_numero[Conclusão]

// Síntese do trabalho.
// Objetivos alcançados / por cumprir.
// Sem citações nem referências (guião 3.2.2).


// ════════════════════════════════════════════════════════════════════════════
// Referências bibliográficas
// ════════════════════════════════════════════════════════════════════════════

// #bibliography("biblio.bib", style: "apa", title: "Referências Bibliográficas")
EOF
    print_info "main.typ criado (tudo junto)"

    # ── typst.toml de projeto + .zed/settings.json ────────────────────────────
    cat > typst.toml << 'EOF'
[project]
main = "main.typ"
EOF
    mkdir -p .zed
    cat > .zed/settings.json << 'EOF'
{
  "lsp": {
    "tinymist": {
      "settings": {
        "exportPdf": "onType",
        "rootPath": "."
      }
    }
  }
}
EOF
    print_info "typst.toml + .zed/settings.json criados"

    _biblio_bib > biblio.bib
    print_info "biblio.bib criado"
}

################################################################################
# Ficheiro .md
################################################################################

create_markdown_file() {
    [ "$FLAG_NO_MD" = true ] && return

    local MODO; $FLAG_SEPARADO && MODO="separado" || MODO="junto"

    cat > "${NOME_PROJETO}.md" << EOF
---
tags:
  - tipo/relatorio_typst
  - contexto/academico
data: $(date +%d-%m-%Y)
disciplina: "${DISCIPLINA:-}"
---
# ${TITULO}

## Compilar

\`\`\`bash
typst compile main.typ
typst watch main.typ
\`\`\`

## Template

- Pacote: \`@local/${PKG_NAME}:${PKG_VERSION}\`
- Modo: ${MODO}
- Guião ISPGAYA 2025

## Referências (APA 7)

1. Exportar Zotero → \`biblio.bib\`
2. Descomentar \`#bibliography\` em \`main.typ\`
EOF
    print_info "${NOME_PROJETO}.md criado"
}

################################################################################
# Mensagem final
################################################################################

show_success_message() {
    local MODO; $FLAG_SEPARADO && MODO="separado (ficheiros separados)" || MODO="junto (ficheiro único)"
    local PKG_DIR; PKG_DIR="$(_get_local_pkg_dir)"

    echo ""
    print_header "RELATÓRIO CRIADO COM SUCESSO!"
    echo ""
    echo -e "${GREEN}📁 Projeto:${NC}  ${NOME_PROJETO}"
    echo -e "${GREEN}📦 Template:${NC} @local/${PKG_NAME}:${PKG_VERSION}"
    echo -e "${GREEN}📄 Modo:${NC}     ${MODO}"
    [ -n "$DISCIPLINA" ] && echo -e "${GREEN}📚 UC:${NC}       ${DISCIPLINA}"
    [ "$FLAG_NO_MD" = false ] && echo -e "${GREEN}📝 Notas:${NC}    ${NOME_PROJETO}.md"
    echo ""

    [ ! -f "$LOGO_PATH" ] && {
        echo -e "${YELLOW}⚠️  Logo em falta:${NC}"
        echo "   cp logo_faculdade.png $ASSETS_DIR/"
        echo ""
    }

    echo -e "${YELLOW}📌 Preencher em main.typ:${NC}"
    [ -z "$AUTORES" ]    && echo "   • autores, numeros"
    [ -z "$DISCIPLINA" ] && echo "   • disciplina"
    echo ""
    echo -e "${CYAN}💡 Próximos passos:${NC}"
    echo "   cd ${NOME_PROJETO} && typst watch main.typ"
    echo ""
    echo -e "${BLUE}ℹ️  Para atualizar o template:${NC} novo typst --instalar"
    echo ""
}

################################################################################
# MAIN
################################################################################

main() {
    parse_arguments "$@"

    if $FLAG_INSTALAR; then
        install_local_template
        exit 0
    fi

    local ORIG_DIR
    ORIG_DIR="$(pwd)"

    validate_environment

    if $FLAG_SEPARADO; then
        create_separado
    else
        create_junto
    fi

    # Voltar à pasta original para criar o .md ao lado do projeto
    cd "$ORIG_DIR"
    create_markdown_file
    show_success_message
}

main "$@"
