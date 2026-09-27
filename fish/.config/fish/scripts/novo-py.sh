#!/bin/bash

################################################################################
# novo-py.sh
#
# Script para criar projetos Python simples (um main.py, sem venv/uv).
# Invocado via:  novo py <nome_projeto> [titulo] [FLAGS]
#
# Flags:
#   --disc "UC"      Unidade curricular (adiciona tags ao .md)
#   --no-md          Não criar ficheiro .md
#   --help           Mostrar ajuda
#
# O Python vem do mise (mise use -g python@latest).
# Compatibilidade: Linux + macOS
################################################################################

set -e

# ── Cores ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ── Flags globais ─────────────────────────────────────────────────────────────
NOME_PROJETO=""
TITULO=""
DISCIPLINA=""
FLAG_NO_MD=false
PY=""   # comando python detetado (python ou python3)

print_error()   { echo -e "${RED}❌ ERRO: $1${NC}" >&2; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_info()    { echo -e "${CYAN}ℹ️  $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_header() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
}

show_help() {
    cat << EOF
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║        NOVO PYTHON — Criação Automática de Projeto        ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝

USO:
    novo py <nome_projeto> [titulo] [FLAGS]

PARÂMETROS:
    nome_projeto    Nome da pasta do projeto (ex: ex_01)
    titulo          Título para documentação — opcional,
                    usa o nome do projeto se omitido

FLAGS OPCIONAIS:
    --disc "UC"         Unidade curricular (tags no .md)
    --no-md             Não criar ficheiro .md
    --help              Mostrar esta ajuda

EXEMPLOS:
    novo py ex_01 "Exercício 1"
    novo py ex_02 "Exercício 2" --disc PC
    novo py ex_03 --no-md

CONFIGURAÇÕES:
    • Estrutura flat: <nome>/main.py
    • Sem venv nem dependências (projeto simples)
    • Python via mise:  mise use -g python@latest
    • Executar: python main.py   (ou: correr)

EOF
}

parse_arguments() {
    if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        show_help
        exit 0
    fi

    if [ $# -lt 1 ]; then
        print_error "Número insuficiente de argumentos"
        echo ""
        show_help
        exit 1
    fi

    NOME_PROJETO="$1"
    shift 1

    if [ $# -gt 0 ] && [[ "$1" != --* ]]; then
        TITULO="$1"
        shift 1
    else
        TITULO="$NOME_PROJETO"
    fi

    while [ $# -gt 0 ]; do
        case "$1" in
            --no-md)    FLAG_NO_MD=true ;;
            --disc)
                if [ $# -lt 2 ]; then
                    print_error "--disc requer um valor"
                    exit 1
                fi
                DISCIPLINA="$2"
                shift
                ;;
            --help|-h)  show_help; exit 0 ;;
            *)
                print_error "Flag desconhecida: $1"
                echo ""
                show_help
                exit 1
                ;;
        esac
        shift
    done
}

validate_environment() {
    if command -v python &>/dev/null; then
        PY=python
    elif command -v python3 &>/dev/null; then
        PY=python3
        print_warning "Comando 'python' não encontrado — a usar python3 ($($PY --version 2>&1))"
        print_info "Para usar o Python do mise: mise use -g python@latest"
    else
        print_error "Python não está instalado!"
        echo ""
        echo "Instalar com:"
        echo "  mise use -g python@latest"
        exit 1
    fi

    if [ -d "$NOME_PROJETO" ]; then
        print_error "Diretório '$NOME_PROJETO' já existe!"
        exit 1
    fi
}

create_project() {
    print_header "Criando Projeto Python"

    mkdir -p "$NOME_PROJETO"
    cd "$NOME_PROJETO"

    cat > main.py << 'EOF'
def main():
    print("Hello, World!")


if __name__ == "__main__":
    main()
EOF
    print_success "main.py criado"

    local ENTRIES=("__pycache__/" "*.pyc" ".venv/" ".idea/" ".vscode/" ".zed/" ".DS_Store")
    for entry in "${ENTRIES[@]}"; do
        echo "$entry" >> .gitignore
    done
    print_success ".gitignore criado"
}

create_markdown() {
    if [ "$FLAG_NO_MD" = true ]; then
        print_info "Ficheiro .md não criado (--no-md)"
        return
    fi

    local DATA_ATUAL
    DATA_ATUAL=$(date +%d-%m-%Y)

    {
        echo "---"
        echo "tags:"
        [ -n "$DISCIPLINA" ] && echo "  - contexto/${DISCIPLINA}"
        echo "  - tipo/trabalho_pratico"
        echo "  - conceito/python"
        echo "  - area/programacao"
        echo "data: ${DATA_ATUAL}"
        if [ -n "$DISCIPLINA" ]; then
            echo "disciplina:"
            echo "  - ${DISCIPLINA}"
        fi
        echo "---"
    } > "${NOME_PROJETO}.md"

    cat >> "${NOME_PROJETO}.md" << EOF
# ${TITULO}

## Descrição

${TITULO}

## Estrutura do Projeto

- \`main.py\` - Ponto de entrada

## Como executar

\`\`\`bash
python main.py
\`\`\`

## Dependências

- **$($PY --version 2>&1)**
EOF
    print_success "${NOME_PROJETO}.md criado"
}

validate_project() {
    print_header "Validando Projeto"
    # ast.parse valida a sintaxe sem criar __pycache__
    if "$PY" -c "import ast; ast.parse(open('main.py').read())" 2>/dev/null; then
        print_success "Sintaxe validada"
    else
        print_warning "main.py com erros de sintaxe"
    fi
}

show_success_message() {
    local CURRENT_PATH
    CURRENT_PATH=$(pwd)

    echo ""
    print_header "PROJETO PYTHON CRIADO COM SUCESSO!"
    echo ""
    echo -e "${GREEN}📁 Projeto:${NC}     ${NOME_PROJETO}"
    echo -e "${GREEN}📍 Localização:${NC} ${CURRENT_PATH}"
    [ "$FLAG_NO_MD" = false ] && echo -e "${GREEN}📄 Docs:${NC}        ${NOME_PROJETO}.md"
    echo ""
    echo -e "${CYAN}🔧 Configurações:${NC}"
    echo "   • $($PY --version 2>&1) | Ponto de entrada: main.py"
    echo ""
    echo -e "${YELLOW}📝 Próximos passos:${NC}"
    echo ""
    echo "   1. cd ${NOME_PROJETO}"
    echo "   2. zed .              # Abrir no Zed"
    echo "   3. python main.py     # Executar"
    echo "      (ou: correr)"
    echo ""
}

main() {
    parse_arguments "$@"
    validate_environment
    create_project
    create_markdown
    validate_project
    show_success_message
}

main "$@"
