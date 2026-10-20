function sessoes --description "Escolhe com o fzf uma sessão do herdr para abrir"
    if contains -- --help $argv; or contains -- -h $argv
        echo "Uso: sessoes"
        echo ""
        echo "Lista as sessões do herdr criadas pelo abrir (a correr ou paradas)"
        echo "com a pasta de cada uma e entra na que escolheres. Se estava parada,"
        echo "o herdr repõe as tabs e os painéis."
        return 0
    end

    set -l linhas
    for s in (herdr session list --json | jq -r '.sessions[] | "\(.name)\t\(.running)\t\(.session_dir)\t\(.default)"')
        set -l campos (string split \t -- $s)
        set -l estado (test "$campos[2]" = true; and echo "a correr"; or echo "parada")
        # A sessão principal tem vários workspaces (do abrir antigo): mostra os nomes
        if test "$campos[4]" = true
            set -l nomes (jq -r '[.workspaces[] | .custom_name // (.identity_cwd | split("/") | last)] | join(", ")' $campos[3]/session.json 2>/dev/null)
            test -n "$nomes"; or continue
            set -a linhas (printf '%s\t%s\t%s' $campos[1] $estado "[$nomes]")
            continue
        end
        set -l cwd (jq -r '.workspaces[0].identity_cwd // "?"' $campos[3]/session.json 2>/dev/null; or echo "?")
        set -a linhas (printf '%s\t%s\t%s' $campos[1] $estado (string replace -r "^$HOME" '~' -- $cwd))
    end
    if test (count $linhas) -eq 0
        echo "Ainda não tens sessões. Cria uma com: abrir [pasta]"
        return 1
    end

    set -l escolha (printf '%s\n' $linhas | column -t -s \t | fzf --prompt "sessão> " --height 40% --reverse)
    or return 0
    set -l sessao (string split -f1 ' ' -- $escolha)

    if test "$HERDR_ENV" = 1
        echo "Sai desta sessão (detach) e corre: herdr --session $sessao"
        return 0
    end
    herdr --session $sessao
end
