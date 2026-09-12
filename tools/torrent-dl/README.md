# Torrent DL

Baixa um torrent a partir de um link, usando o **aria2c** (leve, roda em
macOS e Linux, e lida com magnet links, URLs de `.torrent` e arquivos
`.torrent` locais com a mesma ferramenta).

---

## 📦 Pré-requisito

```bash
# macOS
brew install aria2

# Linux (Debian/Ubuntu)
sudo apt-get install aria2

# Linux (Fedora/RHEL)
sudo dnf install aria2
```

O script verifica se `aria2c` está no `PATH` e mostra o comando de
instalação correto para o seu sistema caso não encontre.

---

## 📁 Estrutura da Ferramenta

```
tools/torrent-dl/
├── run.sh      # Ponto de entrada
└── README.md   # Documentação desta ferramenta
```

---

## 🚀 Como Usar

```bash
# Via Toolbox CLI:
./toolbox torrent-dl '<link>' [opções]

# Diretamente:
./tools/torrent-dl/run.sh '<link>' [opções]
```

O `<link>` pode ser:
- um link magnet: `'magnet:?xt=urn:btih:...'`
- uma URL para um arquivo `.torrent`: `'https://exemplo.com/arquivo.torrent'`
- o caminho de um arquivo `.torrent` já baixado localmente

### Opções

| Opção                     | Descrição                                                        |
|---------------------------|--------------------------------------------------------------------|
| `-o, --output <dir>`      | Diretório de destino (padrão: `~/Downloads/torrents`)              |
| `-s, --seed-minutes <N>`  | Minutos de seed após terminar o download (padrão: `0`, sem seed)   |
| `-h, --help`              | Exibe a ajuda                                                      |

### Exemplos

```bash
./toolbox torrent-dl 'magnet:?xt=urn:btih:...'

./toolbox torrent-dl 'https://exemplo.com/arquivo.torrent' -o ~/Downloads

./toolbox torrent-dl ./arquivo.torrent -s 30
```

Use `Ctrl+C` para interromper — o `aria2c` grava um arquivo `.aria2` de
controle no diretório de destino, então rodar o mesmo comando de novo
retoma o download de onde parou (graças a `--continue=true`).

> Use apenas para conteúdo que você tem o direito de baixar/distribuir.
