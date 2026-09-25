# 🧰 Tool-Box

Repositório modular de utilitários, automações e scripts de manutenção para macOS / servidor.

A estrutura foi projetada para suportar múltiplos scripts e ferramentas de forma isolada, padronizada e fácil de gerenciar através de um CLI unificado (`./toolbox`).

---

## 🚀 Instalação em uma máquina nova

```bash
git clone <este-repositório> tool-box
cd tool-box
./install.sh
```

`install.sh` é interativo: pergunta antes de instalar qualquer coisa (pacotes
do sistema, aliases no shell, serviços), detecta o que já está presente e
pula o resto sozinho — por exemplo, as integrações do menu do Omarchy (Ask AI,
Search Web) só aparecem se o comando `omarchy` existir na máquina. Rodar de
novo é seguro.

### 🐚 Zsh + Oh My Zsh

O primeiro passo do `install.sh` configura o shell:

1. Instala o `zsh` pelo gerenciador de pacotes (brew/pacman/apt/dnf).
2. Instala o [Oh My Zsh](https://ohmyz.sh) em modo não interativo — o
   `~/.zshrc` existente é salvo como `~/.zshrc.pre-oh-my-zsh`.
3. Clona os plugins em `~/.oh-my-zsh/custom/plugins/`:
   [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions),
   [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting) e
   [fast-syntax-highlighting](https://github.com/zdharma-continuum/fast-syntax-highlighting).
4. Ativa os plugins no `~/.zshrc` num bloco marcado
   (`# >>> tool-box zsh plugins >>>`). Os dois plugins de syntax highlighting
   conflitam se carregados juntos, então só o `fast-syntax-highlighting` é
   carregado; o `zsh-syntax-highlighting` fica de reserva caso o outro falte.
5. Oferece tornar o zsh o shell padrão (`chsh -s $(command -v zsh)`).

Esse passo vem antes dos aliases para que eles entrem no `~/.zshrc` novo.
Para fazer à mão:

```bash
sudo pacman -S --needed zsh        # ou: brew install zsh / sudo apt-get install -y zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
P="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins"
git clone --depth 1 https://github.com/zsh-users/zsh-autosuggestions "$P/zsh-autosuggestions"
git clone --depth 1 https://github.com/zsh-users/zsh-syntax-highlighting "$P/zsh-syntax-highlighting"
git clone --depth 1 https://github.com/zdharma-continuum/fast-syntax-highlighting "$P/fast-syntax-highlighting"
# no fim do ~/.zshrc:
#   source "$P/zsh-autosuggestions/zsh-autosuggestions.zsh"
#   source "$P/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh"
chsh -s "$(command -v zsh)"
```

### 🪙 RTK nos agentes de código

Depois dos aliases, o `install.sh` instala o [RTK](https://github.com/rtk-ai/rtk)
(Rust Token Killer), um proxy de CLI que comprime a saída de comandos como
`git status`, `ls` e testes antes de ela entrar no contexto do agente — de 60%
a 90% menos tokens. O `rtk init` instala um hook que reescreve os comandos
sozinho (`git status` → `rtk git status`), sem mudar como você usa o agente.

1. Instala o `rtk` com `brew`, pelo AUR (`yay`/`paru`) ou, sem nenhum deles,
   pelo script oficial (binário em `~/.local/bin`).
2. Para cada agente encontrado na máquina (comando no `PATH` ou pasta de
   configuração), pergunta e roda o `rtk init` correspondente.

Para fazer à mão:

```bash
brew install rtk                   # ou: yay -S rtk
# ou: curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh
# (não use 'cargo install rtk': no crates.io esse nome é outro projeto;
#  use 'cargo install --git https://github.com/rtk-ai/rtk')

rtk init -g                        # Claude Code
rtk init -g --codex                # Codex
rtk init -g --gemini               # Gemini CLI
rtk init -g --opencode             # OpenCode
rtk init -g --agent cursor         # Cursor
rtk init -g --agent windsurf       # Windsurf
rtk init -g --copilot              # GitHub Copilot (VS Code + CLI)
rtk init --agent cline             # Cline / Roo Code (por projeto, rode na raiz dele)

rtk init --show                    # confere o que está ativo
rtk gain                           # tokens economizados até agora
rtk init -g --uninstall            # desfaz (repita com a flag do agente)
```

Reinicie os agentes que estiverem abertos depois do `rtk init`. As
ferramentas nativas do Claude Code (`Read`, `Grep`, `Glob`) não passam pelo
hook — só os comandos de shell são comprimidos.

### 🔍 Delta no git diff

O `install.sh` também instala o [delta](https://github.com/dandavison/delta)
(pacote `git-delta`), um pager para `git diff`, `git log -p` e `git show` com
destaque de sintaxe, realce das palavras alteradas e números de linha. Depois
de instalar, pergunta se deve configurar o git global para usá-lo — só nesse
momento, porque um `core.pager` apontando para um comando que não existe
quebra o `git diff`. Se já houver outro pager configurado, ele avisa antes de
trocar.

Para fazer à mão:

```bash
sudo pacman -S --needed git-delta  # ou: brew install git-delta / sudo apt-get install -y git-delta

git config --global core.pager delta
git config --global interactive.diffFilter "delta --color-only"   # git add -p colorido
git config --global delta.navigate true                           # n / N pulam entre arquivos
git config --global delta.side-by-side true                      # diff lado a lado
git config --global diff.algorithm histogram                     # diffs mais legíveis em código movido
```

Dicas: em terminal estreito, `git -c delta.side-by-side=false diff` volta ao
modo de uma coluna; `git --no-pager diff` desliga o delta numa chamada. Para desfazer: `git config --global --unset core.pager` e
`git config --global --unset interactive.diffFilter`.

---

## 📂 Estrutura do Repositório

```text
tool-box/
├── install.sh                  # Instalação interativa para uma máquina nova
├── toolbox                     # CLI mestre para listar, criar e executar qualquer ferramenta
├── tools/                      # Diretório de ferramentas modulares e isoladas
│   ├── README.md               # Documentação das ferramentas de tools/
│   ├── torrent-dl/             # Ferramenta: Download de torrent via aria2c
│   │   ├── run.sh              # Script de download (-o/--output, -s/--seed-minutes)
│   │   └── README.md           # Documentação específica do torrent-dl
│   │
│   ├── disk-cleaner/           # Ferramenta: Liberação de espaço em disco (macOS/Linux)
│   │   ├── run.sh              # Script interativo de limpeza (-y/--dry-run/--docker-volumes)
│   │   └── README.md           # Documentação específica do disk-cleaner
│   │
│   ├── aliases/                # Ferramenta: Atalhos de shell para o Tool-Box
│   │   ├── aliases.sh          # Definição dos atalhos (autolocalizável, bash/zsh)
│   │   ├── manage.sh           # install/uninstall/status/list
│   │   └── README.md           # Documentação específica dos aliases
│   │
│   ├── mac-monitor/            # Ferramenta: Monitor de Uso de CPU e Memória (Glances)
│   │   ├── collector.py        # Coletor contínuo (streaming Glances -> CSV)
│   │   ├── report.sh           # Script AWK para agregação de estatísticas do dia
│   │   ├── manage.sh           # Gerenciador local do mac-monitor
│   │   ├── launchd/            # Configuração de serviço persistente no macOS
│   │   │   └── com.guilhermesalviano.toolbox-monitor.plist.template
│   │   └── README.md           # Documentação específica do mac-monitor
│   │
│   └── _template/              # Molde para criar novas ferramentas com um comando
│       ├── run.sh
│       └── README.md
│
├── apps/                       # Aplicativos com interface gráfica
│   ├── README.md               # Documentação dos apps de apps/
│   └── swain-macros/           # App: Macros nos botões laterais do mouse Redragon Swain (Ubuntu)
│       ├── run.sh              # Abre o app (ou `install` para a configuração inicial)
│       ├── install.sh          # Dependências apt, regra udev e atalho no menu
│       ├── swain_macros/       # App GTK, engine evdev/uinput e linguagem de macros
│       ├── data/               # Regra udev, .desktop e ícone
│       └── README.md           # Documentação específica do swain-macros
│
├── omarchy/                    # Plugins do shell do Omarchy (cada pasta é um plugin)
│   ├── README.md               # Documentação dos plugins de omarchy/
│   ├── ask-agent/              # Plugin toolbox.ask-agent: menu com respostas de IA
│   │   ├── manifest.json       # Manifesto do plugin (substitui o omarchy.menu)
│   │   ├── Menu.qml            # Menu do Omarchy com Ask AI, lista de Apps e Search Web
│   │   ├── AskPane.qml         # Painel de resposta dentro do menu
│   │   ├── menu.jsonc          # Linhas do menu que o plugin adiciona
│   │   ├── run.sh              # Abre o painel de resposta (ou --headless para scripts)
│   │   ├── answer.sh           # Backend do agente padrão (stdout = só a resposta)
│   │   ├── install.sh          # Valida e copia o plugin para ~/.config/omarchy/plugins
│   │   └── README.md           # Documentação específica do ask-agent
│   │
│   ├── calendar/               # Plugin toolbox.calendar: relógio com eventos do Google Calendar
│   │   ├── manifest.json       # Manifesto do plugin (substitui o omarchy.clock)
│   │   ├── BarWidget.qml       # Relógio da barra + próximo evento; roda o sync
│   │   ├── Panel.qml           # Calendário com os eventos do dia selecionado
│   │   ├── Events.js           # Lógica pura dos eventos (testada com node)
│   │   ├── sync.py             # Baixa os endereços iCal e expande eventos recorrentes
│   │   ├── run.sh              # toolbox calendar add|list|remove|sync|status
│   │   ├── install.sh          # Valida e copia o plugin para ~/.config/omarchy/plugins
│   │   └── README.md           # Documentação específica do calendar
│   │
│   ├── orca/                   # Plugin toolbox.orca: workspaces e agentes do Orca na barra
│   │   ├── manifest.json       # Manifesto do plugin (bar-widget)
│   │   ├── Panel.qml           # Botão da barra + lista de workspaces e agentes
│   │   ├── Model.js            # Lógica pura dos workspaces/agentes (testada com node)
│   │   ├── snapshot.sh         # Lê o CLI do Orca (worktree ps / terminal list) em JSON
│   │   ├── focus.sh            # Traz o Orca para a frente no terminal escolhido
│   │   ├── run.sh              # toolbox orca status|json|focus
│   │   ├── install.sh          # Valida, copia e adiciona o plugin à barra
│   │   └── README.md           # Documentação específica do orca
│   │
│   └── web-search/             # Plugin toolbox.web-search: caixa de busca na internet
│       ├── manifest.json       # Manifesto do plugin (overlay)
│       ├── WebSearch.qml       # Caixa de busca
│       ├── run.sh              # Codifica a query e abre o navegador padrão
│       ├── install.sh          # Valida e copia o plugin para ~/.config/omarchy/plugins
│       └── README.md           # Documentação específica do web-search
│
├── logs/                       # Diretório central de logs
│   ├── glances-YYYY-MM-DD.csv  # Arquivos diários gerados pelo mac-monitor
│   └── ...
├── .venv/                      # Ambiente virtual Python gerenciado
├── .gitignore
└── README.md
```

---

## ⚡ CLI Mestre (`./toolbox`)

O executável `./toolbox` permite interagir com qualquer ferramenta instalada:

### Comandos Gerais
```bash
# Listar todas as ferramentas instaladas
./toolbox list

# Criar uma nova ferramenta a partir do template padrão
./toolbox new <nome-da-ferramenta>
```

### Executando Ferramentas
Qualquer ferramenta dentro de `tools/<nome>`, `apps/<nome>` (aplicativos
gráficos) ou `omarchy/<nome>` (só existem no Omarchy) pode ser executada
diretamente:
```bash
./toolbox <nome-da-ferramenta> [ação/argumentos]
```

`./toolbox list` mostra as três famílias separadamente; `./toolbox new` sempre
cria em `tools/`.

---

## 🛠️ Ferramentas (`tools/`)

A documentação de `torrent-dl`, `disk-cleaner`, `aliases` e `mac-monitor`
está em [`tools/README.md`](tools/README.md).

---

## 🖱️ Apps (`apps/`)

A documentação de `swain-macros` está em [`apps/README.md`](apps/README.md).

---

## 🟢 Plugins Omarchy (`omarchy/`)

A documentação de `ask-agent`, `calendar`, `orca` e `web-search` está em
[`omarchy/README.md`](omarchy/README.md).

---

## ➕ Como Adicionar uma Nova Ferramenta

Para adicionar um novo script ou serviço na toolbox:

1. **Crie a nova ferramenta**:
   ```bash
   ./toolbox new disk-cleaner
   ```
2. **Implemente o script** em `tools/disk-cleaner/run.sh` (ou crie scripts Python/Bash adicionais na mesma pasta).
3. **Execute através do CLI mestre**:
   ```bash
   ./toolbox disk-cleaner
   ```
