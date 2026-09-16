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

section "Integrações do menu do Omarchy (Ask AI, Search Web)"
if ! have omarchy; then
  echo "Omarchy não detectado nesta máquina — pulando (essas duas ferramentas só existem lá)."
else
  echo "Omarchy detectado."
  ok=true
  if ! have jq; then
    pkg_install jq || ok=false
  fi
  if ! have rg; then
    pkg_install ripgrep || ok=false
  fi

  if ! have mise || ! mise which codex >/dev/null 2>&1; then
    echo "Codex (via mise) não encontrado — necessário só para 'Ask AI'."
    echo "'Search Web' funciona sem isso. Instale o Codex e rode este script de novo"
    echo "para habilitar o Ask AI, ou pule por enquanto."
  fi

  menu_ext="${HOME}/.config/omarchy/extensions/omarchy-menu.jsonc"
  shared_jsonc="${ROOT_DIR}/omarchy/ask-agent/omarchy-menu.jsonc"
  has_custom_entries=false
  if [[ -f "${menu_ext}" && ! -L "${menu_ext}" ]]; then
    # Considera "customizado" qualquer linha "chave": fora de comentário —
    # o arquivo padrão do Omarchy só tem exemplos comentados.
    if grep -vE '^\s*//' "${menu_ext}" | grep -qE '"[A-Za-z0-9_.-]+"\s*:'; then
      has_custom_entries=true
    fi
  fi

  if [[ -L "${menu_ext}" && "$(readlink -f "${menu_ext}")" == "$(readlink -f "${shared_jsonc}")" ]]; then
    echo "Extensão do menu já aponta para o arquivo compartilhado do Tool-Box."
  elif [[ "${has_custom_entries}" == true ]]; then
    echo "Você já tem entradas próprias em ${menu_ext} — não vou sobrescrever."
    echo "Adicione manualmente as linhas de ${shared_jsonc} lá (veja omarchy/ask-agent/README.md)."
  elif confirm "Apontar ${menu_ext} para o arquivo compartilhado do Tool-Box (Ask AI + Search Web)?"; then
    mkdir -p "$(dirname "${menu_ext}")"
    if [[ -f "${menu_ext}" ]]; then
      backup="${menu_ext}.bak.$(date +%Y%m%d-%H%M%S)"
      cp "${menu_ext}" "${backup}"
      echo "Backup salvo em ${backup}"
    fi
    ln -sfn "${shared_jsonc}" "${menu_ext}"
  else
    echo "Pulado — os instaladores abaixo vão pedir isso de novo."
  fi

  if confirm "Instalar 'Ask AI' (clona o plugin de menu do Omarchy)?"; then
    "${ROOT_DIR}/omarchy/ask-agent/install.sh" || echo "Falhou — veja a mensagem acima." >&2
  else
    echo "Pulado. Rode './omarchy/ask-agent/install.sh' quando quiser."
  fi

  if confirm "Instalar 'Search Web'?"; then
    "${ROOT_DIR}/omarchy/web-search/install.sh" || echo "Falhou — veja a mensagem acima." >&2
  else
    echo "Pulado. Rode './omarchy/web-search/install.sh' quando quiser."
  fi
fi

section "Pronto"
"${ROOT_DIR}/toolbox" list
echo ""
echo "Abra um novo shell (ou 'source' o seu rc file) para os atalhos entrarem em vigor."
