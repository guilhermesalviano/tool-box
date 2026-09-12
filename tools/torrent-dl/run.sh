#!/usr/bin/env bash
#
# run.sh - Baixa um torrent a partir de um link magnet ou de uma URL/caminho
#          de arquivo .torrent, usando o aria2c.
#

set -euo pipefail

OUTPUT_DIR="${HOME}/Downloads/torrents"
SEED_MINUTES="0"
LINK=""

usage() {
  cat <<EOF
Uso: ./toolbox torrent-dl <link> [opções]
     ./tools/torrent-dl/run.sh <link> [opções]

Baixa um torrent a partir de:
  - um link magnet ("magnet:?xt=...")
  - uma URL para um arquivo .torrent (http/https)
  - o caminho de um arquivo .torrent local

Opções:
  -o, --output <dir>       Diretório de destino (padrão: ${OUTPUT_DIR})
  -s, --seed-minutes <N>   Minutos de seed após o download terminar
                             (padrão: 0 = para de compartilhar assim que terminar)
  -h, --help               Exibe esta mensagem de ajuda

Exemplos:
  ./toolbox torrent-dl 'magnet:?xt=urn:btih:...'
  ./toolbox torrent-dl 'https://exemplo.com/arquivo.torrent' -o ~/Downloads
  ./toolbox torrent-dl ./arquivo.torrent -s 30

Use apenas para conteúdo que você tem o direito de baixar/distribuir.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -o|--output)
      [[ $# -ge 2 ]] || { echo "Erro: '$1' precisa de um valor." >&2; exit 1; }
      OUTPUT_DIR="$2"
      shift 2
      ;;
    -s|--seed-minutes)
      [[ $# -ge 2 ]] || { echo "Erro: '$1' precisa de um valor." >&2; exit 1; }
      SEED_MINUTES="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      echo "Erro: opção desconhecida '$1'" >&2
      usage
      exit 1
      ;;
    *)
      if [[ -n "${LINK}" ]]; then
        echo "Erro: apenas um link é aceito por execução." >&2
        exit 1
      fi
      LINK="$1"
      shift
      ;;
  esac
done

if [[ -z "${LINK}" ]]; then
  echo "Erro: informe um link magnet, uma URL de .torrent ou um arquivo .torrent local." >&2
  usage
  exit 1
fi

if ! command -v aria2c >/dev/null 2>&1; then
  echo "Erro: 'aria2c' não encontrado no PATH." >&2
  case "$(uname -s)" in
    Darwin) echo "Instale com: brew install aria2" >&2 ;;
    Linux)  echo "Instale com: sudo apt-get install aria2   (ou dnf/yum/pacman conforme sua distro)" >&2 ;;
    *)      echo "Instale o aria2 para seu sistema e tente novamente." >&2 ;;
  esac
  exit 1
fi

if [[ "${LINK}" != magnet:* && "${LINK}" != http://* && "${LINK}" != https://* && ! -f "${LINK}" ]]; then
  echo "Aviso: '${LINK}' não parece ser um link magnet, uma URL ou um arquivo existente." >&2
  echo "Tentando mesmo assim..." >&2
fi

mkdir -p "${OUTPUT_DIR}"

echo "Diretório de destino: ${OUTPUT_DIR}"
echo "Link: ${LINK}"
echo ""

exec aria2c \
  --dir="${OUTPUT_DIR}" \
  --seed-time="${SEED_MINUTES}" \
  --enable-dht=true \
  --enable-dht6=true \
  --bt-enable-lpd=true \
  --follow-torrent=mem \
  --continue=true \
  --summary-interval=5 \
  "${LINK}"
