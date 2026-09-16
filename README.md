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

---

## 📂 Estrutura do Repositório

```text
tool-box/
├── install.sh                  # Instalação interativa para uma máquina nova
├── toolbox                     # CLI mestre para listar, criar e executar qualquer ferramenta
├── tools/                      # Diretório de ferramentas modulares e isoladas
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
│   ├── swain-macros/           # Ferramenta: Macros nos botões laterais do mouse Redragon Swain (Ubuntu)
│   │   ├── run.sh              # Abre o app (ou `install` para a configuração inicial)
│   │   ├── install.sh          # Dependências apt, regra udev e atalho no menu
│   │   ├── swain_macros/       # App GTK, engine evdev/uinput e linguagem de macros
│   │   ├── data/               # Regra udev, .desktop e ícone
│   │   └── README.md           # Documentação específica do swain-macros
│   │
│   ├── ask-agent/              # Ferramenta: Respostas de IA dentro da busca do Omarchy
│   │   ├── run.sh              # Abre o painel de resposta (ou --headless para scripts)
│   │   ├── answer.sh           # Backend Codex (stdout = só a resposta)
│   │   ├── install.sh          # Clona e aplica o patch no menu do Omarchy
│   │   ├── menu.patch          # Patch sobre o Menu.qml original do Omarchy
│   │   ├── AskPane.qml         # Painel de resposta adicionado ao menu
│   │   ├── omarchy-menu.jsonc  # Extensão de menu compartilhada (Ask AI + Search Web)
│   │   └── README.md           # Documentação específica do ask-agent
│   │
│   ├── web-search/             # Ferramenta: Busca na internet a partir do menu do Omarchy
│   │   ├── run.sh              # Codifica a query e abre o navegador padrão
│   │   ├── install.sh          # Cria o launcher e indica a linha do menu
│   │   └── README.md           # Documentação específica do web-search
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
Qualquer ferramenta dentro de `tools/<nome>` pode ser executada diretamente:
```bash
./toolbox <nome-da-ferramenta> [ação/argumentos]
```

---

## 🧲 Ferramenta: `torrent-dl`

Baixa um torrent (link magnet, URL de `.torrent` ou arquivo `.torrent`
local) via `aria2c`. Requer `aria2` instalado (`brew install aria2` no
macOS, `apt-get install aria2` no Linux).

```bash
./toolbox torrent-dl 'magnet:?xt=urn:btih:...'
./toolbox torrent-dl 'https://exemplo.com/arquivo.torrent' -o ~/Downloads
```

Veja `tools/torrent-dl/README.md` para todas as opções.

---

## 🧹 Ferramenta: `disk-cleaner`

Libera espaço em disco em macOS ou Linux, limpando caches, lixeira e
arquivos temporários seguros. Pede confirmação antes de cada etapa.

```bash
# Interativo (pergunta em cada etapa):
./toolbox disk-cleaner

# Assumir "sim" em tudo, exceto nas etapas do Docker (que sempre perguntam):
./toolbox disk-cleaner --yes

# Ver o que seria limpo, sem apagar nada:
./toolbox disk-cleaner --dry-run
```

Veja `tools/disk-cleaner/README.md` para a lista completa de etapas.

---

## 🔤 Ferramenta: `aliases`

Instala atalhos de shell (`tb`, `tb-clean`, `tb-mon-status`, etc.) para os
comandos mais usados do Tool-Box.

```bash
./toolbox aliases install   # adiciona ao ~/.zshrc ou ~/.bashrc/.bash_profile
./toolbox aliases list      # lista os atalhos disponíveis
./toolbox aliases uninstall # remove os atalhos
```

Veja `tools/aliases/README.md` para a lista completa de atalhos.

---

## 🖱️ Ferramenta: `swain-macros`

App GNOME (Ubuntu, Wayland e X11) que troca a função dos botões laterais do
mouse Redragon Swain por macros (teclas, texto, cliques, scroll, comandos).
Usa o `python3` do sistema, não o `.venv`.

```bash
# Configuração inicial (uma vez; pede sudo quando precisa):
./toolbox swain-macros install

# Abrir o app (ou pelo menu de aplicativos):
./toolbox swain-macros
```

Veja `tools/swain-macros/README.md` para a linguagem de macros e como desinstalar.

---

## 🤖 Ferramenta: `ask-agent` (somente Omarchy)

Responde perguntas dentro do próprio painel de busca do Omarchy: aperte
**Super + Space**, digite `ask <sua pergunta>` e Enter. Usa o Codex já
instalado e autenticado (escolhido em **Setup → Default → Agent**), em
sandbox somente-leitura.

```bash
# Configuração inicial (clona e aplica o patch no menu do Omarchy):
./tools/ask-agent/install.sh --check   # só verifica a compatibilidade
./tools/ask-agent/install.sh

# Uso:
./toolbox ask-agent 'Explique memória swap'
./toolbox ask-agent --headless '2 + 2?'   # imprime a resposta, sem abrir janela
```

Veja `tools/ask-agent/README.md` para as variáveis de ambiente e como voltar
ao menu original.

---

## 🌐 Ferramenta: `web-search` (somente Omarchy)

Busca na internet pelo navegador padrão, a partir do menu do Omarchy
(**Super + Space** → **Search Web**). Também aparece automaticamente quando
o texto digitado não casa com nenhum app ou configuração.

```bash
./toolbox web-search 'weather in São Paulo'

# Trocar o buscador (precisa do placeholder literal %s):
TOOLBOX_SEARCH_URL='https://duckduckgo.com/?q=%s' ./toolbox web-search 'linux audio'
```

Veja `tools/web-search/README.md` para os detalhes de codificação da query.

---

## 🖥️ Ferramenta: `mac-monitor`

Monitora uso de CPU e Memória RAM continuamente via **Glances** e gera relatórios diários agregados via **AWK**.

### Gerar Relatório
```bash
# Relatório de hoje:
./toolbox mac-monitor report

# Relatório de uma data específica (ex: 2026-09-12):
./toolbox mac-monitor report 2026-09-12
```

Você também pode executar diretamente o comando AWK bruto sobre o arquivo
diário (a partir da raiz do repositório):
```bash
awk -F, '           
NR==1 {next}
{
  cpu+=$3; mem+=$5; n++
  if($3>maxcpu) maxcpu=$3
  if($5>maxmem) maxmem=$5
}
END {
  print "=== Relatório do dia ==="
  print "Amostras:", n
  print "CPU média: " cpu/n "%"
  print "CPU máxima: " maxcpu "%"
  print "Memória média: " mem/n "%"
  print "Memória máxima: " maxmem "%"
}' logs/glances-$(date +%Y-%m-%d).csv
```

### Gerenciamento do Serviço
```bash
# Ver status da execução, PID e amostras de hoje
./toolbox mac-monitor status

# Acompanhar gravação do CSV em tempo real
./toolbox mac-monitor logs -f

# Parar / Reiniciar o monitor
./toolbox mac-monitor stop
./toolbox mac-monitor restart

# Instalar / Desinstalar como LaunchAgent no macOS (inicia no boot/login)
./toolbox mac-monitor install-service
./toolbox mac-monitor uninstall-service
```

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
