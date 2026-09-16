#!/usr/bin/env bash
set -euo pipefail
tool_dir=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")

python3 -m unittest -q "$tool_dir/test_sync.py" 2>&1 | tail -n 1
TZ=America/Sao_Paulo node "$tool_dir/test_events.js"
"$tool_dir/install.sh" --check > /dev/null || { echo 'FAIL: plugin is invalid' >&2; exit 1; }
echo 'PASS: iCal parsing and recurrence, event math, plugin manifest.'
