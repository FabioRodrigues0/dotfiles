#!/bin/bash

################################################################################
# novo-cs.sh
#
# Script para criar projetos C# (.NET, aplicação de consola) simples.
# Invocado via:  novo cs <nome_projeto> [titulo] [FLAGS]
#
# Flags:
#   --classico       Program.cs com class Program + Main (em vez de top-level)
#   --disc "UC"      Unidade curricular (adiciona tags ao .md)
#   --no-md          Não criar ficheiro .md
#   --help           Mostrar ajuda
#
# Compatibilidade: Linux + macOS (Homebrew) — requer o .NET SDK
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
FLAG_CLASSICO=false
FLAG_NO_MD=false

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
║         NOVO C# — Criação Automática de Projeto           ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝

USO:
    novo cs <nome_projeto> [titulo] [FLAGS]

PARÂMETROS:
    nome_projeto    Nome da pasta do projeto (ex: ex_01)
    titulo          Título para documentação — opcional,
                    usa o nome do projeto se omitido

FLAGS OPCIONAIS:
    --classico          class Program + Main (em vez de top-level statements)
    --disc "UC"         Unidade curricular (tags no .md)
    --no-md             Não criar ficheiro .md
    --help              Mostrar esta ajuda

EXEMPLOS:
    novo cs ex_01 "Exercício 1"
    novo cs ex_02 "Exercício 2" --classico
    novo cs ex_03 --no-md

CONFIGURAÇÕES:
    • Aplicação de consola (dotnet new console)
    • Estrutura flat: <nome>/<nome>.csproj + Program.cs
    • Executar: dotnet run   (ou: correr)

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
            --classico) FLAG_CLASSICO=true ;;
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
    if ! command -v dotnet &>/dev/null; then
        print_error ".NET SDK não está instalado!"
        echo ""
        echo "Instalar com:"
        echo "  mise use -g dotnet@10"
        exit 1
    fi

    if [ -d "$NOME_PROJETO" ]; then
        print_error "Diretório '$NOME_PROJETO' já existe!"
        exit 1
    fi

    # O nome vira o nome do assembly/namespace — evitar caracteres inválidos
    if ! [[ "$NOME_PROJETO" =~ ^[A-Za-z_][A-Za-z0-9_.-]*$ ]]; then
        print_error "Nome inválido '$NOME_PROJETO' (usa letras, números, _ . -; não começar por número)"
        exit 1
    fi
}

create_project() {
    print_header "Criando Projeto C#"

    local ARGS=(console -n "$NOME_PROJETO" -o "$NOME_PROJETO" --no-restore)
    [ "$FLAG_CLASSICO" = true ] && ARGS+=(--use-program-main)

    # DOTNET_NOLOGO/TELEMETRY: saída limpa, sem banner nem telemetria
    DOTNET_NOLOGO=1 DOTNET_CLI_TELEMETRY_OPTOUT=1 dotnet new "${ARGS[@]}" >/dev/null
    cd "$NOME_PROJETO"
    print_success "Projeto criado ($([ "$FLAG_CLASSICO" = true ] && echo 'class Program' || echo 'top-level statements'))"

    DOTNET_NOLOGO=1 dotnet new gitignore >/dev/null
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
        echo "  - conceito/csharp"
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

- \`Program.cs\` - Ponto de entrada
- \`${NOME_PROJETO}.csproj\` - Configuração do projeto

## Como executar

\`\`\`bash
# Compilar e executar
dotnet run

# Só compilar
dotnet build

# Limpar build
dotnet clean
\`\`\`
EOF
    print_success "${NOME_PROJETO}.md criado"
}

validate_build() {
    print_header "Validando Projeto"
    print_info "Executando compilação inicial..."
    if DOTNET_NOLOGO=1 dotnet build -v q --nologo >/dev/null 2>&1; then
        print_success "Compilação executada com sucesso"
    else
        print_warning "Compilação falhou — projeto criado mas pode ter erros"
        print_info "Execute 'dotnet build' para ver os erros"
    fi
}

show_success_message() {
    local CURRENT_PATH
    CURRENT_PATH=$(pwd)
    local SDK_VERSION
    SDK_VERSION=$(dotnet --version 2>/dev/null || echo "?")

    echo ""
    print_header "PROJETO C# CRIADO COM SUCESSO!"
    echo ""
    echo -e "${GREEN}📁 Projeto:${NC}     ${NOME_PROJETO}"
    echo -e "${GREEN}📍 Localização:${NC} ${CURRENT_PATH}"
    [ "$FLAG_NO_MD" = false ] && echo -e "${GREEN}📄 Docs:${NC}        ${NOME_PROJETO}.md"
    echo ""
    echo -e "${CYAN}🔧 Configurações:${NC}"
    echo "   • .NET SDK ${SDK_VERSION} | Consola | Ponto de entrada: Program.cs"
    echo ""
    echo -e "${YELLOW}📝 Próximos passos:${NC}"
    echo ""
    echo "   1. cd ${NOME_PROJETO}"
    echo "   2. zed .        # Abrir no Zed"
    echo "   3. dotnet run   # Executar"
    echo "      (ou: correr)"
    echo ""
    echo -e "${BLUE}💡 Comandos úteis:${NC}"
    echo ""
    echo "   dotnet run     # Compilar e executar"
    echo "   dotnet build   # Só compilar"
    echo "   dotnet clean   # Limpar build"
    echo ""
}

main() {
    parse_arguments "$@"
    validate_environment
    create_project
    create_markdown
    validate_build
    show_success_message
}

main "$@"
