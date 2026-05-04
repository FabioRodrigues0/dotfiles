# ════════════════════════════════════════════════════════════════════════════
# novo.fish — Criador de projetos genérico
#
# Localização: ~/.config/fish/functions/novo.fish
# Auto-carregado pelo Fish (não precisa de source)
#
# Uso:
#   novo java   <nome> [titulo] [flags]
#   novo typst  <nome> [titulo] [flags]
#   novo --help
#
# Para adicionar uma nova linguagem no futuro:
#   1. Criar ~/.config/fish/scripts/novo-<linguagem>.sh
#   2. Adicionar um case aqui em baixo
# ════════════════════════════════════════════════════════════════════════════

function novo --description "Criar novo projeto de programação"
    set -l scripts_dir "$HOME/.config/fish/scripts"

    # ── Sem argumentos ou --help ─────────────────────────────────────────────
    if test (count $argv) -eq 0
        _novo_help
        return 0
    end

    if test "$argv[1]" = "--help"; or test "$argv[1]" = "-h"
        _novo_help
        return 0
    end

    # ── Dispatch por linguagem ───────────────────────────────────────────────
    set -l lang $argv[1]
    set -l rest $argv[2..]

    switch $lang
        case java
            set -l script "$scripts_dir/novo-java.sh"
            if not test -f "$script"
                echo "❌ Script não encontrado: $script"
                echo "   Corre o instalador: bash install.sh"
                return 1
            end
            bash "$script" $rest

        case typst
            set -l script "$scripts_dir/novo-typst.sh"
            if not test -f "$script"
                echo "❌ Script não encontrado: $script"
                echo "   Corre o instalador: bash install.sh"
                return 1
            end
            bash "$script" $rest

        case --help -h
            _novo_help
            return 0

        case '*'
            echo "❌ Linguagem '$lang' não reconhecida."
            echo ""
            _novo_help
            return 1
    end
end

# ── Função de ajuda (privada, prefixo _ para não aparecer no autocomplete) ──
function _novo_help
    echo ""
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║              NOVO — Criador de Projetos                   ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo ""
    echo "USO:"
    echo "   novo <linguagem> <nome> [titulo] [flags]"
    echo ""
    echo "LINGUAGENS DISPONÍVEIS:"
    echo "   java     Projeto Java com Gradle (padrão) ou Maven (--maven)"
    echo "   typst    Documento / Relatório Typst"
    echo ""
    echo "EXEMPLOS:"
    echo "   novo java ex_01 \"Exercício 1 - Threads\""
    echo "   novo java ex_02 \"Exercício 2\" --junit"
    echo "   novo java ex_03 \"Exercício 3\" --maven"
    echo "   novo java ex_04 \"Exercício 4\" --maven --junit"
    echo "   novo java app_01 \"Calculadora\" --javafx"
    echo "   novo java proj_01 \"CRUD Completo\" --bricks"
    echo "   novo typst relatorio_01 \"Relatório 1 - SO\" --academico"
    echo "   novo typst doc_01 \"Documentação API\" --tecnico"
    echo ""
    echo "FLAGS JAVA:"
    echo "   --maven          Projeto Maven simples (incompatível com --javafx, --bricks)"
    echo "   --junit          JUnit (Gradle: 6.0.3 / Maven: 5.10.2)"
    echo "   --javafx         JavaFX base (controls + fxml)"
    echo "   --javafx-web     JavaFX Web (requer --javafx)"
    echo "   --javafx-media   JavaFX Media (requer --javafx)"
    echo "   --javafx-full    Todos os módulos JavaFX"
    echo "   --bricks         Bricks UI (incompatível com --javafx)"
    echo "   --no-md          Não criar ficheiro .md"
    echo ""
    echo "FLAGS TYPST:"
    echo "   --academico      Template relatório académico (ISPGAYA)"
    echo "   --tecnico        Template documentação técnica"
    echo ""
    echo "AJUDA DETALHADA POR LINGUAGEM:"
    echo "   novo java --help"
    echo "   novo typst --help"
    echo ""
end
