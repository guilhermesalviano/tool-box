# Disk Cleaner

Libera espaço em disco em **macOS** ou **Linux**, limpando caches, lixeira e
arquivos temporários seguros. Cada etapa mostra o caminho/comando e o
tamanho estimado antes de pedir confirmação para executar.

---

## 📁 Estrutura da Ferramenta

```
tools/disk-cleaner/
├── run.sh          # Ponto de entrada (detecta o SO e executa as etapas)
└── README.md       # Documentação desta ferramenta
```

---

## 🧹 O que é limpo

| Etapa                                    | macOS | Linux | Observação                                   |
|--------------------------------------------|:-----:|:-----:|------------------------------------------------|
| Cache de usuário                           |  ✅   |  ✅   | `~/Library/Caches` / `~/.cache`                |
| Lixeira                                    |  ✅   |  ✅   | `~/.Trash` / `~/.local/share/Trash`            |
| Cache do Homebrew (`brew cleanup`)         |  ✅   |  —    | Só roda se `brew` estiver instalado            |
| Xcode DerivedData                          |  ✅   |  —    |                                                 |
| Cache do CocoaPods                         |  ✅   |  —    | Só roda se `pod` estiver instalado             |
| Cache de miniaturas do QuickLook           |  ✅   |  —    |                                                 |
| Snapshots locais do Time Machine           |  ✅   |  —    | Requer `sudo`; o macOS já libera sozinho sob pressão de espaço |
| Docker: containers/imagens/rede/build-cache (`docker system prune`) | ✅ | ✅ | Só roda se o daemon do Docker estiver ativo |
| Docker: volumes não usados (`docker volume prune`) | ✅ | ✅ | **Desligado por padrão** — requer `--docker-volumes`; pode conter dados de bancos de dados |
| Cache do npm                               |  ✅   |  ✅   | Só roda se `npm` estiver instalado             |
| Cache do Yarn                              |  ✅   |  ✅   | Só roda se `yarn` estiver instalado            |
| Cache do pip                               |  ✅   |  ✅   | Só roda se `pip`/`pip3` estiver instalado      |
| Cache do Conda                             |  ✅   |  ✅   | Só roda se `conda` estiver instalado           |
| Cache do Cargo (crates baixados)           |  ✅   |  ✅   | Só roda se `cargo` estiver instalado           |
| Cache de build do Go                       |  ✅   |  ✅   | Só roda se `go` estiver instalado              |
| Cache do Gradle                            |  ✅   |  ✅   | Roda se `~/.gradle/caches` existir             |
| Cache do Composer                          |  ✅   |  ✅   | Só roda se `composer` estiver instalado        |
| Cache do APT                                |  —    |  ✅   | Requer `sudo`                                  |
| Pacotes/kernels antigos (`apt autoremove`)  |  —    |  ✅   | Requer `sudo`                                  |
| Cache do DNF/YUM                            |  —    |  ✅   | Requer `sudo`                                  |
| Revisões antigas de Snap                    |  —    |  ✅   | Requer `sudo`                                  |
| Runtimes não usados do Flatpak              |  —    |  ✅   |                                                 |
| Logs do systemd-journal (>7 dias)           |  —    |  ✅   | Requer `sudo`                                  |

Nenhuma etapa apaga arquivos pessoais (Documentos, Downloads, Desktop etc.) —
apenas caches, lixeira e arquivos temporários que os próprios programas
recriam quando necessário. A única exceção é o prune de **volumes** do
Docker, que fica desligado por padrão (mesmo com `--yes`) por poder conter
dados de bancos de dados — só entra na lista de etapas com `--docker-volumes`,
e ainda assim continua pedindo confirmação individual a menos que combinado
com `-y`.

---

## 🚀 Como Usar

```bash
# Via Toolbox CLI (pede confirmação em cada etapa):
./toolbox disk-cleaner

# Diretamente:
./tools/disk-cleaner/run.sh

# Assumir "sim" em todas as etapas, sem perguntar nada:
./toolbox disk-cleaner --yes
./toolbox disk-cleaner -y
./toolbox disk-cleaner --all

# Ver o que seria limpo sem apagar nada:
./toolbox disk-cleaner --dry-run

# Também oferecer limpar volumes Docker não usados (cuidado: pode
# conter dados de bancos de dados; ainda pede confirmação sem -y):
./toolbox disk-cleaner --docker-volumes

# Ajuda:
./toolbox disk-cleaner --help
```

Ao final, o script informa o total de espaço liberado.
