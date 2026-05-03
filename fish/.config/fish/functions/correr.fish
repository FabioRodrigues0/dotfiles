function correr --description "Deteta o projeto e corre-o"
    if contains -- --help $argv
        echo "Uso: correr"
        echo ""
        echo "Deteta automaticamente o tipo de projeto e executa-o."
        echo ""
        echo "Projetos suportados:"
        echo "  build.gradle / build.gradle.kts  →  ./gradlew run"
        echo "  pom.xml (Spring Boot)            →  mvn spring-boot:run"
        echo "  pom.xml                          →  mvn compile exec:java"
        echo "  package.json                     →  pnpm start"
        echo "  pyproject.toml                   →  python -m <módulo>"
        echo "  main.py                          →  python main.py"
        echo "  Makefile                         →  make run"
        return 0
    end

    set dir (pwd)

    while test "$dir" != "/"
        # Gradle
        if test -f "$dir/build.gradle" -o -f "$dir/build.gradle.kts"
            echo "Projeto Gradle detetado em $dir"
            cd "$dir"
            ./gradlew run
            return $status
        end

        # Maven — Spring Boot
        if test -f "$dir/pom.xml"
            if grep -q "spring-boot" "$dir/pom.xml" 2>/dev/null
                echo "Projeto Spring Boot detetado em $dir"
                cd "$dir"
                mvn spring-boot:run
                return $status
            else
                echo "Projeto Maven detetado em $dir"
                cd "$dir"
                mvn compile exec:java
                return $status
            end
        end

        # Node
        if test -f "$dir/package.json"
            echo "Projeto Node detetado em $dir"
            cd "$dir"
            pnpm start
            return $status
        end

        # Python — pyproject.toml
        if test -f "$dir/pyproject.toml"
            set modulo (string replace -r '/' '.' (basename $dir))
            echo "Projeto Python detetado em $dir"
            cd "$dir"
            python -m $modulo
            return $status
        end

        # Python — main.py
        if test -f "$dir/main.py"
            echo "main.py detetado em $dir"
            cd "$dir"
            python main.py
            return $status
        end

        # Make
        if test -f "$dir/Makefile"
            echo "Makefile detetado em $dir"
            cd "$dir"
            make run
            return $status
        end

        # Subir um nível
        set dir (dirname $dir)
    end

    echo "Nenhum projeto reconhecido encontrado."
    return 1
end
