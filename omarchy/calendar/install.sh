#!/usr/bin/env bash
# Install this folder as the toolbox.calendar Omarchy shell plugin. It takes
# the place of Omarchy's clock in the bar, keeping the clock's settings.
set -euo pipefail

tool_dir=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
plugin_id=$(jq -r .id "$tool_dir/manifest.json")
target="$HOME/.config/omarchy/plugins/$plugin_id"
plugin_files=(manifest.json BarWidget.qml Panel.qml Model.js Events.js sync.py notify.sh README.md)

check_only=false
case $# in
  0) ;;
  1) [[ $1 == --check ]] || { echo 'Usage: install.sh [--check]' >&2; exit 1; }
     check_only=true ;;
  *) echo 'Usage: install.sh [--check]' >&2; exit 1 ;;
esac

for cmd in jq python3 omarchy omarchy-shell omarchy-launch-browser; do
  command -v "$cmd" >/dev/null || { echo "$cmd is required." >&2; exit 1; }
done

# Stage exactly the files the plugin needs, then validate before touching anything.
stage=$(mktemp -d)
trap 'rm -rf -- "$stage"' EXIT
for file in "${plugin_files[@]}"; do cp "$tool_dir/$file" "$stage/"; done
omarchy plugin validate "$stage"

if [[ $check_only == true ]]; then
  echo "$plugin_id is a valid Omarchy plugin and its prerequisites are available."
  exit 0
fi

backup="$HOME/.local/state/toolbox-calendar/backups/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$backup"
cp -a "$HOME/.config/omarchy/shell.json" "$backup/shell.json" 2>/dev/null || true
[[ ! -e $target ]] || cp -a "$target" "$backup/plugin"

mkdir -p "$(dirname "$target")"
rm -rf -- "$target"
cp -a "$stage" "$target"
chmod 755 "$target"

omarchy-shell shell rescanPlugins >/dev/null
# The rescan finishes asynchronously; wait until the shell knows the plugin.
for _ in {1..50}; do
  omarchy-shell shell listPlugins | jq -e --arg id "$plugin_id" 'any(.[]; .id == $id)' >/dev/null && break
  sleep 0.1
done
omarchy plugin enable "$plugin_id"
# A plugin reload can keep the previously compiled QML. Restart the shell so
# the bar actually runs the code just installed.
omarchy restart shell
printf 'Calendar installed in %s\nBackup: %s\n' "$target" "$backup"
[[ -s $HOME/.config/toolbox-calendar/calendars.conf ]] \
  || echo 'Next: add your Google Calendar with  ./toolbox calendar add'
