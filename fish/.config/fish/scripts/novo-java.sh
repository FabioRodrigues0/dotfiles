#!/bin/bash

################################################################################
# novo-java.sh
#
# Script para criar projetos Java com Gradle de forma automatizada.
# Invocado via:  novo java <nome_projeto> [titulo] [FLAGS]
#
# Flags:
#   --junit          Adicionar JUnit 6
#   --javafx         Adicionar JavaFX base (controls + fxml)
#   --javafx-web     Adicionar JavaFX Web (requer --javafx)
#   --javafx-media   Adicionar JavaFX Media (requer --javafx)
#   --javafx-full    Adicionar todos módulos JavaFX
#   --bricks         Usar Bricks (UI declarativa JavaFX + SQLite)
#   --no-md          Não criar ficheiro .md
#   --help           Mostrar ajuda
#
# Compatibilidade: Linux (Arch, Debian, Fedora) + macOS (Homebrew)
################################################################################

set -e

# ── Cores ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ── Versões (atualizar aqui quando necessário) ────────────────────────────────
JUNIT_VERSION="6.0.3"
JAVAFX_VERSION="25.0.2"
CHECKSTYLE_VERSION="13.3.0"
SPOTLESS_VERSION="8.3.0"
JAVA_VERSION="25"
BRICKS_VERSION="latest.release"
SQLITE_VERSION="3.45.1.0"
BRICKS_JAVA_VERSION="21"
BRICKS_JAVAFX_VERSION="21.0.5"

# ── Flags globais ─────────────────────────────────────────────────────────────
NOME_PROJETO=""
TITULO=""
FLAG_JUNIT=false
FLAG_JAVAFX=false
FLAG_JAVAFX_WEB=false
FLAG_JAVAFX_MEDIA=false
FLAG_JAVAFX_FULL=false
FLAG_NO_MD=false
FLAG_BRICKS=false

################################################################################
# Utilidades
################################################################################

print_error()   { echo -e "${RED}❌ ERRO: $1${NC}" >&2; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_info()    { echo -e "${CYAN}ℹ️  $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_header() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
}

# Detetar sistema operativo e sugerir comando de instalação correto
_get_install_cmd() {
    case "$(uname -s)" in
        Darwin*)
            echo "brew install gradle   # ou: mise use -g gradle@latest"
            ;;
        Linux*)
            if command -v pacman &>/dev/null; then
                echo "sudo pacman -S gradle   # ou: mise use -g gradle@latest"
            elif command -v apt-get &>/dev/null; then
                echo "sudo apt install gradle   # ou: mise use -g gradle@latest"
            elif command -v dnf &>/dev/null; then
                echo "sudo dnf install gradle   # ou: mise use -g gradle@latest"
            else
                echo "mise use -g gradle@latest"
            fi
            ;;
        *)
            echo "mise use -g gradle@latest"
            ;;
    esac
}

show_help() {
    cat << EOF
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║         NOVO JAVA — Criação Automática de Projeto        ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝

USO:
    novo java <nome_projeto> [titulo] [FLAGS]

PARÂMETROS:
    nome_projeto    Nome da pasta do projeto (ex: ex_03)
    titulo          Título para documentação — opcional,
                    usa o nome do projeto se omitido

FLAGS OPCIONAIS:
    --junit             Adicionar JUnit ${JUNIT_VERSION}
    --javafx            Adicionar JavaFX ${JAVAFX_VERSION} base (controls + fxml)
    --javafx-web        Adicionar JavaFX Web (requer --javafx)
    --javafx-media      Adicionar JavaFX Media (requer --javafx)
    --javafx-full       Adicionar todos módulos JavaFX
    --bricks            Usar Bricks (UI declarativa JavaFX + SQLite)
                        incompatível com --javafx
    --no-md             Não criar ficheiro .md
    --help              Mostrar esta ajuda

EXEMPLOS:
    novo java ex_03 "Exercício 3 - Threads"
    novo java ex_04 "Exercício 4 - Testes" --junit
    novo java ex_05 "GUI Simples" --javafx
    novo java ex_06 "WebView" --javafx --javafx-web
    novo java ex_07 "Multimedia" --javafx-full
    novo java ex_08 "Completo" --junit --javafx-full
    novo java proj_01 "Projeto 1 - CRUD" --bricks
    novo java proj_02 "Projeto 2 - CRUD + Testes" --bricks --junit
    novo java projeto_fis "Física - Lab" --no-md

CONFIGURAÇÕES:
    • Java ${JAVA_VERSION} (Bricks usa Java ${BRICKS_JAVA_VERSION})
    • Estrutura flat (sem subprojetos, sem packages)
    • Classe principal: App.java
    • Checkstyle ${CHECKSTYLE_VERSION} (Sun/Oracle conventions)
    • Spotless ${SPOTLESS_VERSION} (formatação automática)

EOF
}

