#!/usr/bin/env bash
# Print one JSON object with Orca's workspaces (with their agents) and live
# terminals, for the toolbox.orca bar widget:
#   {"running": true, "worktrees": [...], "terminals": [...]}
# When Orca is closed, or its CLI fails, prints {"running": false, "error": "..."}
# and still exits 0, so the widget can tell "closed" from "broken".
set -uo pipefail

cli=${TOOLBOX_ORCA_CLI:-$HOME/.config/orca/linux-orca-cli-shim/orca}

closed() {
  jq -cn --arg error "$1" '{running: false, error: $error}'
  exit 0
}

command -v jq >/dev/null || { echo '{"running":false,"error":"jq is required"}'; exit 0; }
[[ -x $cli ]] || closed "Orca CLI not found at $cli (open Orca once to register it)"

# The shim refuses to run once the Orca process it was written for is gone.
ps_json=$("$cli" worktree ps --json 2>&1) || closed "$(printf '%s' "$ps_json" | head -n 1)"
terminals_json=$("$cli" terminal list --json 2>/dev/null) || terminals_json='{}'

jq -cn --argjson ps "$ps_json" --argjson terminals "$terminals_json" '
  if $ps.ok != true then
    {running: false, error: ($ps.error.message // "Orca did not answer")}
  else
    {
      running: true,
      worktrees: ($ps.result.worktrees // []),
      terminals: ($terminals.result.terminals // [])
    }
  end
' 2>/dev/null || closed 'Could not read Orca output'
