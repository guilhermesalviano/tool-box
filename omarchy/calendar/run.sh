#!/usr/bin/env bash
# Manage the private iCal addresses the toolbox.calendar plugin reads.
set -euo pipefail

tool_dir=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
config=${TOOLBOX_CALENDAR_CONFIG:-$HOME/.config/toolbox-calendar/calendars.conf}
events=${TOOLBOX_CALENDAR_STATE:-$HOME/.local/state/toolbox-calendar}/events.json

usage() {
  cat <<'USAGE'
Usage: toolbox calendar <command>

  add [name]     Add a calendar. Asks for its private iCal address without
                 echoing it (Google Calendar → Settings → your calendar →
                 Integrate calendar → Secret address in iCal format).
  list           Show configured calendars, with addresses masked.
  remove <name|number>
                 Remove a calendar.
  sync           Download events now.
  status         Show the last sync time, event count and any errors.

Addresses are stored in ~/.config/toolbox-calendar/calendars.conf (mode 600).
Anyone with an address can read that calendar; reset it in Google Calendar to
revoke it.
USAGE
}

ensure_config() {
  mkdir -p "$(dirname "$config")"
  chmod 700 "$(dirname "$config")"
  [[ -f $config ]] || : > "$config"
  chmod 600 "$config"
}

# Poke the running widget so the bar updates now rather than on its next timer.
refresh_widget() {
  omarchy-shell omarchy.clock sync >/dev/null 2>&1 || true
}

cmd_add() {
  local name=${*:-} url
  if [[ -z $name ]]; then
    read -rp 'Name for this calendar (e.g. Personal): ' name
  fi
  [[ $name != *=* && $name != *$'\n'* ]] || { echo 'The name cannot contain "=".' >&2; exit 2; }
  read -rsp 'Private iCal address (hidden): ' url
  echo
  url=${url//[[:space:]]/}
  [[ $url == https://* ]] || { echo 'The address must start with https://' >&2; exit 2; }

  # Check the address before saving it. The URL goes through stdin, never argv,
  # so it does not show up in the process list.
  echo 'Checking the address…'
  if ! printf '%s' "$url" | python3 -c '
import sys
sys.path.insert(0, sys.argv[1])
import sync
try:
    text = sync.fetch(sys.stdin.read())
except Exception as error:
    print("Could not read that calendar:", sync.describe_error(error), file=sys.stderr)
    sys.exit(1)
_, events = sync.parse_components(text)
print(f"OK: {len(events)} events in the feed")
' "$tool_dir"; then
    exit 1
  fi

  ensure_config
  if [[ -n $name ]]; then
    printf '%s = %s\n' "$name" "$url" >> "$config"
  else
    printf '%s\n' "$url" >> "$config"
  fi
  echo "Saved to $config"
  cmd_sync
}

cmd_list() {
  [[ -s $config ]] || { echo 'No calendars yet. Add one with: toolbox calendar add'; return; }
  python3 - "$tool_dir" "$config" <<'PY'
import sys
from pathlib import Path
sys.path.insert(0, sys.argv[1])
import sync
for index, entry in enumerate(sync.read_calendars(Path(sys.argv[2])), 1):
    print(f"{index}. {entry['name'] or '(name from feed)'}  {sync.mask_url(entry['url'])}")
PY
}

cmd_remove() {
  local target=${1:-}
  [[ -n $target ]] || { echo 'Usage: toolbox calendar remove <name|number>' >&2; exit 2; }
  [[ -s $config ]] || { echo 'No calendars configured.' >&2; exit 1; }
  python3 - "$tool_dir" "$config" "$target" <<'PY'
import os, sys, tempfile
from pathlib import Path
sys.path.insert(0, sys.argv[1])
import sync
path, target = Path(sys.argv[2]), sys.argv[3]
lines = path.read_text(encoding="utf-8").splitlines(keepends=True)
entry_lines = [i for i, line in enumerate(lines) if line.strip() and not line.strip().startswith("#")]
calendars = sync.read_calendars(path)
matches = [n for n, c in enumerate(calendars) if c["name"].lower() == target.lower() or str(n + 1) == target]
if len(matches) != 1:
    sys.exit(f"No single calendar matches {target!r}. See: toolbox calendar list")
removed = calendars[matches[0]]
del lines[entry_lines[matches[0]]]
fd, tmp = tempfile.mkstemp(dir=path.parent)
with os.fdopen(fd, "w", encoding="utf-8") as handle:
    handle.writelines(lines)
os.chmod(tmp, 0o600)
os.replace(tmp, path)
print(f"Removed {removed['name'] or sync.mask_url(removed['url'])}")
PY
  cmd_sync
}

cmd_sync() {
  python3 "$tool_dir/sync.py" || true
  refresh_widget
}

cmd_status() {
  [[ -f $events ]] || { echo 'Not synced yet. Run: toolbox calendar sync'; return; }
  jq -r '
    "Last sync: \(.syncedAt)",
    "Calendars: \(.calendars)",
    "Events:    \(.events | length)",
    (.errors[] | "Error:     \(.calendar): \(.message)")
  ' "$events"
}

case ${1:-} in
  add) shift; cmd_add "$@" ;;
  list) cmd_list ;;
  remove) shift; cmd_remove "$@" ;;
  sync) cmd_sync ;;
  status) cmd_status ;;
  -h|--help|help|'') usage ;;
  *) echo "Unknown command: $1" >&2; usage >&2; exit 2 ;;
esac