################################################################################
# Parsing de argumentos
################################################################################

parse_arguments() {
    if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        show_help
        exit 0
    fi

    if [ $# -lt 1 ]; then
        print_error "Número insuficiente de argumentos"
        echo ""
        show_help
        exit 1
    fi

    NOME_PROJETO="$1"
    shift 1

    # Título opcional — se o próximo arg for uma flag, usa o nome como título
    if [ $# -gt 0 ] && [[ "$1" != --* ]]; then
        TITULO="$1"
        shift 1
    else
        TITULO="$NOME_PROJETO"
    fi

    # Parse flags
    while [ $# -gt 0 ]; do
        case "$1" in
            --junit)         FLAG_JUNIT=true ;;
            --javafx)        FLAG_JAVAFX=true ;;
            --javafx-web)    FLAG_JAVAFX_WEB=true ;;
            --javafx-media)  FLAG_JAVAFX_MEDIA=true ;;
            --javafx-full)
                             FLAG_JAVAFX_FULL=true
                             FLAG_JAVAFX=true
                             ;;
            --bricks)        FLAG_BRICKS=true ;;
            --no-md)         FLAG_NO_MD=true ;;
            --help|-h)       show_help; exit 0 ;;
            *)
                print_error "Flag desconhecida: $1"
                echo ""
                show_help
                exit 1
                ;;
        esac
        shift
    done
}

################################################################################
# Validações
################################################################################

validate_environment() {
    # Verificar se gradle está instalado (sistema ou mise shims)
    if ! command -v gradle &>/dev/null; then
        if [ -d "$HOME/.local/share/mise/shims" ] && [ -x "$HOME/.local/share/mise/shims/gradle" ]; then
            export PATH="$HOME/.local/share/mise/shims:$PATH"
        elif command -v mise &>/dev/null && mise which gradle &>/dev/null 2>&1; then
            export PATH="$(dirname "$(mise which gradle)"):$PATH"
        else
            print_error "Gradle não está instalado!"
            echo ""
            echo "Instalar com:"
            echo "  $(_get_install_cmd)"
            exit 1
        fi
    fi

    # Verificar se diretório já existe
    if [ -d "$NOME_PROJETO" ]; then
        print_error "Diretório '$NOME_PROJETO' já existe!"
        exit 1
    fi

    # Validar flags JavaFX dependentes
    if [ "$FLAG_JAVAFX_WEB" = true ] || [ "$FLAG_JAVAFX_MEDIA" = true ]; then
        if [ "$FLAG_JAVAFX" = false ] && [ "$FLAG_JAVAFX_FULL" = false ]; then
            print_error "--javafx-web e --javafx-media requerem --javafx ou --javafx-full"
            exit 1
        fi
    fi

    # --bricks é incompatível com --javafx
    if [ "$FLAG_BRICKS" = true ]; then
        if [ "$FLAG_JAVAFX" = true ] || [ "$FLAG_JAVAFX_WEB" = true ] || \
           [ "$FLAG_JAVAFX_MEDIA" = true ] || [ "$FLAG_JAVAFX_FULL" = true ]; then
            print_error "A flag --bricks é incompatível com --javafx"
            exit 1
        fi
    fi
}

################################################################################
# Estrutura de diretórios + ficheiros base
################################################################################

