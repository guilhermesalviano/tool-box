#!/usr/bin/env bash
# Print the CPU temperature sensors, as the toolbox.cpu-temp widget sees them.
set -euo pipefail

tool_dir=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")

case ${1:-status} in
  status)
    "$tool_dir/sensors.sh" | node -e '
      const Model = require(process.argv[1])
      const model = Model.normalize(JSON.parse(require("fs").readFileSync(0, "utf8")))
      console.log(Model.summary(model))
      if (!model.available) process.exit(1)
      console.log(`  ${model.primary.label}  ${Model.degrees(model.primary.celsius)}  [${model.source}]`)
      for (const s of model.others) console.log(`  ${s.label}  ${Model.degrees(s.celsius)}`)
    ' "$tool_dir/Model.js" ;;
  json) "$tool_dir/sensors.sh" ;;
  -h|--help|help)
    cat <<'USAGE'
Usage: toolbox cpu-temp [status|json]

  status   CPU package and per-core temperatures (default)
  json     The raw sensor list the bar widget reads
USAGE
    ;;
  *) echo "Unknown command: $1 (try: toolbox cpu-temp help)" >&2; exit 2 ;;
esac
