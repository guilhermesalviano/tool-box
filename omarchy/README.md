# 🟢 Plugins Omarchy do Tool-Box

Documentação dos plugins do shell do Omarchy em `omarchy/` (só funcionam
nessa distro). Rodam pelo CLI mestre a partir da raiz do repositório:
`./toolbox <nome-do-plugin> [ação/argumentos]`.

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

Veja [`ask-agent/README.md`](ask-agent/README.md) para as variáveis de ambiente e como voltar
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

Veja [`calendar/README.md`](calendar/README.md) para onde achar o endereço no Google Calendar
e os cuidados de privacidade.

---

## 🐋 Ferramenta: `orca` (somente Omarchy)

Mostra na barra os workspaces abertos no Orca e quantos agentes estão rodando
(`󰉋 3  󰚩 2`). O ícone fica na cor de alerta quando um agente espera aprovação
ou resposta, e some da barra com o Orca fechado. Clicar abre a lista de
workspaces com seus agentes; clicar numa linha traz o Orca para a frente
naquele terminal.

```bash
./omarchy/orca/install.sh   # instala o plugin toolbox.orca e adiciona à barra
./toolbox orca              # workspaces e agentes rodando, no terminal
./toolbox orca focus        # traz o Orca para a frente
```

Veja [`orca/README.md`](orca/README.md) para as configurações e como os dados
são lidos do CLI do Orca.

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

Veja [`web-search/README.md`](web-search/README.md) para os detalhes de codificação da query.