create_project_structure() {
    print_header "Criando Estrutura do Projeto"

    print_info "Criando diretório: $NOME_PROJETO"
    mkdir -p "$NOME_PROJETO"
    cd "$NOME_PROJETO"

    print_info "Criando estrutura de diretórios..."
    mkdir -p src/main/java
    mkdir -p src/main/resources

    if [ "$FLAG_JUNIT" = true ]; then
        mkdir -p src/test/java
        mkdir -p src/test/resources
    fi

    # settings.gradle
    cat > settings.gradle << EOF
rootProject.name = '${NOME_PROJETO}'
EOF

    # ── App.java ──────────────────────────────────────────────────────────────
    print_info "Criando App.java..."

    if [ "$FLAG_BRICKS" = true ]; then
        # Pastas extra para Bricks (estilo Laravel)
        mkdir -p config/database
        mkdir -p database/schema
        mkdir -p database/seeds

        # ── App.java ──────────────────────────────────────────────────────────
        cat > src/main/java/App.java << 'EOF'
import fabiorodrigues.bricks.components.*;
import fabiorodrigues.bricks.core.*;
import fabiorodrigues.bricks.style.BricksTheme;
import fabiorodrigues.bricks.style.Modifier;

/**
 * Ponto de entrada da aplicação Bricks.
 * UI declarativa com estado reativo e base de dados SQLite integrada.
 */
public class App extends BricksApplication {

    // ── Estado ────────────────────────────────────────────────────────────────

    private final State<String> titulo = state("Olá, Bricks!");

    {
        setTitle("App");
        // setTheme(BricksTheme.dark()); // descomenta para dark mode
    }

    // ── Effects ───────────────────────────────────────────────────────────────

    // Cria o schema da base de dados no arranque
    private final Effect initDB = effect(() -> DatabaseSchema.create());

    // ── root() ────────────────────────────────────────────────────────────────

    @Override
    public Component root() {
        return new Column()
            .padding(20)
            .gap(12)
            .modifier(new Modifier().fillMaxWidth())
            .children(
                new Text(titulo.get())
                    .modifier(new Modifier().fontSize(24).bold()),
                new Button("Clica-me!")
                    .onClick(() -> titulo.set("Botão clicado!"))
            );
    }

    /**
     * Ponto de entrada da aplicação.
     *
     * @param args argumentos da linha de comandos
     */
    public static void main(String[] args) {
        launch(args);
    }
}
EOF
        print_info "App.java criado (Bricks)"

        # ── config/database/DatabaseConfig.java ───────────────────────────────
        cat > config/database/DatabaseConfig.java << 'EOF'
import fabiorodrigues.bricks.data.DB;
import fabiorodrigues.bricks.data.config.SQLiteConfig;

/**
 * Configuração da ligação à base de dados.
 * Por defeito usa SQLite — cria ./data/database.db automaticamente.
 * Para trocar de base de dados, descomenta a configuração pretendida.
 */
public class DatabaseConfig {

    static {
        // SQLite (padrão) — sem configuração necessária
        DB.configure(new SQLiteConfig());

        // MySQL — descomentar e preencher credenciais
        // DB.configure(new MySQLConfig()
        //     .host("localhost")
        //     .port(3306)
        //     .database("nome_db")
        //     .user("root")
        //     .password("")
        // );

        // PostgreSQL — descomentar e preencher credenciais
        // DB.configure(new PostgreSQLConfig()
        //     .host("localhost")
        //     .database("nome_db")
        //     .user("postgres")
        //     .password("")
        // );
    }
}
EOF
        print_info "DatabaseConfig.java criado"

        # ── database/schema/DatabaseSchema.java ───────────────────────────────
        cat > database/schema/DatabaseSchema.java << 'EOF'
import fabiorodrigues.bricks.data.DB;

/**
 * Define o schema da base de dados.
 * Chamado automaticamente no arranque via Effect em App.java.
 * Adiciona aqui as definições das tabelas.
 */
public class DatabaseSchema {

    private DatabaseSchema() {}

    /**
     * Cria as tabelas se não existirem.
     * Seguro para chamar múltiplas vezes — usa CREATE TABLE IF NOT EXISTS.
     */
    public static void create() {
        // Exemplo — descomenta e adapta:
        // DB.query()
        //     .createTableIfNotExists("exemplo")
        //     .column("id", "INTEGER PRIMARY KEY AUTOINCREMENT")
        //     .column("nome", "TEXT NOT NULL")
        //     .execute();
    }
}
EOF
        print_info "DatabaseSchema.java criado"

        # ── database/seeds/DatabaseSeeder.java ────────────────────────────────
        cat > database/seeds/DatabaseSeeder.java << 'EOF'
import fabiorodrigues.bricks.data.DB;
import java.util.Map;

/**
 * Dados iniciais da base de dados.
 * Chamar DatabaseSeeder.run() no Effect initDB do App.java se necessário.
 * Só deve correr quando a base de dados está vazia.
 */
public class DatabaseSeeder {

    private DatabaseSeeder() {}

    /**
     * Insere dados iniciais nas tabelas.
     * Exemplo de uso no App.java:
     *
     * private final Effect initDB = effect(() -> {
     *     DatabaseSchema.create();
     *     DatabaseSeeder.run();
     * });
     */
    public static void run() {
        // Exemplo — descomenta e adapta:
        // DB.query()
        //     .insertInto("exemplo")
        //     .values(Map.of("nome", "Valor inicial"))
        //     .execute();
    }
}
EOF
        print_info "DatabaseSeeder.java criado"

    elif [ "$FLAG_JAVAFX" = true ] || [ "$FLAG_JAVAFX_FULL" = true ]; then
        cat > src/main/java/App.java << 'EOF'
import javafx.application.Application;
import javafx.geometry.Insets;
import javafx.geometry.Pos;
import javafx.scene.Scene;
import javafx.scene.control.Button;
import javafx.scene.control.Label;
import javafx.scene.layout.VBox;
import javafx.stage.Stage;

/**
 * Aplicação JavaFX com UI criada por código.
 */
public class App extends Application {

    @Override
    public void start(Stage primaryStage) {
        Label label = new Label("Hello, JavaFX!");
        label.setStyle("-fx-font-size: 24px; -fx-font-weight: bold;");

        Button button = new Button("Clica-me!");
        button.setOnAction(e -> label.setText("Botão clicado!"));

        VBox root = new VBox(20);
        root.setAlignment(Pos.CENTER);
        root.setPadding(new Insets(40));
        root.getChildren().addAll(label, button);

        Scene scene = new Scene(root, 400, 300);
        primaryStage.setTitle("JavaFX App");
        primaryStage.setScene(scene);
        primaryStage.show();
    }

    /**
     * Ponto de entrada da aplicação.
     *
     * @param args argumentos da linha de comandos
     */
    public static void main(String[] args) {
        launch(args);
    }
}
EOF
        print_info "App.java criado (JavaFX)"
    else
        cat > src/main/java/App.java << 'EOF'
/**
 * Classe principal da aplicação.
 */
public class App {

    /**
     * Ponto de entrada da aplicação.
     *
     * @param args argumentos da linha de comandos
     */
    public static void main(String[] args) {
        System.out.println("Hello, World!");
    }
}
EOF
        print_info "App.java criado (Console)"
    fi

    # ── Gradle Wrapper ────────────────────────────────────────────────────────
    print_info "Gerando Gradle Wrapper..."
    gradle wrapper --gradle-version 9.4 >/dev/null 2>&1 || {
        print_warning "Falha ao gerar wrapper — usando gradle do sistema"
    }

    print_success "Estrutura base criada"
}

