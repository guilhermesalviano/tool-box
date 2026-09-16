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
│   └── swain-macros/           # App: Macros nos botões laterais do mouse Redragon Swain (Ubuntu)
│       ├── run.sh              # Abre o app (ou `install` para a configuração inicial)
│       ├── install.sh          # Dependências apt, regra udev e atalho no menu
│       ├── swain_macros/       # App GTK, engine evdev/uinput e linguagem de macros
│       ├── data/               # Regra udev, .desktop e ícone
│       └── README.md           # Documentação específica do swain-macros
│
├── omarchy/                    # Plugins do shell do Omarchy (cada pasta é um plugin)
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

## 🖱️ App: `swain-macros`

App GNOME (Ubuntu, Wayland e X11) que troca a função dos botões laterais do
mouse Redragon Swain por macros (teclas, texto, cliques, scroll, comandos).
Usa o `python3` do sistema, não o `.venv`.

```bash
# Configuração inicial (uma vez; pede sudo quando precisa):
./toolbox swain-macros install

# Abrir o app (ou pelo menu de aplicativos):
./toolbox swain-macros
```

Veja `apps/swain-macros/README.md` para a linguagem de macros e como desinstalar.

---

## 🤖 Ferramenta: `ask-agent` (somente Omarchy)

Responde perguntas dentro do próprio painel de busca do Omarchy: aperte
**Super + Space**, digite `ask <sua pergunta>` e Enter. Usa o agente padrão do
Omarchy (**Setup → Default → Agent**), já instalado e autenticado. Codex e
Claude Code respondem dentro do menu, sem poder executar nada; outros agentes
abrem a pergunta no próprio terminal.

```bash
# Configuração inicial (instala o plugin toolbox.ask-agent no lugar do menu):
./omarchy/ask-agent/install.sh --check   # só valida o plugin
./omarchy/ask-agent/install.sh

# Uso:
./toolbox ask-agent 'Explique memória swap'
./toolbox ask-agent --headless '2 + 2?'   # imprime a resposta, sem abrir janela
```

Veja `omarchy/ask-agent/README.md` para as variáveis de ambiente e como voltar
ao menu original.

---

## 📅 Ferramenta: `calendar` (somente Omarchy)

Mostra os eventos do Google Calendar no relógio do Omarchy, **somente leitura**,
usando o endereço iCal secreto de cada agenda (sem login no Google). A barra
mostra o próximo evento quando falta menos de uma hora, uma notificação avisa
30 minutos antes de cada evento, e clicar no relógio abre o calendário com os
eventos do dia.

```bash
./omarchy/calendar/install.sh   # instala o plugin toolbox.calendar no lugar do relógio
./toolbox calendar add          # adiciona uma agenda (pede o endereço iCal secreto)
./toolbox calendar list         # agendas configuradas, endereços mascarados
./toolbox calendar status       # último sync, quantidade de eventos, erros
```

Veja `omarchy/calendar/README.md` para onde achar o endereço no Google Calendar
e os cuidados de privacidade.

---

## 🌐 Ferramenta: `web-search` (somente Omarchy)

Busca na internet pelo navegador padrão, a partir do menu do Omarchy
(**Super + Space** → **Search Web**). Também aparece automaticamente quando
o texto digitado não casa com nenhum app ou configuração (com o plugin
`toolbox.ask-agent` instalado).

```bash
./omarchy/web-search/install.sh          # instala o plugin toolbox.web-search
./toolbox web-search                     # abre a caixa de busca
./toolbox web-search 'weather in São Paulo'

# Trocar o buscador (precisa do placeholder literal %s):
TOOLBOX_SEARCH_URL='https://duckduckgo.com/?q=%s' ./toolbox web-search 'linux audio'
```

Veja `omarchy/web-search/README.md` para os detalhes de codificação da query.

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
