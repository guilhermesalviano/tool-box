# 🧰 Tool-Box

Repositório modular de utilitários, automações e scripts de manutenção para macOS / servidor.

A estrutura foi projetada para suportar múltiplos scripts e ferramentas de forma isolada, padronizada e fácil de gerenciar através de um CLI unificado (`./toolbox`).

---

## 📂 Estrutura do Repositório

```text
tool-box/
├── toolbox                     # CLI mestre para listar, criar e executar qualquer ferramenta
├── tools/                      # Diretório de ferramentas modulares e isoladas
│   ├── mac-monitor/            # Ferramenta: Monitor de Uso de CPU e Memória (Glances)
│   │   ├── collector.py        # Coletor contínuo (streaming Glances -> CSV)
│   │   ├── report.sh           # Script AWK para agregação de estatísticas do dia
│   │   ├── manage.sh           # Gerenciador local do mac-monitor
│   │   ├── launchd/            # Configuração de serviço persistente no macOS
│   │   │   └── com.guilhermesalviano.toolbox-monitor.plist
│   │   └── README.md           # Documentação específica do mac-monitor
│   │
│   └── _template/              # Molde para criar novas ferramentas com um comando
│       ├── run.sh
│       └── README.md
│
├── logs/                       # Diretório central de logs
│   ├── glances-YYYY-MM-DD.csv  # Arquivos diários gerados pelo mac-monitor
│   └── ...
│
├── manage.sh                   # Atalho de compatibilidade para ./toolbox mac-monitor
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

## 🖥️ Ferramenta: `mac-monitor`

Monitora uso de CPU e Memória RAM continuamente via **Glances** e gera relatórios diários agregados via **AWK**.

### Gerar Relatório
```bash
# Relatório de hoje:
./toolbox mac-monitor report

# Relatório de uma data específica (ex: 2026-09-12):
./toolbox mac-monitor report 2026-09-12
```

Você também pode executar diretamente o comando AWK bruto sobre o arquivo diário:
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
}' ~/ServerApps/tool-box/logs/glances-$(date +%Y-%m-%d).csv
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