################################################################################
# build.gradle
################################################################################

configure_build_gradle() {
    print_header "Configurando build.gradle"

    # ── Bricks ────────────────────────────────────────────────────────────────
    if [ "$FLAG_BRICKS" = true ]; then
        cat > build.gradle << EOF
plugins {
    id 'application'
    id 'checkstyle'
    id 'com.diffplug.spotless' version '${SPOTLESS_VERSION}'
    id 'org.openjfx.javafxplugin' version '0.1.0'
}

repositories {
    mavenCentral()
    maven { url 'https://jitpack.io' }
}

dependencies {
    // Bricks — UI library (inclui JavaFX internamente)
    implementation 'com.github.fabiorodrigues0:bricks:${BRICKS_VERSION}'

    // SQLite — base de dados local
    implementation 'org.xerial:sqlite-jdbc:${SQLITE_VERSION}'

    // MySQL e PostgreSQL — opcionais (compileOnly, não forçam dependência)
    compileOnly 'com.mysql:mysql-connector-j:8.3.0'
    compileOnly 'org.postgresql:postgresql:42.7.3'
EOF

        if [ "$FLAG_JUNIT" = true ]; then
            cat >> build.gradle << EOF

    // JUnit 6
    testImplementation 'org.junit.jupiter:junit-jupiter:${JUNIT_VERSION}'
    testRuntimeOnly 'org.junit.platform:junit-platform-launcher'
EOF
            print_info "JUnit ${JUNIT_VERSION} adicionado"
        fi

        cat >> build.gradle << EOF
}

// Inclui database/ e config/database/ na compilação (estilo Laravel)
sourceSets {
    main {
        java {
            srcDirs = ['src/main/java', 'database/schema', 'database/seeds', 'config/database']
        }
    }
}

javafx {
    version = '${BRICKS_JAVAFX_VERSION}'
    modules = ['javafx.controls', 'javafx.graphics']
}

application {
    mainClass = 'App'
}

java {
    toolchain {
        languageVersion = JavaLanguageVersion.of(${BRICKS_JAVA_VERSION})
    }
}

EOF

        if [ "$FLAG_JUNIT" = true ]; then
            cat >> build.gradle << 'EOF'
tasks.named('test') {
    useJUnitPlatform()
}

EOF
        fi

        cat >> build.gradle << 'EOF'
// Checkstyle - Sun/Oracle conventions
checkstyle {
    toolVersion = '13.3.0'
    configFile = file("${rootDir}/config/checkstyle/sun_checks.xml")
    ignoreFailures = false
    maxWarnings = 0
}

// Spotless - Formatação automática
spotless {
    java {
        target 'src/**/*.java', 'database/**/*.java', 'config/database/**/*.java'
        importOrder()
        removeUnusedImports()
        eclipse().configFile('config/formatter/eclipse-formatter.xml')
        trimTrailingWhitespace()
        endWithNewline()
    }
}

// Formatar antes de compilar
tasks.named('compileJava') {
    dependsOn 'spotlessApply'
}
EOF
        print_success "build.gradle configurado (Bricks)"
        return
    fi

    # ── JavaFX / Console ──────────────────────────────────────────────────────
    cat > build.gradle << 'EOF'
plugins {
    id 'application'
    id 'checkstyle'
    id 'com.diffplug.spotless' version '8.3.0'
}

repositories {
    mavenCentral()
}

dependencies {
EOF

    if [ "$FLAG_JUNIT" = true ]; then
        cat >> build.gradle << EOF
    // JUnit 6
    testImplementation 'org.junit.jupiter:junit-jupiter:${JUNIT_VERSION}'
    testRuntimeOnly 'org.junit.platform:junit-platform-launcher'
EOF
        print_info "JUnit ${JUNIT_VERSION} adicionado"
    fi

    if [ "$FLAG_JAVAFX" = true ] || [ "$FLAG_JAVAFX_FULL" = true ]; then
        cat >> build.gradle << EOF

    // JavaFX
    implementation 'org.openjfx:javafx-controls:${JAVAFX_VERSION}'
    implementation 'org.openjfx:javafx-fxml:${JAVAFX_VERSION}'
EOF
        if [ "$FLAG_JAVAFX_FULL" = true ]; then
            cat >> build.gradle << EOF
    implementation 'org.openjfx:javafx-graphics:${JAVAFX_VERSION}'
    implementation 'org.openjfx:javafx-web:${JAVAFX_VERSION}'
    implementation 'org.openjfx:javafx-media:${JAVAFX_VERSION}'
EOF
            print_info "JavaFX ${JAVAFX_VERSION} completo adicionado"
        else
            if [ "$FLAG_JAVAFX_WEB" = true ]; then
                cat >> build.gradle << EOF
    implementation 'org.openjfx:javafx-web:${JAVAFX_VERSION}'
EOF
                print_info "JavaFX Web adicionado"
            fi
            if [ "$FLAG_JAVAFX_MEDIA" = true ]; then
                cat >> build.gradle << EOF
    implementation 'org.openjfx:javafx-media:${JAVAFX_VERSION}'
EOF
                print_info "JavaFX Media adicionado"
            fi
            print_info "JavaFX ${JAVAFX_VERSION} base adicionado"
        fi
    fi

    cat >> build.gradle << EOF
}

application {
    mainClass = 'App'
}

java {
    toolchain {
        languageVersion = JavaLanguageVersion.of(${JAVA_VERSION})
    }
}

EOF

    if [ "$FLAG_JUNIT" = true ]; then
        cat >> build.gradle << 'EOF'
tasks.named('test') {
    useJUnitPlatform()
}

EOF
    fi

    cat >> build.gradle << 'EOF'
// Checkstyle - Sun/Oracle conventions (compatível NetBeans)
checkstyle {
    toolVersion = '13.3.0'
    configFile = file("${rootDir}/config/checkstyle/sun_checks.xml")
    ignoreFailures = false
    maxWarnings = 0
}

// Spotless - Formatação automática
spotless {
    java {
        target 'src/**/*.java'
        importOrder()
        removeUnusedImports()
        eclipse().configFile('config/formatter/eclipse-formatter.xml')
        trimTrailingWhitespace()
        endWithNewline()
    }
}

// Formatar antes de compilar
tasks.named('compileJava') {
    dependsOn 'spotlessApply'
}
EOF

    print_success "build.gradle configurado"
}

