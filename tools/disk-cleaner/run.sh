#!/usr/bin/env bash
#
# run.sh - Libera espaço em disco em macOS ou Linux.
#
# Por padrão, pede confirmação individual antes de cada limpeza.
# Use -y/--yes/--all para assumir "sim" em todas as etapas.
#

set -euo pipefail

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${TOOL_DIR}/../.." && pwd)"

OS="$(uname -s)"
ASSUME_YES=false
DRY_RUN=false
INCLUDE_DOCKER_VOLUMES=false
TOTAL_FREED_KB=0

usage() {
  cat <<EOF
Uso: ./toolbox disk-cleaner [opções]
     ./tools/disk-cleaner/run.sh [opções]

Limpa caches, lixeira e arquivos temporários seguros para liberar espaço
em disco, em macOS ou Linux. Cada etapa mostra o que será feito e pede
confirmação antes de executar.

Opções:
  -y, --yes, --all     Não pergunta nada: assume "sim" para todas as etapas,
                        EXCETO as etapas do Docker (veja abaixo).
  -n, --dry-run        Apenas mostra o que seria limpo, sem apagar nada.
  --docker-volumes     Também oferece remover volumes Docker não utilizados.
                        Desligado por padrão porque volumes podem conter
                        dados de bancos de dados.
  -h, --help           Exibe esta mensagem de ajuda.

Nota: as etapas de Docker (docker system prune / docker volume prune)
sempre pedem confirmação própria, mesmo com -y/--all/--yes, pois podem
remover imagens locais e volumes que não existem em nenhum outro lugar.
EOF
}

for arg in "$@"; do
  case "${arg}" in
    -y|--yes|--all)
      ASSUME_YES=true
      ;;
    -n|--dry-run)
      DRY_RUN=true
      ;;
    --docker-volumes)
      INCLUDE_DOCKER_VOLUMES=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Erro: opção desconhecida '${arg}'" >&2
      usage
      exit 1
      ;;
  esac
done

confirm_interactive() {
  local prompt="$1"
  local reply
  read -r -p "${prompt} [y/N] " reply || reply="n"
  [[ "${reply}" =~ ^[Yy]$ ]]
}

confirm() {
  local prompt="$1"
  if ${ASSUME_YES}; then
    return 0
  fi
  confirm_interactive "${prompt}"
}

free_kb() {
  df -k "${ROOT_DIR}" 2>/dev/null | awk 'NR==2 {print $4}'
}

kb_to_human() {
  local kb="$1"
  awk -v kb="${kb}" 'BEGIN {
    if (kb >= 1048576) printf "%.2f GB", kb/1048576
    else if (kb >= 1024) printf "%.2f MB", kb/1024
    else printf "%d KB", kb
  }'
}

# perform_step <rótulo> <caminho-para-mostrar-tamanho-ou-vazio> <comando-a-executar> [force_ask]
#   force_ask=true ignora -y/--all/--yes e sempre pede confirmação interativa
#   (usado nas etapas do Docker, onde queremos uma pergunta dedicada mesmo
#   quando o resto da limpeza roda sem perguntar nada).
perform_step() {
  local label="$1" info_path="$2" cmd="$3" force_ask="${4:-false}"

  echo ""
  echo "-> ${label}"

  if [[ -n "${info_path}" ]]; then
    if [[ -e "${info_path}" ]]; then
      echo "   Caminho: ${info_path} ($(du -sh "${info_path}" 2>/dev/null | cut -f1))"
    else
      echo "   (não encontrado, pulando)"
      return 0
    fi
  fi

  if ${DRY_RUN}; then
    echo "   [dry-run] nenhuma ação executada"
    return 0
  fi

  local approved=false
  if ${force_ask}; then
    confirm_interactive "   Deseja executar essa limpeza?" && approved=true || true
  else
    confirm "   Deseja executar essa limpeza?" && approved=true || true
  fi

  if ! ${approved}; then
    echo "   Pulado."
    return 0
  fi

  local before after freed
  before=$(free_kb)
  eval "${cmd}" || echo "   Aviso: comando terminou com erro (ignorado)."
  after=$(free_kb)
  freed=$(( after - before ))

  if (( freed > 0 )); then
    TOTAL_FREED_KB=$(( TOTAL_FREED_KB + freed ))
    echo "   OK. Espaço liberado nesta etapa: $(kb_to_human "${freed}")"
  else
    echo "   OK."
  fi
}

# ---------------------------------------------------------------------------
# Etapas de limpeza
# ---------------------------------------------------------------------------

task_user_cache() {
  local target
  case "${OS}" in
    Darwin) target="${HOME}/Library/Caches" ;;
    *) target="${HOME}/.cache" ;;
  esac
  perform_step "Cache de usuário" "${target}" \
    "find \"${target}\" -mindepth 1 -maxdepth 1 -exec rm -rf {} +"
}

