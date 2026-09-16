#!/usr/bin/env bash
set -euo pipefail

tool_dir=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
case ${1:-} in
  --help|-h)
    echo 'Usage: toolbox ask-agent [question...]'
    echo 'Show Ask AI inside Omarchy search (requires ./omarchy/ask-agent/install.sh).'
    echo '  --headless question...  Print an answer without opening a window.'
    exit 0 ;;
  --headless)
    shift
    exec "$tool_dir/answer.sh" "$@" ;;
esac

payload=$(jq -nc --arg question "$*" '{mode:"ask", question:$question}')
exec omarchy-shell shell summon omarchy.menu "$payload"