################################################################################
# Ficheiros de configuração (Checkstyle + Spotless)
################################################################################

create_config_files() {
    print_header "Criando Ficheiros de Configuração"

    mkdir -p config/checkstyle
    mkdir -p config/formatter

    cat > config/checkstyle/sun_checks.xml << 'EOF'
<?xml version="1.0"?>
<!DOCTYPE module PUBLIC
    "-//Checkstyle//DTD Checkstyle Configuration 1.3//EN"
    "https://checkstyle.org/dtds/configuration_1_3.dtd">

<module name="Checker">
    <property name="severity" value="warning"/>
    <property name="fileExtensions" value="java"/>

    <module name="FileLength">
        <property name="max" value="2000"/>
    </module>

    <module name="LineLength">
        <property name="max" value="100"/>
        <property name="ignorePattern" value="^package.*|^import.*"/>
    </module>

    <module name="TreeWalker">
        <!-- Naming Conventions -->
        <module name="ConstantName"/>
        <module name="LocalFinalVariableName"/>
        <module name="LocalVariableName"/>
        <module name="MemberName"/>
        <module name="MethodName"/>
        <module name="PackageName"/>
        <module name="ParameterName"/>
        <module name="StaticVariableName"/>
        <module name="TypeName"/>

        <!-- Imports -->
        <module name="AvoidStarImport"/>
        <module name="IllegalImport"/>
        <module name="RedundantImport"/>
        <module name="UnusedImports"/>

        <!-- Tamanhos -->
        <module name="MethodLength">
            <property name="max" value="150"/>
        </module>
        <module name="ParameterNumber">
            <property name="max" value="7"/>
        </module>

        <!-- Espaços em branco -->
        <module name="EmptyForIteratorPad"/>
        <module name="GenericWhitespace"/>
        <module name="MethodParamPad"/>
        <module name="NoWhitespaceAfter"/>
        <module name="NoWhitespaceBefore"/>
        <module name="OperatorWrap"/>
        <module name="ParenPad"/>
        <module name="TypecastParenPad"/>
        <module name="WhitespaceAfter"/>
        <module name="WhitespaceAround"/>

        <!-- Modificadores -->
        <module name="ModifierOrder"/>
        <module name="RedundantModifier"/>

        <!-- Blocos -->
        <module name="AvoidNestedBlocks"/>
        <module name="EmptyBlock"/>
        <module name="LeftCurly"/>
        <module name="NeedBraces"/>
        <module name="RightCurly"/>

        <!-- Problemas comuns -->
        <module name="EmptyStatement"/>
        <module name="EqualsHashCode"/>
        <module name="IllegalInstantiation"/>
        <module name="InnerAssignment"/>
        <module name="MissingSwitchDefault"/>
        <module name="SimplifyBooleanExpression"/>
        <module name="SimplifyBooleanReturn"/>

        <!-- Complexidade -->
        <module name="CyclomaticComplexity">
            <property name="max" value="10"/>
        </module>

        <!-- Práticas de código -->
        <module name="ArrayTypeStyle"/>
        <module name="UpperEll"/>
    </module>
</module>
EOF
    print_success "sun_checks.xml criado"

    cat > config/formatter/eclipse-formatter.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<profiles version="13">
<profile kind="CodeFormatterProfile" name="Sun/Oracle Style" version="13">
<setting id="org.eclipse.jdt.core.formatter.indent_switchstatements_compare_to_cases" value="true"/>
<setting id="org.eclipse.jdt.core.formatter.indent_switchstatements_compare_to_switch" value="true"/>
<setting id="org.eclipse.jdt.core.formatter.tabulation.char" value="space"/>
<setting id="org.eclipse.jdt.core.formatter.tabulation.size" value="4"/>
<setting id="org.eclipse.jdt.core.formatter.lineSplit" value="100"/>
<setting id="org.eclipse.jdt.core.formatter.brace_position_for_type_declaration" value="end_of_line"/>
<setting id="org.eclipse.jdt.core.formatter.brace_position_for_method_declaration" value="end_of_line"/>
<setting id="org.eclipse.jdt.core.formatter.brace_position_for_constructor_declaration" value="end_of_line"/>
<setting id="org.eclipse.jdt.core.formatter.brace_position_for_block" value="end_of_line"/>
<setting id="org.eclipse.jdt.core.formatter.brace_position_for_switch" value="end_of_line"/>
<setting id="org.eclipse.jdt.core.formatter.insert_space_after_comma_in_method_invocation_arguments" value="insert"/>
<setting id="org.eclipse.jdt.core.formatter.insert_space_before_opening_paren_in_method_declaration" value="do not insert"/>
<setting id="org.eclipse.jdt.core.formatter.insert_space_before_opening_paren_in_method_invocation" value="do not insert"/>
<setting id="org.eclipse.jdt.core.formatter.alignment_for_arguments_in_method_invocation" value="16"/>
<setting id="org.eclipse.jdt.core.formatter.alignment_for_parameters_in_method_declaration" value="16"/>
</profile>
</profiles>
EOF
    print_success "eclipse-formatter.xml criado"
}