task_trash() {
  local target
  case "${OS}" in
    Darwin) target="${HOME}/.Trash" ;;
    *) target="${HOME}/.local/share/Trash" ;;
  esac
  perform_step "Lixeira" "${target}" \
    "find \"${target}\" -mindepth 1 -maxdepth 1 -exec rm -rf {} +"
}

task_homebrew() {
  [[ "${OS}" == "Darwin" ]] || return 0
  command -v brew >/dev/null 2>&1 || return 0
  perform_step "Cache do Homebrew (brew cleanup -s)" "" "brew cleanup -s"
}

task_xcode_derived_data() {
  [[ "${OS}" == "Darwin" ]] || return 0
  local target="${HOME}/Library/Developer/Xcode/DerivedData"
  [[ -d "${target}" ]] || return 0
  perform_step "Xcode DerivedData" "${target}" \
    "find \"${target}\" -mindepth 1 -maxdepth 1 -exec rm -rf {} +"
}

docker_daemon_reachable() {
  command -v docker >/dev/null 2>&1 || return 1

  # docker info trava por bastante tempo se o daemon não estiver rodando
  # (comum quando o Docker Desktop está fechado), então limitamos o tempo
  # de espera usando um arquivo marcador em vez de checar o status direto
  # (evita interações estranhas com "set -e").
  local marker pid waited=0
  marker="$(mktemp)"
  ( docker info >/dev/null 2>&1 && echo ok > "${marker}" ) &
  pid=$!

  while kill -0 "${pid}" 2>/dev/null && (( waited < 5 )); do
    sleep 1
    waited=$(( waited + 1 ))
  done
  kill "${pid}" 2>/dev/null || true
  wait "${pid}" 2>/dev/null || true

  local reachable=1
  [[ -s "${marker}" ]] && reachable=0
  rm -f "${marker}"
  return "${reachable}"
}

task_docker() {
  docker_daemon_reachable || return 0
  # force_ask=true: docker system prune sempre pergunta, mesmo com -y/--all,
  # já que pode remover imagens locais que não existem em nenhum registry.
  perform_step "Docker: containers parados, redes e imagens não usadas, cache de build (docker system prune)" "" \
    "docker system prune -f" true
}

task_docker_volumes() {
  ${INCLUDE_DOCKER_VOLUMES} || return 0
  docker_daemon_reachable || return 0
  # force_ask=true: volumes podem conter dados de bancos de dados, então
  # essa etapa sempre pergunta, mesmo com -y/--all.
  perform_step "Docker: volumes não utilizados — CUIDADO: podem conter dados de bancos de dados (docker volume prune)" "" \
    "docker volume prune -f" true
}

task_npm_cache() {
  command -v npm >/dev/null 2>&1 || return 0
  local target="${HOME}/.npm"
  perform_step "Cache do npm" "${target}" "npm cache clean --force"
}

task_yarn_cache() {
  command -v yarn >/dev/null 2>&1 || return 0
  local target
  target=$(yarn cache dir 2>/dev/null || echo "")
  perform_step "Cache do Yarn" "${target}" "yarn cache clean"
}

task_pip_cache() {
  local pipcmd=""
  if command -v pip3 >/dev/null 2>&1; then
    pipcmd="pip3"
  elif command -v pip >/dev/null 2>&1; then
    pipcmd="pip"
  else
    return 0
  fi
  local target
  target=$("${pipcmd}" cache dir 2>/dev/null || echo "")
  perform_step "Cache do ${pipcmd}" "${target}" "${pipcmd} cache purge"
}

task_conda_cache() {
  command -v conda >/dev/null 2>&1 || return 0
  perform_step "Cache do Conda (pacotes baixados, tarballs, ambientes não usados)" "" \
    "conda clean --all -y"
}

task_cargo_cache() {
  command -v cargo >/dev/null 2>&1 || return 0
  local target="${HOME}/.cargo/registry/cache"
  [[ -d "${target}" ]] || return 0
  perform_step "Cache do Cargo (crates baixados; serão rebaixados se precisar)" "${target}" \
    "find \"${target}\" -mindepth 1 -maxdepth 1 -exec rm -rf {} +"
}

task_go_build_cache() {
  command -v go >/dev/null 2>&1 || return 0
  local target
  target=$(go env GOCACHE 2>/dev/null || echo "")
  perform_step "Cache de build do Go" "${target}" "go clean -cache"
}

task_gradle_cache() {
  local target="${HOME}/.gradle/caches"
  [[ -d "${target}" ]] || return 0
  perform_step "Cache do Gradle" "${target}" \
    "find \"${target}\" -mindepth 1 -maxdepth 1 -exec rm -rf {} +"
}

task_composer_cache() {
  command -v composer >/dev/null 2>&1 || return 0
  local target
  case "${OS}" in
    Darwin) target="${HOME}/Library/Caches/composer" ;;
    *) target="${HOME}/.cache/composer" ;;
  esac
  perform_step "Cache do Composer" "${target}" "composer clear-cache"
}

