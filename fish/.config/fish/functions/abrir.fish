function abrir --description "Abre uma pasta no herdr com 3 tabs (a 3ª já com o lazygit)"
    if contains -- --help $argv; or contains -- -h $argv
        echo "Uso: abrir [pasta]"
        echo ""
        echo "Cria um workspace no herdr para a pasta (por omissão a atual) com"
        echo "3 tabs: as duas primeiras só com a shell na pasta e a terceira já"
        echo "com o lazygit aberto. Se não estiveres dentro do herdr, entra nele."
        return 0
    end

    set -l pasta (path resolve -- (test (count $argv) -gt 0; and echo $argv[1]; or echo .))
    if not test -d "$pasta"
        echo "Não encontrei a pasta $pasta"
        return 1
    end
    set -l nome (path basename -- $pasta)

    if not herdr status server 2>/dev/null | string match -q "status: running"
        command herdr server >/dev/null 2>&1 &
        disown
        set -l tentativas 0
        while not herdr status server 2>/dev/null | string match -q "status: running"
            sleep 0.1
            set tentativas (math $tentativas + 1)
            if test $tentativas -ge 50
                echo "O servidor do herdr não arrancou."
                return 1
            end
        end
    end

    set -l ws (herdr workspace create --cwd $pasta --label $nome --focus | jq -r .result.workspace.workspace_id)
    or return 1
    herdr tab create --workspace $ws --cwd $pasta --no-focus >/dev/null
    set -l git (herdr tab create --workspace $ws --cwd $pasta --label git --no-focus | jq -r .result.root_pane.pane_id)
    herdr pane run $git lazygit >/dev/null

    if test "$HERDR_ENV" != 1
        herdr
    end
end
