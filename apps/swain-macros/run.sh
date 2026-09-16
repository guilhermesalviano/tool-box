#!/usr/bin/env bash
#
# run.sh - Abre o Swain Macros (app GTK para macros nos botões laterais do
#          mouse Redragon Swain). Use `install.sh` uma vez antes.
#

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "${1:-}" == "install" ]]; then
  shift
  exec "${DIR}/install.sh" "$@"
fi

exec "${DIR}/swain-macros" "$@"
