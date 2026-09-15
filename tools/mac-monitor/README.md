# Mac Monitor (Glances)

Monitor contínuo de uso de CPU e Memória para macOS, registrando métricas em arquivos CSV diários em `logs/glances-YYYY-MM-DD.csv`.

---

## 📁 Estrutura da Ferramenta

```
tools/mac-monitor/
├── collector.py       # Coletor em tempo real via Glances (daemon)
├── report.sh          # Script AWK para gerar relatório agregado
├── manage.sh          # Script de controle (start/stop/status/service)
├── launchd/           # Configuração de serviço persistente no macOS
│   └── com.guilhermesalviano.toolbox-monitor.plist.template
│       # (os caminhos são preenchidos por manage.sh install-service,
│       #  já que cada máquina pode ter clonado o tool-box em outro lugar)
└── README.md          # Documentação desta ferramenta
```

---

## 📊 Formato das Colunas (CSV)

```csv
now.iso,now.custom,cpu.total,mem.used,mem.percent
```
- `$1`: `now.iso`
- `$2`: `now.custom`
- **`$3`**: **`cpu.total` (%)**
- `$4`: `mem.used` (bytes)
- **`$5`**: **`mem.percent` (%)**

---

## 🚀 Uso Rápido

```bash
# Relatório de hoje
./tools/mac-monitor/report.sh

# Gerenciar o serviço localmente
./tools/mac-monitor/manage.sh status
./tools/mac-monitor/manage.sh restart
./tools/mac-monitor/manage.sh logs -f
```
