#!/usr/bin/env bash
#
# tools/mac-monitor/manage.sh - Gerenciador do Mac Monitor (Glances)
#

set -e

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${TOOL_DIR}/../.." && pwd)"
PYTHON="${ROOT_DIR}/.venv/bin/python3"
COLLECTOR="${TOOL_DIR}/collector.py"
REPORT="${TOOL_DIR}/report.sh"
LOGS_DIR="${ROOT_DIR}/logs"
PID_FILE="${LOGS_DIR}/monitor.pid"
SERVICE_NAME="com.guilhermesalviano.toolbox-monitor"
PLIST_TEMPLATE="${TOOL_DIR}/launchd/${SERVICE_NAME}.plist.template"
PLIST_DEST="${HOME}/Library/LaunchAgents/${SERVICE_NAME}.plist"

mkdir -p "${LOGS_DIR}"

ensure_venv() {
  if [[ ! -x "${PYTHON}" ]]; then
    echo "Ambiente virtual não encontrado em .venv/. Criando..."
    python3 -m venv "${ROOT_DIR}/.venv"
    "${ROOT_DIR}/.venv/bin/pip" install --upgrade pip glances
  fi
}

# launchctl só existe no macOS. O redirecionamento precisa ficar no próprio
# launchctl (e não no grep) para que "command not found" não vaze no stderr
# quando o monitor roda em Linux.
service_loaded() {
  launchctl list 2>/dev/null | grep -q "${SERVICE_NAME}"
}

