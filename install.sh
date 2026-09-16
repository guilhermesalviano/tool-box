#!/usr/bin/env bash
#
# install.sh - Instalação interativa do Tool-Box em uma máquina nova.
#
# Percorre cada ferramenta, mostra o que falta e pergunta antes de instalar
# qualquer coisa (pacotes do sistema, aliases no shell, serviços). Não
# assume "sim" para nada: rodar de novo é seguro, cada passo é independente.
#

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OS="$(uname -s)"

# --- Helpers ---------------------------------------------------------------

have() { command -v "$1" >/dev/null 2>&1; }

confirm() {
  local reply
  read -r -p "$1 [y/N] " reply </dev/tty
  [[ "${reply}" =~ ^[Yy]$ ]]
}

section() {
  echo ""
  echo "=== $1 ==="
}

# Melhor esforço: tenta achar um gerenciador de pacotes e instalar "$1".
# Sempre confirma antes, já que isso mexe no sistema (e pode pedir sudo).
pkg_install() {
  local pkg="$1"
  local cmd=""
  if have brew; then
    cmd="brew install ${pkg}"
  elif have pacman; then
    cmd="sudo pacman -S --needed ${pkg}"
  elif have apt-get; then
    cmd="sudo apt-get update && sudo apt-get install -y ${pkg}"
  elif have dnf; then
    cmd="sudo dnf install -y ${pkg}"
  else
    echo "Nenhum gerenciador de pacotes suportado encontrado (brew/pacman/apt/dnf)." >&2
    echo "Instale '${pkg}' manualmente e rode este script de novo." >&2
    return 1
  fi

  if confirm "Instalar '${pkg}' agora? (${cmd})"; then
    eval "${cmd}"
  else
    echo "Pulado — a ferramenta que precisa de '${pkg}' vai avisar de novo quando você usar."
    return 1
  fi
}

echo "Tool-Box - instalação interativa"
echo "================================="
echo "Repositório: ${ROOT_DIR}"
echo "Sistema:     ${OS}"

# --- Aliases -----------------------------------------------------------

section "Atalhos de shell (tb, tb-clean, tb-mon-*, ...)"
if confirm "Instalar os atalhos do Tool-Box no seu shell?"; then
  "${ROOT_DIR}/toolbox" aliases install
else
  echo "Pulado. Rode '${ROOT_DIR}/toolbox aliases install' quando quiser."
fi

# --- Torrent DL ----------------------------------------------------------

section "Torrent DL (aria2)"
if have aria2c; then
  echo "aria2c já está instalado."
else
  echo "aria2c não encontrado (necessário para './toolbox torrent-dl')."
  pkg_install aria2 || true
fi

# --- Disk Cleaner ----------------------------------------------------------

section "Disk Cleaner"
echo "Sem pré-requisitos — usa apenas utilitários já presentes no macOS/Linux."
echo "Pronto para usar: ./toolbox disk-cleaner --dry-run"

# --- Mac/System Monitor ----------------------------------------------------

section "Mac/System Monitor (Glances)"
if have python3; then
  if confirm "Criar o virtualenv e instalar o Glances agora?"; then
    "${ROOT_DIR}/toolbox" mac-monitor setup
    if [[ "${OS}" == "Darwin" ]]; then
      if confirm "Instalar como LaunchAgent (inicia sozinho no login)?"; then
        "${ROOT_DIR}/toolbox" mac-monitor install-service
      else
        echo "Pulado. Rode './toolbox mac-monitor install-service' quando quiser."
      fi
    else
      echo "LaunchAgent é exclusivo de macOS — use './toolbox mac-monitor start' para rodar em primeiro plano."
    fi
  else
    echo "Pulado. Rode './toolbox mac-monitor start' quando quiser."
  fi
else
  echo "python3 não encontrado — necessário para o mac-monitor." >&2
  pkg_install python3 || true
fi

# --- Omarchy (Ask AI + Search Web) -----------------------------------------

section "Plugins do Omarchy (Ask AI, Search Web, Calendar)"
if ! have omarchy; then
  echo "Omarchy não detectado nesta máquina — pulando (esses plugins só existem lá)."
else
  echo "Omarchy detectado."
  if ! have jq; then
    pkg_install jq || true
  fi

  if ! have mise || ! mise which codex >/dev/null 2>&1; then
    echo "Codex (via mise) não encontrado — necessário só para responder no 'Ask AI'."
    echo "O menu e o 'Search Web' funcionam sem isso. Instale o Codex e rode este"
    echo "script de novo para habilitar as respostas, ou pule por enquanto."
  fi

  if confirm "Instalar o plugin 'Search Web' (toolbox.web-search)?"; then
    "${ROOT_DIR}/omarchy/web-search/install.sh" || echo "Falhou — veja a mensagem acima." >&2
  else
    echo "Pulado. Rode './omarchy/web-search/install.sh' quando quiser."
  fi

  if confirm "Instalar o plugin 'Calendar' (toolbox.calendar, eventos do Google Calendar no relógio)?"; then
    if "${ROOT_DIR}/omarchy/calendar/install.sh"; then
      echo "Adicione sua agenda depois com: ./toolbox calendar add"
    else
      echo "Falhou — veja a mensagem acima." >&2
    fi
  else
    echo "Pulado. Rode './omarchy/calendar/install.sh' quando quiser."
  fi

  if confirm "Instalar o plugin 'Ask AI' (toolbox.ask-agent, substitui o menu do Omarchy e reinicia o shell)?"; then
    "${ROOT_DIR}/omarchy/ask-agent/install.sh" || echo "Falhou — veja a mensagem acima." >&2
  else
    echo "Pulado. Rode './omarchy/ask-agent/install.sh' quando quiser."
  fi
fi

section "Pronto"
"${ROOT_DIR}/toolbox" list
echo ""
echo "Abra um novo shell (ou 'source' o seu rc file) para os atalhos entrarem em vigor."
