#!/usr/bin/env bash
set -euo pipefail
tool_dir=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")

node "$tool_dir/test_model.js"
TOOLBOX_ORCA_CLI=/nonexistent "$tool_dir/snapshot.sh" | jq -e '.running == false' > /dev/null \
  || { echo 'FAIL: snapshot.sh should report Orca as not running' >&2; exit 1; }
"$tool_dir/install.sh" --check > /dev/null || { echo 'FAIL: plugin is invalid' >&2; exit 1; }
echo 'PASS: workspace/agent model, closed-Orca snapshot, plugin manifest.'
