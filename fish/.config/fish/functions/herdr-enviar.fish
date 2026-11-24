function herdr-enviar --description "Envia referências ou anotações de código do Helix para o agente no Herdr"
    set -l acao (test (count $argv) -gt 0; and echo $argv[1]; or echo "ref")
    set -l ficheiro (test (count $argv) -gt 1; and echo $argv[2]; or echo "")
    set -l linha (test (count $argv) -gt 2; and echo $argv[3]; or echo "1")

    # Localizar o agente ativo no Herdr
    set -l agent_json (herdr agent list 2>/dev/null)
    set -l agent_pane (echo "$agent_json" | jq -r '.result.agents[0].pane_id // empty' 2>/dev/null)

    # Fallback: se não estiver explicitamente como agent, pega no outro pane da tab
    if test -z "$agent_pane"
        set -l meu_pane "$HERDR_PANE_ID"
        set agent_pane (herdr pane list 2>/dev/null | jq -r --arg cur "$meu_pane" '.result.panes[] | select(.pane_id != $cur) | .pane_id' | head -n1 2>/dev/null)
    end

    if test -z "$agent_pane"
        return 0
    end

    switch $acao
        case ref
            # Inserir caminho:linha na linha de comandos do agente
            set -l ref "$ficheiro"
            test -n "$linha"; and test "$linha" != "1"; and set ref "$ficheiro:$linha"
            herdr pane send-text "$agent_pane" "$ref " >/dev/null 2>&1

        case comment
            # Lê o texto selecionado através de stdin (via :pipe-to do Helix)
            set -l conteudo (cat)
            if test -n "$conteudo"
                set -l prompt "No ficheiro `$ficheiro` (linha $linha):
```
$conteudo
```
"
                # Se for reconhecido como agente pelo Herdr, usa agent prompt
                if echo "$agent_json" | jq -e '.result.agents[0]' >/dev/null 2>&1
                    set -l agent_id (echo "$agent_json" | jq -r '.result.agents[0].pane_id')
                    herdr agent prompt "$agent_id" "$prompt" >/dev/null 2>&1
                else
                    herdr pane send-text "$agent_pane" "$prompt\n" >/dev/null 2>&1
                end
            end
    end
end
