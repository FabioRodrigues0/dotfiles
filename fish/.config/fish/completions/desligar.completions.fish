# ════════════════════════════════════════════════════════════════════════════
# desligar.fish — Completions
#
# Localização: ~/.config/fish/completions/desligar.fish
# ════════════════════════════════════════════════════════════════════════════

complete -c desligar -f

complete -c desligar -n "test (count (commandline -opc)) -eq 1" -a "mysql"     -d "Desligar o MySQL"
complete -c desligar -n "test (count (commandline -opc)) -eq 1" -a "oracle"    -d "Desligar o Oracle"
complete -c desligar -n "test (count (commandline -opc)) -eq 1" -a "sqlserver" -d "Desligar o SQL Server"
complete -c desligar -n "test (count (commandline -opc)) -eq 1" -a "todos"     -d "Desligar mysql, oracle e sqlserver"

complete -c desligar -l help -d "Mostrar ajuda"
complete -c desligar -s h    -d "Mostrar ajuda"
