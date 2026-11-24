function herdr-enviar --description "Envia referências ou anotações de código do Helix para o agente no Herdr"
    set -l acao (test (count $argv) -gt 0; and echo $argv[1]; or echo "ref")
    set -l ficheiro (test (count $argv) -gt 1; and echo $argv[2]; or echo "")
    set -l linha (test (count $argv) -gt 2; and echo $argv[3]; or echo "1")

    # Dois ambientes: herdr-app (herdr-core, via `hc` + $HC_TERMINAL_ID) e o
    # multiplexer `herdr` antigo (via $HERDR_PANE_ID). Preferir hc quando existe.
    if set -q HC_TERMINAL_ID; and type -q hc
        __herdr-enviar-hc $acao $ficheiro $linha
    else
        __herdr-enviar-tui $acao $ficheiro $linha
    end
end

# ---- herdr-app / herdr-core (hc) ----
function __herdr-enviar-hc
    set -l acao $argv[1]
    set -l ficheiro $argv[2]
    set -l linha $argv[3]

    set -l me "$HC_TERMINAL_ID"
    set -l ls (hc ls --json 2>/dev/null)
    test -z "$ls"; and return 0

    # Agente = terminal AI (não shell), diferente deste. Preferir o do mesmo
    # espaço (prefixo de `where`, "Espaço / Tab"); senão o primeiro que houver.
    set -l agent (echo "$ls" | jq -r --arg me "$me" '
        (first(.terminals[]|select(.address==$me)|.where)|split(" / ")[0]) as $sp
        | [.terminals[]
            | select(.address!=$me)
            | select(.agent|test("claude|codex|cursor|gemini|aider|opencode|crush|qwen";"i"))] as $a
        | (([$a[]|select((.where|split(" / ")[0])==$sp)] + $a)|first|.address // empty)')
    test -z "$agent"; and return 0

    switch $acao
        case ref
            # hc só sabe "colar + Enter"; para não submeter um ref solto, copia
            # para o clipboard — colas no prompt do agente quando quiseres.
            set -l ref "$ficheiro"
            test -n "$linha"; and test "$linha" != "1"; and set ref "$ficheiro:$linha"
            if type -q wl-copy
                printf '%s ' "$ref" | wl-copy
            else
                hc send "$agent" "$ref" >/dev/null 2>&1
            end

        case comment
            set -l conteudo (cat)
            test -z "$conteudo"; and return 0
            set -l prompt "No ficheiro `$ficheiro` (linha $linha):
```
$conteudo
```"
            hc send "$agent" "$prompt" >/dev/null 2>&1
    end
end

# ---- herdr (multiplexer antigo) ----
function __herdr-enviar-tui
    set -l acao $argv[1]
    set -l ficheiro $argv[2]
    set -l linha $argv[3]

    set -l agent_json (herdr agent list 2>/dev/null)
    set -l agent_pane (echo "$agent_json" | jq -r '.result.agents[0].pane_id // empty' 2>/dev/null)

    if test -z "$agent_pane"
        set -l meu_pane "$HERDR_PANE_ID"
        set agent_pane (herdr pane list 2>/dev/null | jq -r --arg cur "$meu_pane" '.result.panes[] | select(.pane_id != $cur) | .pane_id' | head -n1 2>/dev/null)
    end

    test -z "$agent_pane"; and return 0

    switch $acao
        case ref
            set -l ref "$ficheiro"
            test -n "$linha"; and test "$linha" != "1"; and set ref "$ficheiro:$linha"
            herdr pane send-text "$agent_pane" "$ref " >/dev/null 2>&1

        case comment
            set -l conteudo (cat)
            if test -n "$conteudo"
                set -l prompt "No ficheiro `$ficheiro` (linha $linha):
```
$conteudo
```
"
                if echo "$agent_json" | jq -e '.result.agents[0]' >/dev/null 2>&1
                    set -l agent_id (echo "$agent_json" | jq -r '.result.agents[0].pane_id')
                    herdr agent prompt "$agent_id" "$prompt" >/dev/null 2>&1
                else
                    herdr pane send-text "$agent_pane" "$prompt\n" >/dev/null 2>&1
                end
            end
    end
end
