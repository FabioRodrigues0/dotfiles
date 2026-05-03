function pandoc-convert
    pandoc $argv[1] \
        -o (string replace '.md' '.pdf' $argv[1]) \
        --pdf-engine=lualatex \
        --from markdown+raw_tex \
        --citeproc \
        -V lang=pt
end
