function ligar --description "Arranca (via Docker) e liga a uma base de dados da disciplina"
    if test (count $argv) -eq 0; or contains -- --help $argv; or contains -- -h $argv
        echo "Uso: ligar <mysql|oracle|sqlserver>"
        echo ""
        echo "Arranca o container Docker da base de dados pedida (via Colima) e"
        echo "mostra os dados de ligação para usar no TablePlus / DbSchema."
        echo "Depois da primeira ligação guardada na app, basta correr 'ligar <alvo>'"
        echo "antes de abrir o TablePlus/DbSchema."
        return 0
    end

    set -l compose_dir ~/docker/bases-dados
    set -l compose_file "$compose_dir/docker-compose.yml"
    set -l alvo $argv[1]

    if not test -f "$compose_file"
        echo "Não encontrei $compose_file"
        return 1
    end

    if not docker info >/dev/null 2>&1
        echo "A iniciar o Colima…"
        colima start
        or return 1
    end

    switch $alvo
        case mysql
            echo "A ligar o MySQL…"
            docker compose -f "$compose_file" up -d mysql
            or return 1

            echo -n "A aguardar que o MySQL fique pronto"
            set -l tentativas 0
            while not docker exec bd-mysql mysqladmin ping -h localhost -u root -proot --silent >/dev/null 2>&1
                echo -n "."
                sleep 1
                set tentativas (math $tentativas + 1)
                if test $tentativas -ge 120
                    echo ""
                    echo "O MySQL está a demorar demasiado. Vê os logs com: docker compose -f $compose_file logs mysql"
                    return 1
                end
            end
            echo ""
            echo ""
            echo "MySQL pronto. Dados para o TablePlus / DbSchema:"
            echo "  Tipo:        MySQL"
            echo "  Host:        localhost"
            echo "  Porta:       3306"
            echo "  Utilizador:  bd   (password: bd)"
            echo "  Base:        bd"
            echo "  (root / root também disponível)"

        case oracle
            echo "A ligar o Oracle…"
            docker compose -f "$compose_file" up -d oracle
            or return 1

            echo -n "A aguardar que o Oracle fique pronto (pode demorar 1-3 min no 1º arranque)"
            set -l tentativas 0
            while not docker compose -f "$compose_file" logs oracle 2>/dev/null | grep -q "DATABASE IS READY TO USE"
                echo -n "."
                sleep 3
                set tentativas (math $tentativas + 1)
                if test $tentativas -ge 100
                    echo ""
                    echo "O Oracle está a demorar demasiado. Vê os logs com: docker compose -f $compose_file logs oracle"
                    return 1
                end
            end
            echo ""
            echo ""
            echo "Oracle pronto. Dados para o TablePlus / DbSchema:"
            echo "  Tipo:        Oracle"
            echo "  Host:        localhost"
            echo "  Porta:       1521"
            echo "  Service:     FREEPDB1   (é o pluggable DB; 'FREE' é só a raiz/CDB e não tem o user bd)"
            echo "  Utilizador:  bd   (password: bd)"
            echo "  (system / oracle também disponível, mas em FREE)"

        case sqlserver
            echo "A ligar o SQL Server…"
            docker compose -f "$compose_file" up -d sqlserver
            or return 1

            echo -n "A aguardar que o SQL Server fique pronto"
            set -l tentativas 0
            while not docker exec bd-sqlserver /opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa -P "Bd_1234!" -Q "SELECT 1" >/dev/null 2>&1
                echo -n "."
                sleep 1
                set tentativas (math $tentativas + 1)
                if test $tentativas -ge 120
                    echo ""
                    echo "O SQL Server está a demorar demasiado. Vê os logs com: docker compose -f $compose_file logs sqlserver"
                    return 1
                end
            end
            echo ""
            echo ""
            echo "SQL Server pronto. Dados para o TablePlus / DbSchema:"
            echo "  Tipo:        SQL Server (Microsoft)"
            echo "  Host:        localhost"
            echo "  Porta:       1433"
            echo "  Utilizador:  sa   (password: Bd_1234!)"
            echo "  Base:        master"

        case '*'
            echo "Alvo desconhecido: $alvo"
            echo "Uso: ligar <mysql|oracle|sqlserver>"
            return 1
    end
end
