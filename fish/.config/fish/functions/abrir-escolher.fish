function abrir-escolher --description "Escolhe com o fzf uma pasta para abrir numa sessão própria do herdr"
    if contains -- --help $argv; or contains -- -h $argv
        echo "Uso: abrir-escolher"
        echo ""
        echo "Lista pastas de projetos (zoxide, sessões existentes e pastas comuns)"
        echo "para escolher com o fzf e abrir numa sessão própria do herdr."
        return 0
    end

    set -l caminhos
    set -l home_real (path resolve "$HOME")

    # 1. Pastas das sessões já existentes do herdr
    for s in (herdr session list --json 2>/dev/null | jq -r '.sessions[] | .session_dir' 2>/dev/null)
        set -l cwd (jq -r '.workspaces[0].identity_cwd // empty' "$s/session.json" 2>/dev/null)
        test -n "$cwd"; and test -d "$cwd"; and set -a caminhos (path resolve "$cwd")
    end

    # 2. Histórico do zoxide
    if command -q zoxide
        for z in (zoxide query -l 2>/dev/null)
            test -d "$z"; and set -a caminhos (path resolve "$z")
        end
    end

    # 3. Pastas de topo comuns
    set -a caminhos (path resolve "$HOME/.dotfiles")
    for d in ~/Documents ~/Projects ~/Desktop ~/flathub ~/into ~/src ~/workspace
        test -d "$d"; and set -a caminhos (path resolve "$d")
    end

    # 4. Pesquisa de subdiretórios com fd ou find
    set -l bases
    for d in ~/Documents ~/.dotfiles ~/Projects ~/Desktop ~/flathub ~/into
        test -d "$d"; and set -a bases "$d"
    end

    if test (count $bases) -gt 0
        if command -q fd
            set -a caminhos (fd --type d --min-depth 1 --max-depth 4 --hidden --exclude .git --exclude node_modules --exclude .cache --exclude .local --exclude target . $bases 2>/dev/null)
        else
            set -a caminhos (find $bases -maxdepth 4 -type d -not -path '*/.*' 2>/dev/null)
        end
    end

    # Formatar com ~ e remover duplicados
    set -l lista
    for c in $caminhos
        test -d "$c"; or continue
        set -l resolvido (path resolve "$c")
        test "$resolvido" = "$home_real"; and continue
        set -l formatado (string replace -r "^($HOME|$home_real)" '~' -- "$resolvido")
        contains -- "$formatado" $lista; or set -a lista "$formatado"
    end

    if test (count $lista) -eq 0
        echo "Nenhuma pasta encontrada."
        return 1
    end

    set -l res (printf '%s\n' $lista | fzf --prompt "pasta > " --height 100% --reverse --print-query)
    or return 0

    set -l query $res[1]
    set -l selecionado (test (count $res) -ge 2; and echo $res[2]; or echo "")

    set -l pasta_escolhida
    if test -n "$selecionado"
        set pasta_escolhida (string replace -r "^~" "$HOME" -- $selecionado)
    else if test -n "$query"
        set -l expandido (string replace -r "^~" "$HOME" -- $query)
        if test -d "$expandido"
            set pasta_escolhida "$expandido"
        end
    end

    test -n "$pasta_escolhida"; or return 0
    abrir "$pasta_escolhida"
end
