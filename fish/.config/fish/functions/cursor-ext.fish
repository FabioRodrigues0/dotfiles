function cursor-ext --description 'Sincroniza as extensoes do Cursor com o extensions.txt dos dotfiles'
    if contains -- --help $argv
        echo "Uso: cursor-ext [--limpar]"
        echo ""
        echo "Instala as extensoes do extensions.txt que faltam."
        echo "Com --limpar desinstala tambem as que nao estao na lista."
        echo ""
        echo "Extensoes so desta maquina vao no extensions.local.txt ao lado"
        echo "(fora dos dotfiles); contam como estando na lista."
        return 0
    end

    if not command -q cursor
        echo "Comando cursor nao encontrado"
        return 1
    end

    if test (uname) = Darwin
        set pasta "$HOME/Library/Application Support/Cursor"
    else
        set pasta $HOME/.config/Cursor
    end
    set lista $pasta/extensions.txt
    set local $pasta/extensions.local.txt

    if not test -f $lista
        echo "Nao encontrei $lista (falta fazer stow do cursor?)"
        return 1
    end

    set querer (cat $lista (test -f $local; and echo $local) | string match -rv '^\s*(#|$)' | string trim | string lower)
    set instaladas (cursor --list-extensions 2>/dev/null | string lower)

    set faltam
    for ext in $querer
        contains -- $ext $instaladas; or set -a faltam $ext
    end

    set extras
    for ext in $instaladas
        contains -- $ext $querer; or set -a extras $ext
    end

    for ext in $faltam
        echo "Instalar: $ext"
        cursor --install-extension $ext 2>/dev/null | string match -q '*successfully*'
        or echo "  falhou: $ext"
    end

    if test (count $extras) -gt 0
        if contains -- --limpar $argv
            for ext in $extras
                echo "Desinstalar: $ext"
                cursor --uninstall-extension $ext >/dev/null 2>&1
                or echo "  falhou: $ext"
            end
        else
            echo "Instaladas mas fora da lista (usa --limpar para remover):"
            printf '  %s\n' $extras
        end
    end

    if test (count $faltam) -eq 0; and test (count $extras) -eq 0
        echo "Extensoes do Cursor em dia"
    end
end
