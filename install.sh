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

# --- Zsh + Oh My Zsh ---------------------------------------------------------
#
# Vem antes dos aliases: o instalador do Oh My Zsh troca o ~/.zshrc (o antigo
# vira ~/.zshrc.pre-oh-my-zsh), então os aliases precisam entrar depois.

section "Zsh + Oh My Zsh (autosuggestions, syntax highlighting)"
if ! have zsh; then
  echo "zsh não encontrado."
  pkg_install zsh || true
else
  echo "zsh já está instalado."
fi

OMZ_DIR="${HOME}/.oh-my-zsh"
if have zsh; then
  if [[ -d "${OMZ_DIR}" ]]; then
    echo "Oh My Zsh já está instalado em ${OMZ_DIR}."
  elif ! have git || ! have curl; then
    echo "Oh My Zsh precisa de git e curl — instale-os e rode este script de novo." >&2
  elif confirm "Instalar o Oh My Zsh? (o ~/.zshrc atual vira ~/.zshrc.pre-oh-my-zsh)"; then
    RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended \
      || echo "Falhou — veja a mensagem acima." >&2
  else
    echo "Pulado."
  fi
fi

if [[ -d "${OMZ_DIR}" ]]; then
  ZSH_PLUGINS_DIR="${ZSH_CUSTOM:-${OMZ_DIR}/custom}/plugins"
  zsh_plugins=(
    "zsh-autosuggestions https://github.com/zsh-users/zsh-autosuggestions"
    "zsh-syntax-highlighting https://github.com/zsh-users/zsh-syntax-highlighting"
    "fast-syntax-highlighting https://github.com/zdharma-continuum/fast-syntax-highlighting"
  )
  missing=()
  for entry in "${zsh_plugins[@]}"; do
    [[ -d "${ZSH_PLUGINS_DIR}/${entry%% *}" ]] || missing+=("${entry}")
  done

  if [[ ${#missing[@]} -eq 0 ]]; then
    echo "Plugins do zsh já estão instalados em ${ZSH_PLUGINS_DIR}."
  elif confirm "Instalar os plugins do zsh (${#missing[@]} faltando: $(printf '%s ' "${missing[@]%% *}"))?"; then
    mkdir -p "${ZSH_PLUGINS_DIR}"
    for entry in "${missing[@]}"; do
      git clone --depth 1 "${entry#* }" "${ZSH_PLUGINS_DIR}/${entry%% *}" \
        || echo "Falhou ao clonar ${entry%% *}." >&2
    done
  else
    echo "Pulado."
  fi

  # zsh-syntax-highlighting e fast-syntax-highlighting fazem a mesma coisa e
  # conflitam se carregados juntos: carrega o fast e usa o outro só de reserva.
  ZSH_START_MARKER="# >>> tool-box zsh plugins >>>"
  ZSH_END_MARKER="# <<< tool-box zsh plugins <<<"
  if grep -qF "${ZSH_START_MARKER}" "${HOME}/.zshrc" 2>/dev/null; then
    echo "Plugins já ativados no ~/.zshrc."
  elif confirm "Ativar os plugins no ~/.zshrc?"; then
    cat >> "${HOME}/.zshrc" <<EOF

${ZSH_START_MARKER}
_tb_zsh_plugins="\${ZSH_CUSTOM:-\${ZSH:-\$HOME/.oh-my-zsh}/custom}/plugins"
[[ -r "\${_tb_zsh_plugins}/zsh-autosuggestions/zsh-autosuggestions.zsh" ]] \\
  && source "\${_tb_zsh_plugins}/zsh-autosuggestions/zsh-autosuggestions.zsh"
if [[ -r "\${_tb_zsh_plugins}/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh" ]]; then
  source "\${_tb_zsh_plugins}/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh"
elif [[ -r "\${_tb_zsh_plugins}/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
  source "\${_tb_zsh_plugins}/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi
unset _tb_zsh_plugins
${ZSH_END_MARKER}
EOF
    echo "Ativado em: ${HOME}/.zshrc"
  else
    echo "Pulado."
  fi
fi

if have zsh && [[ "$(basename "${SHELL:-}")" != zsh ]]; then
  if confirm "Tornar o zsh o shell padrão? (chsh -s $(command -v zsh))"; then
    # Atualiza $SHELL para os aliases (logo abaixo) irem para o ~/.zshrc.
    chsh -s "$(command -v zsh)" && export SHELL="$(command -v zsh)" || echo "Falhou — rode 'chsh -s $(command -v zsh)' manualmente." >&2
  else
    echo "Pulado. Rode 'chsh -s $(command -v zsh)' quando quiser."
  fi
fi

# --- Aliases -----------------------------------------------------------

section "Atalhos de shell (tb, tb-clean, tb-mon-*, ...)"
if confirm "Instalar os atalhos do Tool-Box no seu shell?"; then
  "${ROOT_DIR}/toolbox" aliases install
else
  echo "Pulado. Rode '${ROOT_DIR}/toolbox aliases install' quando quiser."
fi

# --- RTK (Rust Token Killer) -------------------------------------------------
#
# Proxy de CLI que comprime a saída de comandos (git, ls, testes...) antes de
# chegar no contexto dos agentes de código. O `rtk init` instala um hook que
# reescreve `git status` em `rtk git status` sozinho, então cada agente precisa
# ser ativado uma vez.

section "RTK (economia de tokens nos agentes de código)"
if have rtk; then
  echo "rtk já está instalado ($(rtk --version 2>/dev/null))."
else
  echo "rtk não encontrado."
  # Não existe no pacman/apt: brew, AUR ou o script oficial (~/.local/bin).
  # Evite 'cargo install rtk' — no crates.io esse nome é outro projeto.
  if have brew; then
    rtk_cmd="brew install rtk"
  elif have yay; then
    rtk_cmd="yay -S --needed rtk"
  elif have paru; then
    rtk_cmd="paru -S --needed rtk"
  else
    rtk_cmd="curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh"
  fi
  if confirm "Instalar o rtk agora? (${rtk_cmd})"; then
    eval "${rtk_cmd}" || echo "Falhou — veja a mensagem acima." >&2
    # O script oficial instala em ~/.local/bin, que pode não estar no PATH ainda.
    [[ -x "${HOME}/.local/bin/rtk" ]] && export PATH="${HOME}/.local/bin:${PATH}"
  else
    echo "Pulado."
  fi
fi

if have rtk; then
  # "nome|detectado?|flags do rtk init"
  rtk_agents=(
    "Claude Code|$(have claude || [[ -d ${HOME}/.claude ]] && echo y)|-g"
    "Codex|$(have codex || [[ -d ${HOME}/.codex ]] && echo y)|-g --codex"
    "Gemini CLI|$(have gemini || [[ -d ${HOME}/.gemini ]] && echo y)|-g --gemini"
    "OpenCode|$(have opencode || [[ -d ${HOME}/.config/opencode ]] && echo y)|-g --opencode"
    "Cursor|$(have cursor-agent || have cursor || [[ -d ${HOME}/.cursor ]] && echo y)|-g --agent cursor"
    "Windsurf|$(have windsurf || [[ -d ${HOME}/.codeium/windsurf ]] && echo y)|-g --agent windsurf"
    "GitHub Copilot|$(have copilot && echo y)|-g --copilot"
  )
  found=0
  for entry in "${rtk_agents[@]}"; do
    IFS='|' read -r name detected flags <<<"${entry}"
    [[ ${detected} == y ]] || continue
    found=1
    # --codex não aceita --auto-patch (não há settings.json para alterar).
    [[ ${flags} == *--codex* ]] || flags+=" --auto-patch"
    if confirm "Ativar o rtk no ${name}? (rtk init ${flags})"; then
      # shellcheck disable=SC2086
      rtk init ${flags} </dev/tty || echo "Falhou — veja a mensagem acima." >&2
    else
      echo "Pulado. Rode 'rtk init ${flags}' quando quiser."
    fi
  done
  if [[ ${found} -eq 0 ]]; then
    echo "Nenhum agente de código detectado. Depois de instalar um, rode 'rtk init -g' (veja o README)."
  else
    echo "Reinicie os agentes abertos para o hook valer. Confira com 'rtk init --show' e 'rtk gain'."
  fi
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

  agent=$(omarchy default agent 2>/dev/null || true)
  if [[ -z ${agent} ]]; then
    echo "Nenhum agente padrão no Omarchy — o 'Ask AI' precisa de um para responder."
    echo "Escolha em Setup → Default → Agent (Codex ou Claude Code respondem dentro do menu)."
  elif [[ ${agent} != codex && ${agent} != claude ]]; then
    echo "Agente padrão: ${agent}. O 'Ask AI' vai abrir as perguntas no terminal dele;"
    echo "com Codex ou Claude Code a resposta aparece dentro do menu."
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

  if confirm "Instalar o plugin 'Orca' (toolbox.orca, workspaces e agentes do Orca na barra)?"; then
    "${ROOT_DIR}/omarchy/orca/install.sh" || echo "Falhou — veja a mensagem acima." >&2
  else
    echo "Pulado. Rode './omarchy/orca/install.sh' quando quiser."
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