task_cocoapods_cache() {
  [[ "${OS}" == "Darwin" ]] || return 0
  command -v pod >/dev/null 2>&1 || return 0
  local target="${HOME}/Library/Caches/CocoaPods"
  perform_step "Cache do CocoaPods" "${target}" "pod cache clean --all"
}

task_quicklook_cache() {
  [[ "${OS}" == "Darwin" ]] || return 0
  command -v qlmanage >/dev/null 2>&1 || return 0
  perform_step "Cache de miniaturas do QuickLook" "" "qlmanage -r cache && qlmanage -r"
}

_delete_tmutil_snapshots() {
  tmutil listlocalsnapshots / 2>/dev/null | sed -n 's/.*TimeMachine\.//p' | while IFS= read -r ts; do
    sudo tmutil deletelocalsnapshots "${ts}" || true
  done
}

task_tmutil_snapshots() {
  [[ "${OS}" == "Darwin" ]] || return 0
  command -v tmutil >/dev/null 2>&1 || return 0
  local count
  count=$(tmutil listlocalsnapshots / 2>/dev/null | grep -c "TimeMachine" || true)
  (( count > 0 )) || return 0
  perform_step "Snapshots locais do Time Machine (${count} encontrado(s); o macOS já os libera sozinho sob pressão de espaço) — pode pedir senha (sudo)" \
    "" "_delete_tmutil_snapshots"
}

task_apt_cache() {
  [[ "${OS}" == "Linux" ]] || return 0
  command -v apt-get >/dev/null 2>&1 || return 0
  perform_step "Cache do APT (/var/cache/apt/archives) — pode pedir senha (sudo)" \
    "/var/cache/apt/archives" "sudo apt-get clean"
}

task_apt_autoremove() {
  [[ "${OS}" == "Linux" ]] || return 0
  command -v apt-get >/dev/null 2>&1 || return 0
  perform_step "Pacotes não usados, incluindo kernels antigos (apt autoremove --purge) — pode pedir senha (sudo)" \
    "" "sudo apt-get autoremove --purge -y"
}

task_dnf_yum_cache() {
  [[ "${OS}" == "Linux" ]] || return 0
  local pm=""
  if command -v dnf >/dev/null 2>&1; then
    pm="dnf"
  elif command -v yum >/dev/null 2>&1; then
    pm="yum"
  else
    return 0
  fi
  perform_step "Cache do ${pm} — pode pedir senha (sudo)" "" "sudo ${pm} clean all"
}

_cleanup_snap_revisions() {
  LANG=C snap list --all 2>/dev/null | awk '/disabled/{print $1, $3}' | while read -r snapname revision; do
    sudo snap remove "${snapname}" --revision="${revision}" || true
  done
}

task_snap_cleanup() {
  [[ "${OS}" == "Linux" ]] || return 0
  command -v snap >/dev/null 2>&1 || return 0
  perform_step "Revisões antigas/desabilitadas de pacotes Snap — pode pedir senha (sudo)" \
    "" "_cleanup_snap_revisions"
}

task_flatpak_cleanup() {
  [[ "${OS}" == "Linux" ]] || return 0
  command -v flatpak >/dev/null 2>&1 || return 0
  perform_step "Runtimes do Flatpak não usados" "" "flatpak uninstall --unused -y"
}

task_journal_logs() {
  [[ "${OS}" == "Linux" ]] || return 0
  command -v journalctl >/dev/null 2>&1 || return 0
  perform_step "Logs do systemd-journal (mantém últimos 7 dias) — pode pedir senha (sudo)" \
    "" "sudo journalctl --vacuum-time=7d"
}

# ---------------------------------------------------------------------------
# Execução
# ---------------------------------------------------------------------------

echo "=========================================="
echo "disk-cleaner - liberação de espaço em disco"
echo "Sistema detectado: ${OS}"
${DRY_RUN} && echo "Modo: dry-run (nada será apagado)"
${ASSUME_YES} && echo "Modo: assumir 'sim' em todas as etapas"
echo "=========================================="

task_user_cache
task_trash
task_homebrew
task_xcode_derived_data
task_cocoapods_cache
task_quicklook_cache
task_tmutil_snapshots
task_docker
task_docker_volumes
task_npm_cache
task_yarn_cache
task_pip_cache
task_conda_cache
task_cargo_cache
task_go_build_cache
task_gradle_cache
task_composer_cache
task_apt_cache
task_apt_autoremove
task_dnf_yum_cache
task_snap_cleanup
task_flatpak_cleanup
task_journal_logs

echo ""
echo "=========================================="
if ${DRY_RUN}; then
  echo "Dry-run concluído. Nenhum arquivo foi removido."
else
  echo "Limpeza concluída."
  echo "Espaço total liberado: $(kb_to_human "${TOTAL_FREED_KB}")"
fi
echo "=========================================="
