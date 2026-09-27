function desligar --description "Para o(s) container(s) Docker da(s) base(s) de dados da disciplina"
    if contains -- --help $argv; or contains -- -h $argv
        echo "Uso: desligar [mysql|oracle|sqlserver|todos]"
        echo ""
        echo "Para o container Docker da base de dados pedida. Sem argumento, ou"
        echo "com 'todos', para todas (mysql, oracle e sqlserver)."
        return 0
    end

    set -l compose_dir ~/docker/bases-dados
    set -l compose_file "$compose_dir/docker-compose.yml"
    set -l alvo todos
    if test (count $argv) -ge 1
        set alvo $argv[1]
    end

    if not test -f "$compose_file"
        echo "Não encontrei $compose_file"
        return 1
    end

    switch $alvo
        case mysql
            echo "A desligar o MySQL…"
            docker compose -f "$compose_file" stop mysql

        case oracle
            echo "A desligar o Oracle…"
            docker compose -f "$compose_file" stop oracle

        case sqlserver
            echo "A desligar o SQL Server…"
            docker compose -f "$compose_file" stop sqlserver

        case todos all
            echo "A desligar o MySQL, o Oracle e o SQL Server…"
            docker compose -f "$compose_file" stop

        case '*'
            echo "Alvo desconhecido: $alvo"
            echo "Uso: desligar [mysql|oracle|sqlserver|todos]"
            return 1
    end
end
