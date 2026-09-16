# 🛠️ Utils — Soluções de problemas

## Omarchy: o menu (Super + Space) não mostra ou não abre os apps

### Sintomas

- O submenu **Apps** aparece vazio ("Nothing here yet") ou os apps não abrem com Enter.
- As entradas **Ask AI** e **Search Web** somem do menu.

### Contexto

O menu em uso é um clone do plugin do Omarchy (`~/.config/omarchy/plugins/<usuário>.menu`),
instalado por `omarchy/ask-agent/install.sh`. Por um bug do Omarchy
([omacom/omarchy#11762](https://github.com/omacom/omarchy/issues/11762)), menus clonados
não recebem o `appLibrary`, então a lista padrão de apps fica vazia. O `menu.patch` contorna
isso com um provider `programs` que lê os arquivos `.desktop` direto, e o
`omarchy-menu.jsonc` troca a entrada `"apps"` do menu para usar esse provider.

Por isso o menu depende destes links simbólicos apontando para o repositório:

| Link | Destino |
|---|---|
| `~/.config/omarchy/extensions/omarchy-menu.jsonc` | `omarchy/ask-agent/omarchy-menu.jsonc` |
| `~/.local/bin/toolbox-ask-agent` | `omarchy/ask-agent/run.sh` |
| `~/.local/bin/toolbox-web-search` | `omarchy/web-search/run.sh` |

### Causas comuns

1. **Pastas do repositório movidas ou renomeadas** — os links quebram. Foi o que aconteceu
   quando `tools/ask-agent` e `tools/web-search` foram movidos para `omarchy/`: sem o
   `omarchy-menu.jsonc`, o menu voltou à lista padrão de apps, que não funciona no clone.
2. **Atualização do Omarchy** — o `Menu.qml` original pode mudar e o patch parar de aplicar.

### Diagnóstico

```bash
# Links quebrados aparecem como BROKEN
for l in ~/.config/omarchy/extensions/omarchy-menu.jsonc ~/.local/bin/toolbox-*; do
  printf '%s -> %s ' "$l" "$(readlink "$l")"; [[ -e $l ]] && echo OK || echo BROKEN
done

# O patch ainda aplica na versão instalada do Omarchy?
omarchy/ask-agent/install.sh --check
```

### Solução

Na raiz do repositório:

```bash
ln -sfn "$PWD/omarchy/ask-agent/omarchy-menu.jsonc" ~/.config/omarchy/extensions/omarchy-menu.jsonc
omarchy/web-search/install.sh
omarchy/ask-agent/install.sh   # reinstala o menu, recria o link e reinicia o shell
```

Se o `--check` falhar depois de uma atualização do Omarchy, gere o `menu.patch` de novo a
partir do `/usr/share/omarchy/shell/plugins/menu/Menu.qml` atual antes de reinstalar.

O `install.sh` do ask-agent faz backup do menu anterior em
`~/.local/state/toolbox-ask-agent/<data>`.

### Verificação

Abra o menu, entre em **Apps**, digite `foot` e aperte Enter: um terminal deve abrir e o
menu deve fechar.

> Dica: sempre que mover pastas de `omarchy/`, rode os dois `install.sh` de novo.
