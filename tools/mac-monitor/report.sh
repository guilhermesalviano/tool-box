#!/usr/bin/env bash
#
# report.sh - Gera o relatório de uso da máquina a partir dos logs diários do Glances
#
# Uso:
#   ./tools/mac-monitor/report.sh              # Gera o relatório de hoje
#   ./tools/mac-monitor/report.sh YYYY-MM-DD   # Gera o relatório de uma data específica
#   ./tools/mac-monitor/report.sh /path/to.csv # Gera o relatório de um arquivo CSV específico

set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOGS_DIR="${DIR}/logs"

TARGET_INPUT="${1:-$(date +%Y-%m-%d)}"

if [[ -f "${TARGET_INPUT}" ]]; then
  CSV_FILE="${TARGET_INPUT}"
elif [[ -f "${LOGS_DIR}/glances-${TARGET_INPUT}.csv" ]]; then
  CSV_FILE="${LOGS_DIR}/glances-${TARGET_INPUT}.csv"
else
  CSV_FILE="${LOGS_DIR}/glances-${TARGET_INPUT}.csv"
fi

if [[ ! -f "${CSV_FILE}" ]]; then
  echo "Erro: Arquivo de log não encontrado: ${CSV_FILE}" >&2
  echo "Certifique-se de que o monitor está ativo." >&2
  exit 1
fi

TOTAL_LINES=$(wc -l < "${CSV_FILE}" | tr -d ' ')
if [[ "${TOTAL_LINES}" -le 1 ]]; then
  echo "Aviso: O arquivo '${CSV_FILE}' não possui amostras coletadas ainda."
  exit 0
fi

awk -F, '           
NR==1 {next}
{
  cpu+=$3; mem+=$5; n++
  if($3>maxcpu) maxcpu=$3
  if($5>maxmem) maxmem=$5
}
END {
  if (n == 0) {
    print "Nenhuma amostra encontrada."
    exit
  }
  print "=== Relatório do dia ==="
  print "Amostras:", n
  printf "CPU média: %.2f%%\n", cpu/n
  printf "CPU máxima: %.2f%%\n", maxcpu
  printf "Memória média: %.2f%%\n", mem/n
  printf "Memória máxima: %.2f%%\n", maxmem
}' "${CSV_FILE}"
