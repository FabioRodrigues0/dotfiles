# ════════════════════════════════════════════════════════════════════════════
# novo.fish — Completions
#
# Localização: ~/.config/fish/completions/novo.fish
# ════════════════════════════════════════════════════════════════════════════

# Desativar completions de ficheiros por padrão
complete -c novo -f

# Linguagens disponíveis (primeiro argumento)
complete -c novo -n "test (count (commandline -opc)) -eq 1" -a "java"  -d "Projeto Java com Gradle"
complete -c novo -n "test (count (commandline -opc)) -eq 1" -a "typst" -d "Documento / Relatório Typst"

# Flags Java (quando o primeiro arg é "java")
complete -c novo -n "__fish_seen_subcommand_from java" -l junit       -d "Adicionar JUnit 6.0.3"
complete -c novo -n "__fish_seen_subcommand_from java" -l javafx      -d "Adicionar JavaFX base (controls + fxml)"
complete -c novo -n "__fish_seen_subcommand_from java" -l javafx-web  -d "Adicionar JavaFX Web (requer --javafx)"
complete -c novo -n "__fish_seen_subcommand_from java" -l javafx-media -d "Adicionar JavaFX Media (requer --javafx)"
complete -c novo -n "__fish_seen_subcommand_from java" -l javafx-full -d "Adicionar todos os módulos JavaFX"
complete -c novo -n "__fish_seen_subcommand_from java" -l bricks      -d "Usar Bricks UI (incompatível com --javafx)"
complete -c novo -n "__fish_seen_subcommand_from java" -l no-md       -d "Não criar ficheiro .md"
complete -c novo -n "__fish_seen_subcommand_from java" -l help        -d "Mostrar ajuda detalhada"

# Flags Typst (quando o primeiro arg é "typst")
complete -c novo -n "__fish_seen_subcommand_from typst" -l academico -d "Template relatório académico (ISPGAYA)"
complete -c novo -n "__fish_seen_subcommand_from typst" -l tecnico   -d "Template documentação técnica"
complete -c novo -n "__fish_seen_subcommand_from typst" -l help      -d "Mostrar ajuda detalhada"

# Help global
complete -c novo -l help -d "Mostrar ajuda"
complete -c novo -s h    -d "Mostrar ajuda"
