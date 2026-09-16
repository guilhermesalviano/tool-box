# 🛠️ Utils — Soluções de problemas

## Omarchy: o menu (Super + Space) não mostra ou não abre os apps

### Sintomas

- O submenu **Apps** aparece vazio ("Nothing here yet") ou os apps não abrem com Enter.
- As entradas **Ask AI** e **Search Web** somem do menu.

### Contexto

O menu em uso é o plugin `toolbox.ask-agent` (`~/.config/omarchy/plugins/toolbox.ask-agent`),
instalado por `omarchy/ask-agent/install.sh`. Por um bug do Omarchy
([omacom/omarchy#11762](https://github.com/omacom/omarchy/issues/11762)), menus fora da pasta
do Omarchy não recebem o `appLibrary`, então a lista padrão de apps fica vazia. O plugin
contorna isso com um provider `programs` que lê os arquivos `.desktop` direto, e o
`menu.jsonc` do próprio plugin troca a entrada `"apps"` do menu para usar esse provider.

O **Search Web** é outro plugin, `toolbox.web-search`. As linhas dele no menu só aparecem
enquanto ele estiver instalado.

Os plugins são **cópias** das pastas do repositório, sem links simbólicos. Mover pastas do
repo não quebra mais o menu, mas editar arquivos no repo só vale depois de reinstalar.

> Histórico: antes de virar plugin, o menu era um patch num clone `<usuário>.menu` e dependia
> de links simbólicos para o repo (`~/.config/omarchy/extensions/omarchy-menu.jsonc` e
> `~/.local/bin/toolbox-*`). Em 2026-09-16 esses links quebraram quando `tools/` virou
> `omarchy/`, e os apps sumiram. O `install.sh` atual remove essas peças antigas.

### Causas comuns

1. **Plugin desativado ou não instalado** — por exemplo, depois de trocar o menu em
   Setup → Plugins, ou numa máquina nova.
2. **Atualização do Omarchy** — o menu do plugin é uma cópia do menu original; uma mudança
   grande no shell do Omarchy pode quebrar a cópia.
3. **Mudanças no repo ainda não instaladas.**

### Diagnóstico

```bash
# Os dois plugins existem e estão ativos?
omarchy-shell shell listPlugins | jq -c '.[] | select(.id | test("toolbox|menu")) | {id, enabled}'

# Os plugins do repo são válidos?
omarchy/ask-agent/install.sh --check
omarchy/web-search/install.sh --check

# Erros de QML ao carregar o menu
journalctl --user --since "-10min" | grep -iE "toolbox|failed to load|TypeError|ReferenceError"
```

### Solução

Na raiz do repositório:

```bash
omarchy/web-search/install.sh
omarchy/ask-agent/install.sh   # instala o menu, ativa e reinicia o shell
```

Backups ficam em `~/.local/state/toolbox-ask-agent/<data>` e
`~/.local/state/toolbox-web-search/<data>`.

Se o menu quebrar depois de uma atualização do Omarchy, compare com o original e traga as
mudanças:

```bash
diff -u /usr/share/omarchy/shell/plugins/menu/Menu.qml omarchy/ask-agent/Menu.qml
```

Para voltar ao menu original do Omarchy: `omarchy plugin disable toolbox.ask-agent`.

### Verificação

Abra o menu, entre em **Apps**, digite `foot` e aperte Enter: um terminal deve abrir e o
menu deve fechar. Digite um texto qualquer que não seja app (ex.: `zzqx linux`): deve
aparecer **Search Web: zzqx linux**.
