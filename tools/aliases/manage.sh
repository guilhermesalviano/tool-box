#!/usr/bin/env bash
#
# manage.sh - Instala/remove os atalhos (aliases) do Tool-Box no seu shell.
#

set -euo pipefail

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ALIASES_FILE="${TOOL_DIR}/aliases.sh"

START_MARKER="# >>> tool-box aliases >>>"
END_MARKER="# <<< tool-box aliases <<<"

usage() {
  cat <<EOF
Uso: ./toolbox aliases <comando>

Comandos:
  install      Adiciona os atalhos ao(s) arquivo(s) de configuração do seu shell.
  uninstall    Remove os atalhos do(s) arquivo(s) de configuração do seu shell.
  status       Mostra em quais arquivos os atalhos estão instalados.
  list         Lista todos os atalhos disponíveis.
  help         Exibe esta mensagem de ajuda.
EOF
}

detect_rc_files() {
  case "$(basename "${SHELL:-}")" in
    zsh)
      echo "${HOME}/.zshrc"
      ;;
    bash)
      if [[ "$(uname -s)" == "Darwin" ]]; then
        echo "${HOME}/.bash_profile"
      else
        echo "${HOME}/.bashrc"
      fi
      ;;
    *)
      echo "${HOME}/.zshrc"
      echo "${HOME}/.bashrc"
      ;;
  esac
}

block_content() {
  cat <<EOF
${START_MARKER}
[ -f "${ALIASES_FILE}" ] && source "${ALIASES_FILE}"
${END_MARKER}
EOF
}

cmd_install() {
  local installed_any=false
  local rc
  while IFS= read -r rc; do
    [[ -n "${rc}" ]] || continue

    if ! touch "${rc}" 2>/dev/null; then
      echo "Aviso: não foi possível acessar ${rc}, pulando." >&2
      continue
    fi

    if grep -qF "${START_MARKER}" "${rc}" 2>/dev/null; then
      echo "Já instalado em: ${rc}"
      continue
    fi

    { echo ""; block_content; } >> "${rc}"
    echo "Instalado em: ${rc}"
    installed_any=true
  done < <(detect_rc_files)

  echo ""
  if ${installed_any}; then
    echo "Para usar agora, rode 'source ~/.zshrc' (ou ~/.bashrc / ~/.bash_profile)"
    echo "ou simplesmente abra um novo terminal."
  fi
  echo "Veja os atalhos disponíveis com: ./toolbox aliases list"
}

remove_block_from_file() {
  local rc="$1"
  [[ -f "${rc}" ]] || return 0

  if ! grep -qF "${START_MARKER}" "${rc}" 2>/dev/null; then
    echo "Não encontrado em: ${rc}"
    return 0
  fi

  local tmp
  tmp="$(mktemp)"
  awk -v start="${START_MARKER}" -v end="${END_MARKER}" '
    $0 == start {skip=1; next}
    $0 == end {skip=0; next}
    skip {next}
    {print}
  ' "${rc}" > "${tmp}"
  mv "${tmp}" "${rc}"
  echo "Removido de: ${rc}"
}

cmd_uninstall() {
  local rc
  while IFS= read -r rc; do
    [[ -n "${rc}" ]] || continue
    remove_block_from_file "${rc}"
  done < <(detect_rc_files)
  echo ""
  echo "Abra um novo terminal (ou rode 'exec \$SHELL') para os atalhos saírem da sessão atual."
}

cmd_status() {
  local rc
  while IFS= read -r rc; do
    [[ -n "${rc}" ]] || continue
    if [[ -f "${rc}" ]] && grep -qF "${START_MARKER}" "${rc}" 2>/dev/null; then
      echo "  [instalado]     ${rc}"
    elif [[ -f "${rc}" ]]; then
      echo "  [não instalado] ${rc}"
    else
      echo "  [não existe]    ${rc}"
    fi
  done < <(detect_rc_files)
}

cmd_list() {
  echo "Atalhos disponíveis (depois de instalar e recarregar o shell):"
  echo ""
  (
    # shellcheck disable=SC1090
    source "${ALIASES_FILE}"
    alias | sed -E "s/^alias //; s/^([a-zA-Z0-9_-]+)='(.*)'\$/  \\1 -> \\2/"
  ) | sort
}

ACTION="${1:-help}"

case "${ACTION}" in
  install)
    cmd_install
    ;;
  uninstall)
    cmd_uninstall
    ;;
  status)
    cmd_status
    ;;
  list)
    cmd_list
    ;;
  help|--help|-h)
    usage
    ;;
  *)
    echo "Erro: comando desconhecido '${ACTION}'" >&2
    usage
    exit 1
    ;;
esac
