function cursor-bricks --description 'Esconde do jdtls do Cursor os tipos que colidem com o Bricks'
    if contains -- --help $argv
        echo "Uso: cursor-bricks [pasta]"
        echo ""
        echo "Junta java.completion.filteredTypes ao .vscode/settings.json do"
        echo "projeto (por defeito a pasta atual), como o java-bricks.el no Emacs."
        echo "Sem isto o organize imports nao escolhe entre Bricks e JavaFX."
        echo "Liga tambem o organize imports ao gravar (imports dos snippets b...)."
        return 0
    end

    set raiz (realpath (string length -q -- $argv[1]; and echo $argv[1]; or echo .))

    # A propria lib nao conta: o <groupId> dela nao esta dentro de <dependency>
    set pom_bricks '<dependency><groupId>[^<]*fabiorodrigues[^<]*</groupId><artifactId>bricks</artifactId>'
    if not grep -qsiE 'fabiorodrigues0?:bricks:|requires +(transitive +)?fabiorodrigues\.bricks' \
            $raiz/build.gradle $raiz/build.gradle.kts $raiz/src/main/java/module-info.java
        and not begin
            test -f $raiz/pom.xml; and tr -d ' \t\r\n' <$raiz/pom.xml | grep -qi $pom_bricks
        end
        echo "Projeto em $raiz nao usa o Bricks"
        return 1
    end

    if not command -q jq
        echo "Falta o jq"
        return 1
    end

    # Mesma lista que fabio/bricks--tipos-filtrados (doom/lisp/java-bricks.el)
    set tipos \
        # Valores por defeito do jdtls (o setting substitui-os, nao acrescenta)
        'java.awt.*' 'com.sun.*' 'sun.*' 'jdk.*' 'org.graalvm.*' \
        'io.micrometer.shaded.*' \
        # Colidem com nomes do Bricks
        'javafx.scene.control.*' 'javafx.scene.text.Text' \
        'javafx.scene.image.Image' 'javafx.scene.effect.*' \
        'javax.swing.*' 'javax.management.*' \
        'java.lang.reflect.Modifier' 'java.lang.Thread.State' \
        'java.util.Calendar'

    set settings $raiz/.vscode/settings.json
    mkdir -p $raiz/.vscode
    test -s $settings; or echo '{}' >$settings

    # Os snippets do Cursor nao conseguem meter imports (no Emacs faz-o o
    # fabio/bricks-import): o organize imports ao gravar trata disso
    set novo (jq --args '."java.completion.filteredTypes" = $ARGS.positional
        | ."java.saveActions.organizeImports" = true' $tipos <$settings)
    or begin
        echo "Nao consegui ler $settings (tem comentarios?)"
        return 1
    end
    printf '%s\n' $novo >$settings
    echo "Tipos do JavaFX/AWT escondidos e organize imports ao gravar em $settings"
end
