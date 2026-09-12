# Aliases

Instala atalhos de shell (bash/zsh) para os comandos mais usados do Tool-Box,
para não precisar digitar `./toolbox <ferramenta> <ação>` toda vez.

---

## 📁 Estrutura da Ferramenta

```
tools/aliases/
├── aliases.sh     # Definição dos atalhos (é "sourced", não executado)
├── manage.sh      # install/uninstall/status/list
└── README.md      # Documentação desta ferramenta
```

`aliases.sh` se autolocaliza (funciona em qualquer caminho onde o
repositório esteja clonado) e é seguro executar `install` mais de uma vez —
ele não duplica a entrada no seu arquivo de shell.

---

## 🔤 Atalhos instalados

| Atalho             | Equivale a                          |
|---------------------|--------------------------------------|
| `tb`                | `./toolbox`                          |
| `tbl`               | `./toolbox list`                     |
| `tbn`               | `./toolbox new`                      |
| `tb-clean`          | `./toolbox disk-cleaner`             |
| `tb-clean-all`      | `./toolbox disk-cleaner --yes`       |
| `tb-clean-dry`      | `./toolbox disk-cleaner --dry-run`   |
| `tb-torrent`        | `./toolbox torrent-dl`               |
| `tb-dl`             | `./toolbox torrent-dl`               |
| `tb-mon`            | `./toolbox mac-monitor`              |
| `tb-mon-status`     | `./toolbox mac-monitor status`       |
| `tb-mon-report`     | `./toolbox mac-monitor report`       |
| `tb-mon-logs`       | `./toolbox mac-monitor logs -f`      |
| `tb-mon-start`      | `./toolbox mac-monitor start`        |
| `tb-mon-stop`       | `./toolbox mac-monitor stop`         |
| `tb-mon-restart`    | `./toolbox mac-monitor restart`      |

Veja a lista atualizada a qualquer momento com `./toolbox aliases list`.

---

## 🚀 Como Usar

```bash
# Instalar (adiciona um bloco marcado ao ~/.zshrc ou ~/.bashrc/.bash_profile,
# detectado a partir do seu $SHELL):
./toolbox aliases install

# Recarregar o shell atual para começar a usar:
source ~/.zshrc   # ou ~/.bashrc / ~/.bash_profile

# Ver quais arquivos já têm os atalhos instalados:
./toolbox aliases status

# Listar todos os atalhos disponíveis:
./toolbox aliases list

# Remover os atalhos:
./toolbox aliases uninstall
```

O `install` só adiciona um bloco entre marcadores (`# >>> tool-box aliases >>>`
/ `# <<< tool-box aliases <<<`) que aponta para `tools/aliases/aliases.sh` —
nada é copiado para dentro do seu `.zshrc`, então atualizar o Tool-Box já
atualiza os atalhos automaticamente. O `uninstall` remove exatamente esse
bloco, sem tocar no resto do arquivo.