get_pid() {
  if [[ -f "${PID_FILE}" ]]; then
    local pid
    pid=$(cat "${PID_FILE}" 2>/dev/null || true)
    if [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null; then
      echo "${pid}"
      return 0
    fi
  fi
  pgrep -f "${COLLECTOR}" | head -n 1 || true
}

cmd_start() {
  ensure_venv
  local pid
  pid=$(get_pid)
  if [[ -n "${pid}" ]]; then
    echo "Mac Monitor já está em execução (PID: ${pid})."
    return 0
  fi

  if service_loaded; then
    echo "Iniciando via launchd service..."
    launchctl start "${SERVICE_NAME}"
    sleep 1
    echo "Mac Monitor iniciado via LaunchAgent."
    return 0
  fi

  echo "Iniciando Mac Monitor em segundo plano..."
  nohup "${PYTHON}" "${COLLECTOR}" >> "${LOGS_DIR}/monitor-service.log" 2>> "${LOGS_DIR}/monitor-service-err.log" &
  local new_pid=$!
  echo "${new_pid}" > "${PID_FILE}"
  sleep 1
  if kill -0 "${new_pid}" 2>/dev/null; then
    echo "Mac Monitor iniciado com sucesso (PID: ${new_pid})."
  else
    echo "Erro ao iniciar o monitor. Verifique ${LOGS_DIR}/monitor-service-err.log" >&2
    exit 1
  fi
}

cmd_stop() {
  local pid
  pid=$(get_pid)

  if service_loaded; then
    echo "Parando LaunchAgent ${SERVICE_NAME}..."
    launchctl stop "${SERVICE_NAME}" 2>/dev/null || true
  fi

  if [[ -n "${pid}" ]]; then
    echo "Finalizando processo PID: ${pid}..."
    kill -TERM "${pid}" 2>/dev/null || true
    for _ in {1..10}; do
      if ! kill -0 "${pid}" 2>/dev/null; then
        break
      fi
      sleep 0.5
    done
    if kill -0 "${pid}" 2>/dev/null; then
      echo "Forçando finalização (SIGKILL)..."
      kill -9 "${pid}" 2>/dev/null || true
    fi
    rm -f "${PID_FILE}"
    echo "Mac Monitor finalizado."
  else
    echo "Mac Monitor não está em execução."
  fi
}

cmd_restart() {
  cmd_stop
  sleep 1
  cmd_start
}

cmd_status() {
  local pid
  pid=$(get_pid)
  echo "=========================================="
  echo "Status: Mac Monitor (Glances)"
  echo "=========================================="

  if [[ -n "${pid}" ]]; then
    echo "Status:   EM EXECUÇÃO (PID: ${pid})"
  else
    echo "Status:   PARADO"
  fi

  if [[ -f "${PLIST_DEST}" ]]; then
    local loaded="Não"
    if service_loaded; then
      loaded="Sim (ativo)"
    fi
    echo "Serviço:  Instalado em LaunchAgents (${loaded})"
  else
    echo "Serviço:  Não instalado como LaunchAgent"
  fi

  local today_csv="${LOGS_DIR}/glances-$(date +%Y-%m-%d).csv"
  if [[ -f "${today_csv}" ]]; then
    local lines
    lines=$(wc -l < "${today_csv}" | tr -d ' ')
    local samples=$((lines > 1 ? lines - 1 : 0))
    local size
    size=$(ls -lh "${today_csv}" | awk '{print $5}')
    echo "Hoje:     ${today_csv} (${size}, ${samples} amostras)"
  else
    echo "Hoje:     Nenhum log gerado ainda hoje (${today_csv})"
  fi
  echo "=========================================="
}

cmd_report() {
  "${REPORT}" "$@"
}

cmd_logs() {
  local today_csv="${LOGS_DIR}/glances-$(date +%Y-%m-%d).csv"
  if [[ "${1:-}" == "-f" ]]; then
    if [[ ! -f "${today_csv}" ]]; then
      touch "${today_csv}"
    fi
    tail -f "${today_csv}"
  else
    if [[ -f "${today_csv}" ]]; then
      tail -n 20 "${today_csv}"
    else
      echo "Nenhum log encontrado para hoje."
    fi
  fi
}

cmd_install_service() {
  ensure_venv
  echo "Instalando LaunchAgent em ${PLIST_DEST}..."
  mkdir -p "${HOME}/Library/LaunchAgents"

  local pid
  pid=$(get_pid)
  if [[ -n "${pid}" ]]; then
    echo "Parando instância atual..."
    cmd_stop
  fi

  # O template não tem caminho absoluto nenhum embutido: cada máquina/usuário
  # pode ter clonado o tool-box em um lugar diferente, então os caminhos reais
  # são preenchidos aqui a partir de ROOT_DIR/HOME antes de instalar o plist.
  sed \
    -e "s|__PYTHON__|${PYTHON}|g" \
    -e "s|__COLLECTOR__|${COLLECTOR}|g" \
    -e "s|__ROOT_DIR__|${ROOT_DIR}|g" \
    -e "s|__STDOUT__|${LOGS_DIR}/monitor-service.log|g" \
    -e "s|__STDERR__|${LOGS_DIR}/monitor-service-err.log|g" \
    "${PLIST_TEMPLATE}" > "${PLIST_DEST}"

  if service_loaded; then
    launchctl unload "${PLIST_DEST}" 2>/dev/null || true
  fi

  launchctl load "${PLIST_DEST}"
  echo "LaunchAgent carregado com sucesso!"
  echo "O Mac Monitor agora iniciará automaticamente no login do macOS."
  sleep 1
  cmd_status
}

cmd_uninstall_service() {
  echo "Removendo LaunchAgent..."
  if [[ -f "${PLIST_DEST}" ]]; then
    launchctl unload "${PLIST_DEST}" 2>/dev/null || true
    rm -f "${PLIST_DEST}"
    echo "LaunchAgent desinstalado com sucesso."
  else
    echo "LaunchAgent não estava instalado."
  fi
  cmd_stop
}

case "${1:-}" in
  setup)
    ensure_venv
    echo "Virtualenv pronto em ${ROOT_DIR}/.venv."
    ;;
  start)
    cmd_start
    ;;
  stop)
    cmd_stop
    ;;
  restart)
    cmd_restart
    ;;
  status)
    cmd_status
    ;;
  report)
    shift
    cmd_report "$@"
    ;;
  logs)
    shift
    cmd_logs "$@"
    ;;
  install-service)
    cmd_install_service
    ;;
  uninstall-service)
    cmd_uninstall_service
    ;;
  *)
    echo "Uso: $0 {setup|start|stop|restart|status|report [data]|logs [-f]|install-service|uninstall-service}"
    exit 1
    ;;
esac
