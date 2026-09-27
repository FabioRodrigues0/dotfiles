# ════════════════════════════════════════════════════════════════════════════
# ligar.fish — Completions
#
# Localização: ~/.config/fish/completions/ligar.fish
# ════════════════════════════════════════════════════════════════════════════

complete -c ligar -f

complete -c ligar -n "test (count (commandline -opc)) -eq 1" -a "mysql"     -d "Ligar ao MySQL"
complete -c ligar -n "test (count (commandline -opc)) -eq 1" -a "oracle"    -d "Ligar ao Oracle"
complete -c ligar -n "test (count (commandline -opc)) -eq 1" -a "sqlserver" -d "Ligar ao SQL Server"

complete -c ligar -l help -d "Mostrar ajuda"
complete -c ligar -s h    -d "Mostrar ajuda"
