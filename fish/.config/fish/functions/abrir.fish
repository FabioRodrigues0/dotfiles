function abrir --description "Abre uma pasta numa sessão própria do herdr (emacs, shell, lazygit)"
    if contains -- --help $argv; or contains -- -h $argv
        echo "Uso: abrir [pasta]"
        echo ""
        echo "Cada pasta tem a sua sessão no herdr, por isso só vês esse projeto."
        echo "Se a sessão já existir, entra nela (se estava parada, o herdr repõe"
        echo "as tabs). Se não existir, cria-a com 3 tabs: Emacs, shell e lazygit."
        echo "Para escolher entre as sessões que já tens: sessoes"
        return 0
    end

    set -l pasta (path resolve -- (test (count $argv) -gt 0; and echo $argv[1]; or echo .))
    if not test -d "$pasta"
        echo "Não encontrei a pasta $pasta"
        return 1
    end
    set -l nome (path basename -- $pasta)
    set -l sessao (string replace -ra '[^A-Za-z0-9._-]' '-' -- $nome)

    # Outra pasta com o mesmo nome já tem a sessão: junta o nome da pasta-mãe
    set -l json ~/.config/herdr/sessions/$sessao/session.json
    if test -f $json
        set -l cwd (jq -r '.workspaces[0].identity_cwd // empty' $json)
        if test -n "$cwd"; and test "$cwd" != "$pasta"
            set sessao (string replace -ra '[^A-Za-z0-9._-]' '-' -- (path basename -- (path dirname -- $pasta)))-$sessao
        end
    end

    # emacs / Emacs.app (macOS) — o binário no PATH costuma chamar-se igual nos dois
    set -l emacs_bin emacs
    if not command -q emacs; and test -x /Applications/Emacs.app/Contents/MacOS/Emacs
        set emacs_bin /Applications/Emacs.app/Contents/MacOS/Emacs
    end

    if not herdr session list --json | jq -e --arg s $sessao '.sessions[] | select(.name == $s)' >/dev/null
        command herdr --session $sessao server >/dev/null 2>&1 &
        disown
        set -l tentativas 0
        while not herdr --session $sessao status server 2>/dev/null | string match -q "status: running"
            sleep 0.1
            set tentativas (math $tentativas + 1)
            if test $tentativas -ge 50
                echo "O servidor do herdr não arrancou."
                return 1
            end
        end

        set -l created (herdr --session $sessao workspace create --cwd $pasta --label $nome --focus)
        or return 1
        set -l ws (echo $created | jq -r .result.workspace.workspace_id)
        set -l emacs_pane (echo $created | jq -r .result.root_pane.pane_id)
        herdr --session $sessao pane run $emacs_pane $emacs_bin -nw . >/dev/null

        herdr --session $sessao tab create --workspace $ws --cwd $pasta --no-focus >/dev/null
        set -l git (herdr --session $sessao tab create --workspace $ws --cwd $pasta --label git --no-focus | jq -r .result.root_pane.pane_id)
        herdr --session $sessao pane run $git lazygit >/dev/null
    end

    env -u HERDR_ENV herdr session attach $sessao
end
