#!/usr/bin/env sh
#
# aliases.sh - Atalhos de shell para o Tool-Box.
#
# Não execute este arquivo diretamente: ele é feito para ser "sourced"
# (bash ou zsh). Use "./toolbox aliases install" para configurar isso
# automaticamente no seu ~/.zshrc / ~/.bashrc.
#
# Este arquivo se autolocaliza, então funciona não importa onde o
# repositório tool-box esteja clonado.
#

# A sintaxe de autolocalização do zsh ("${(%):-%x}") não é válida em bash,
# então ela fica dentro de um "eval" com aspas simples — assim o bash nunca
# chega a interpretar essa sintaxe, mesmo estando nesse arquivo. Usamos "%x"
# (não "%N") porque "%N" reporta o nome pseudo-arquivo do próprio "eval"
# quando usado dentro dele, enquanto "%x" segue até o arquivo de origem real.
if [ -n "${ZSH_VERSION:-}" ]; then
  _tb_aliases_self="$(eval 'print -r -- ${(%):-%x}')"
elif [ -n "${BASH_SOURCE:-}" ]; then
  _tb_aliases_self="${BASH_SOURCE:-$0}"
else
  _tb_aliases_self="$0"
fi

_tb_root="$(cd "$(dirname "${_tb_aliases_self}")/../.." && pwd)"

# --- Geral ---------------------------------------------------------------
alias tb="${_tb_root}/toolbox"
alias tbl="tb list"
alias tbn="tb new"

# --- Disk Cleaner ----------------------------------------------------------
alias tb-clean="tb disk-cleaner"
alias tb-clean-all="tb disk-cleaner --yes"
alias tb-clean-dry="tb disk-cleaner --dry-run"

# --- Torrent DL ------------------------------------------------------------
alias tb-torrent="tb torrent-dl"
alias tb-dl="tb torrent-dl"

# --- Mac Monitor -----------------------------------------------------------
alias tb-mon="tb mac-monitor"
alias tb-mon-status="tb mac-monitor status"
alias tb-mon-report="tb mac-monitor report"
alias tb-mon-logs="tb mac-monitor logs -f"
alias tb-mon-start="tb mac-monitor start"
alias tb-mon-stop="tb mac-monitor stop"
alias tb-mon-restart="tb mac-monitor restart"

unset _tb_aliases_self _tb_root