################################################################################
# Ficheiro .md (Obsidian)
################################################################################

create_markdown_file() {
    if [ "$FLAG_NO_MD" = true ]; then
        print_info "Ficheiro .md não criado (--no-md)"
        return
    fi

    print_header "Criando Documentação (.md)"

    local DATA_ATUAL
    DATA_ATUAL=$(date +%d-%m-%Y)
    local MD_FILE="${NOME_PROJETO}.md"

    cat > "$MD_FILE" << EOF
---
tags:
  - contexto/PC
  - tipo/trabalho_pratico
  - conceito/java
  - area/programacao
data: ${DATA_ATUAL}
disciplina:
  - PC
---
# ${TITULO}

## Descrição

${TITULO}

## Conceitos abordados

- [[variavel|Variáveis]] e [[tipo_primitivo|tipos de dados]]
- 

## Estrutura do Projeto

- \`src/main/java/App.java\` - Classe principal
EOF

    if [ "$FLAG_JUNIT" = true ]; then
        cat >> "$MD_FILE" << EOF
- \`src/test/java/\` - Testes unitários (JUnit ${JUNIT_VERSION})
EOF
    fi

    cat >> "$MD_FILE" << EOF
- \`build.gradle\` - Configuração Gradle
- \`config/checkstyle/sun_checks.xml\` - Regras Checkstyle (Sun/Oracle)
- \`config/formatter/eclipse-formatter.xml\` - Formatação automática

## Como executar

\`\`\`bash
# Compilar
./gradlew build

# Executar
./gradlew run
EOF

    if [ "$FLAG_JUNIT" = true ]; then
        cat >> "$MD_FILE" << EOF

# Testes
./gradlew test
EOF
    fi

    cat >> "$MD_FILE" << EOF

# Formatar código automaticamente
./gradlew spotlessApply

# Verificar estilo (Checkstyle)
./gradlew checkstyleMain

# Limpar build
./gradlew clean
\`\`\`

## Dependências

EOF

    if [ "$FLAG_BRICKS" = true ]; then
        cat >> "$MD_FILE" << EOF
- **Java ${BRICKS_JAVA_VERSION}** - Versão do JDK
EOF
    else
        cat >> "$MD_FILE" << EOF
- **Java ${JAVA_VERSION}** - Versão do JDK
EOF
    fi

    if [ "$FLAG_JUNIT" = true ]; then
        cat >> "$MD_FILE" << EOF
- **JUnit ${JUNIT_VERSION}** - Framework de testes unitários
EOF
    fi

    if [ "$FLAG_BRICKS" = true ]; then
        cat >> "$MD_FILE" << EOF
- **Bricks ${BRICKS_VERSION}** - UI declarativa JavaFX (inclui JavaFX ${BRICKS_JAVAFX_VERSION})
  - Base de dados SQLite em \`./data/database.db\` (criada automaticamente)
  - Schema: \`DatabaseSchema.java\`
- **SQLite JDBC ${SQLITE_VERSION}** - Driver SQLite
EOF
    fi

    if [ "$FLAG_JAVAFX" = true ] || [ "$FLAG_JAVAFX_FULL" = true ]; then
        cat >> "$MD_FILE" << EOF
- **JavaFX ${JAVAFX_VERSION}** - Interface gráfica
  - javafx-controls (base)
  - javafx-fxml (FXML)
EOF
        if [ "$FLAG_JAVAFX_FULL" = true ]; then
            cat >> "$MD_FILE" << EOF
  - javafx-graphics (gráficos)
  - javafx-web (WebView)
  - javafx-media (áudio/vídeo)
EOF
        else
            [ "$FLAG_JAVAFX_WEB" = true ]   && echo "  - javafx-web (WebView)"   >> "$MD_FILE"
            [ "$FLAG_JAVAFX_MEDIA" = true ] && echo "  - javafx-media (áudio/vídeo)" >> "$MD_FILE"
        fi
    fi

    cat >> "$MD_FILE" << EOF
- **Checkstyle ${CHECKSTYLE_VERSION}** - Verificação de estilo (Sun/Oracle conventions)
EOF

    if [ "$FLAG_BRICKS" = false ]; then
        cat >> "$MD_FILE" << EOF
- **Spotless ${SPOTLESS_VERSION}** - Formatação automática de código
EOF
    fi

    cat >> "$MD_FILE" << EOF

## Relações

- [[variavel]]
- [[tipo_primitivo]]
EOF

    print_success "${MD_FILE} criado"
}

################################################################################
# .gitignore
################################################################################

adjust_gitignore() {
    print_header "Ajustando .gitignore"

    local ENTRIES=(
        ".gradle/"
        "build/"
        ".idea/"
        ".vscode/"
        "*.class"
        "*.log"
        ".zed/"
    )

    for entry in "${ENTRIES[@]}"; do
        if ! grep -q "^${entry}$" .gitignore 2>/dev/null; then
            echo "$entry" >> .gitignore
        fi
    done

    if [ "$FLAG_BRICKS" = true ]; then
        if ! grep -q "^data/$" .gitignore 2>/dev/null; then
            echo "data/" >> .gitignore
        fi
        print_info "data/ adicionado ao .gitignore (SQLite)"
    fi

    print_success ".gitignore ajustado"
}

################################################################################
# Limpar testes
################################################################################

cleanup_tests() {
    if [ "$FLAG_JUNIT" = false ]; then
        print_info "Removendo testes (JUnit não configurado)"
        rm -rf src/test
    else
        rm -f src/test/java/AppTest.java 2>/dev/null || true
        print_info "Diretório de testes preparado (vazio)"
    fi
}

################################################################################
# Build inicial
################################################################################

validate_build() {
    print_header "Validando Projeto"

    print_info "Executando build inicial..."
    if ./gradlew build --quiet; then
        print_success "Build executado com sucesso"
        if [ "$FLAG_BRICKS" = false ]; then
            print_info "Aplicando formatação automática..."
            ./gradlew spotlessApply --quiet
            print_success "Código formatado"
        fi
    else
        print_warning "Build falhou — projeto criado mas pode ter erros"
        print_info "Execute './gradlew build' para ver os erros"
    fi
}

################################################################################
# Mensagem final
################################################################################

show_success_message() {
    local CURRENT_PATH
    CURRENT_PATH=$(pwd)

    echo ""
    print_header "PROJETO CRIADO COM SUCESSO!"
    echo ""

    echo -e "${GREEN}📁 Projeto:${NC}     ${NOME_PROJETO}"
    echo -e "${GREEN}📍 Localização:${NC} ${CURRENT_PATH}"
    [ "$FLAG_NO_MD" = false ] && echo -e "${GREEN}📄 Docs:${NC}        ${NOME_PROJETO}.md"

    echo ""
    echo -e "${CYAN}🔧 Configurações:${NC}"
    if [ "$FLAG_BRICKS" = true ]; then
        echo "   • Java ${BRICKS_JAVA_VERSION}"
    else
        echo "   • Java ${JAVA_VERSION}"
    fi
    echo "   • Estrutura: Flat | Packages: Não | Main: App.java"

    [ "$FLAG_JUNIT" = true ]  && echo -e "   ${GREEN}✓${NC} JUnit ${JUNIT_VERSION}"
    if [ "$FLAG_BRICKS" = true ]; then
        echo -e "   ${GREEN}✓${NC} Bricks (UI declarativa + SQLite)"
        echo "     • Base de dados: ./data/database.db (automática)"
        echo "     • Ligação:  config/database/DatabaseConfig.java"
        echo "     • Schema:   database/schema/DatabaseSchema.java"
        echo "     • Seeds:    database/seeds/DatabaseSeeder.java"
    fi

    if [ "$FLAG_JAVAFX" = true ] || [ "$FLAG_JAVAFX_FULL" = true ]; then
        local MODS="controls, fxml"
        [ "$FLAG_JAVAFX_FULL" = true ]  && MODS="${MODS}, graphics, web, media"
        [ "$FLAG_JAVAFX_WEB" = true ]   && MODS="${MODS}, web"
        [ "$FLAG_JAVAFX_MEDIA" = true ] && MODS="${MODS}, media"
        echo -e "   ${GREEN}✓${NC} JavaFX ${JAVAFX_VERSION} (${MODS})"
    fi

    echo -e "   ${GREEN}✓${NC} Checkstyle ${CHECKSTYLE_VERSION} (Sun/Oracle)"
    echo -e "   ${GREEN}✓${NC} Spotless ${SPOTLESS_VERSION}"

    echo ""
    echo -e "${YELLOW}📝 Próximos passos:${NC}"
    echo ""
    echo "   1. cd ${NOME_PROJETO}"
    echo "   2. zed .               # Abrir no Zed"
    echo "   3. ./gradlew run       # Executar"
    echo ""
    echo -e "${BLUE}💡 Comandos úteis:${NC}"
    echo ""
    echo "   ./gradlew build            # Compilar"
    [ "$FLAG_JUNIT" = true ] && echo "   ./gradlew test             # Executar testes"
    echo "   ./gradlew spotlessApply    # Formatar código"
    echo "   ./gradlew checkstyleMain   # Verificar estilo"
    echo "   ./gradlew clean            # Limpar build"
    echo ""
    echo -e "${CYAN}🎓 Dica:${NC} O código é formatado automaticamente ao compilar!"
    echo ""
}

################################################################################
# MAIN
################################################################################

main() {
    parse_arguments "$@"
    validate_environment
    create_project_structure
    configure_build_gradle
    create_config_files
    create_markdown_file
    adjust_gitignore
    cleanup_tests
    validate_build
    show_success_message
}

main "$@"
