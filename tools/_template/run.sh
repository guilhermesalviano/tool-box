#!/usr/bin/env bash
#
# run.sh - Ponto de entrada do script/ferramenta
#

set -e

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${TOOL_DIR}/../.." && pwd)"

echo "Executando ferramenta a partir de ${TOOL_DIR}..."
echo "Diretório raiz da toolbox: ${ROOT_DIR}"

# Escreva a lógica do seu script aqui.
# Você pode usar Python do ambiente virtual da toolbox:
# "${ROOT_DIR}/.venv/bin/python3" script.py "$@"
