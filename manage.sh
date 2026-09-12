#!/usr/bin/env bash
#
# manage.sh - Atalho de conveniência para gerenciar o mac-monitor
#

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${DIR}/toolbox" mac-monitor "$@"
