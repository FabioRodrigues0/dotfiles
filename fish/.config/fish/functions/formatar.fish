function formatar --description 'Formata um ficheiro com o Spotless do projeto Gradle'
    if test (count $argv) -ne 1; or contains -- --help $argv
        echo "Uso: formatar <ficheiro>"
        echo ""
        echo "Procura o projeto Gradle do ficheiro e, se usar Spotless,"
        echo "formata so esse ficheiro (spotlessApply com spotlessIdeHook)."
        return 0
    end

    set file (realpath $argv[1])
    set dir (dirname $file)

    while test "$dir" != "/"
        for build in $dir/build.gradle $dir/build.gradle.kts
            if test -f $build
                if not grep -qw spotless $build
                    echo "Projeto Gradle sem Spotless em $dir"
                    return 0
                end
                cd $dir
                ./gradlew spotlessApply -q -PspotlessIdeHook=$file
                and echo "Formatado com Spotless: "(basename $file)
                return $status
            end
        end
        set dir (dirname $dir)
    end

    echo "Nao encontrei projeto Gradle para $file"
end
