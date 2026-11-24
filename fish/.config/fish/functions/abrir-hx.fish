function abrir-hx --description "Abre uma tab no Herdr no caminho atual (ou ficheiro) com o Helix"
    if contains -- --help $argv; or contains -- -h $argv
        echo "Uso: abrir-hx [ficheiro ou pasta]"
        echo ""
        echo "Abre uma nova tab no Herdr focada na pasta atual com o Helix (hx)."
        echo "Se fornecido um ficheiro, abre o Helix diretamente nesse ficheiro (e linha se path:line)."
        echo "Se não estiver dentro do Herdr, abre o hx no terminal atual."
        return 0
    end

    set -l alvo (test (count $argv) -gt 0; and echo $argv[1]; or echo .)
    set -l cwd (pwd)

    # Determinar a diretoria base caso o alvo seja um ficheiro (mesmo com :linha)
    set -l f_sem_linha (string replace -r ':[0-9]+.*$' '' -- "$alvo")
    if test -f "$f_sem_linha"
        set cwd (path dirname -- (path resolve -- "$f_sem_linha"))
    end

    # Verifica se estamos dentro do Herdr
    if test "$HERDR_ENV" = 1; or herdr api status >/dev/null 2>&1
        set -l label "hx"
        if test "$alvo" != "."
            set label (path basename -- "$f_sem_linha")
        end

        set -l res (herdr tab create --cwd "$cwd" --label "$label" --focus 2>/dev/null)
        set -l pane_id (echo $res | jq -r '.result.root_pane.pane_id // empty')

        if test -n "$pane_id"
            herdr pane run $pane_id hx $alvo >/dev/null
            return 0
        end
    end

    # Fallback caso esteja fora do Herdr ou a API não responda
    hx $alvo
end
