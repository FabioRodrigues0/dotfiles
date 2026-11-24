function agente-ficheiros --description "Fuzzy picker para ficheiros do agente/git abertos no Helix em nova tab"
    if contains -- --help $argv; or contains -- -h $argv
        echo "Uso: agente-ficheiros"
        echo ""
        echo "Lista os ficheiros modificados pelo agente e pelo Git usando o fzf,"
        echo "abrindo o ficheiro escolhido numa nova tab do Herdr com o Helix."
        return 0
    end

    set -l lista

    # 1. Ficheiros com alterações no Git (uncommitted, unstaged, untracked)
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1
        for f in (git status --short 2>/dev/null | awk '{print $NF}')
            test -f "$f"; and not contains -- "$f" $lista; and set -a lista "$f"
        end

        # Ficheiros do commit mais recente
        for f in (git diff-tree --no-commit-id --name-only -r HEAD 2>/dev/null)
            test -f "$f"; and not contains -- "$f" $lista; and set -a lista "$f"
        end
    end

    # 2. Se houver agente ativo no Herdr, extrai referências do seu ecrã/histórico
    if test "$HERDR_ENV" = 1; or herdr api status >/dev/null 2>&1
        set -l agent_pane (herdr agent list 2>/dev/null | jq -r '.result.agents[0].pane_id // empty')
        if test -n "$agent_pane"
            set -l agent_out (herdr agent read $agent_pane --lines 100 2>/dev/null)
            for token in (string split " " -- (string replace -ra '[│┃╭╮╰╯─━═├┤●∴`"\'\(\)\[\]]' ' ' -- $agent_out))
                set -l limpo (string trim -- $token)
                # Remove eventual sufixo :linha para testar existência do ficheiro
                set -l sem_linha (string replace -r ':[0-9]+.*$' '' -- $limpo)
                if test -f "$sem_linha"; and not contains -- "$limpo" $lista
                    set -a lista "$limpo"
                end
            end
        end
    end

    # Se nada tiver sido tocado recentemente, lista ficheiros do repositório
    if test (count $lista) -eq 0
        if git rev-parse --is-inside-work-tree >/dev/null 2>&1
            set lista (git ls-files 2>/dev/null)
        else if command -q fd
            set lista (fd --type f --max-depth 4 2>/dev/null)
        end
    end

    if test (count $lista) -eq 0
        echo "Nenhum ficheiro encontrado."
        return 1
    end

    set -l preview_cmd "head -n 50 (string replace -r ':[0-9]+.*\$' '' -- {})"
    if command -q bat
        set preview_cmd "bat --color=always --line-range :50 (string replace -r ':[0-9]+.*\$' '' -- {})"
    end

    set -l escolha (printf '%s\n' $lista | fzf --prompt "agente/git > " --height 80% --reverse --preview "$preview_cmd")
    or return 0

    abrir-hx "$escolha"
end
