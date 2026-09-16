#!/usr/bin/env bash
# Print Orca's workspaces and running agents, as the toolbox.orca widget sees them.
set -euo pipefail

tool_dir=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")

case ${1:-status} in
  status)
    "$tool_dir/snapshot.sh" | node -e '
      const Model = require(process.argv[1])
      const model = Model.normalize(JSON.parse(require("fs").readFileSync(0, "utf8")), Date.now())
      console.log(Model.summary(model))
      if (!model.running && model.error) console.log(`  (${model.error})`)
      for (const w of model.workspaces) {
        console.log(`${w.attention ? "!" : w.working ? "*" : "-"} ${w.name}  [${w.repo}]`)
        for (const a of w.agents) console.log(`    ${a.name} · ${a.stateLabel}${a.since ? " · " + a.since : ""}${a.task ? "  " + a.task : ""}`)
      }
    ' "$tool_dir/Model.js" ;;
  json) "$tool_dir/snapshot.sh" ;;
  focus) shift; "$tool_dir/focus.sh" "${1:-}" ;;
  -h|--help|help)
    cat <<'USAGE'
Usage: toolbox orca [status|json|focus [terminal-handle]]

  status   Workspaces and running agents (default)
  json     The raw snapshot the bar widget reads
  focus    Bring Orca to the front, on a terminal when a handle is given
USAGE
    ;;
  *) echo "Unknown command: $1 (try: toolbox orca help)" >&2; exit 2 ;;
esac
