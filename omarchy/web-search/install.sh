#!/usr/bin/env bash
# Install this folder as the toolbox.web-search Omarchy shell plugin.
set -euo pipefail

tool_dir=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
plugin_id=$(jq -r .id "$tool_dir/manifest.json")
target="$HOME/.config/omarchy/plugins/$plugin_id"
plugin_files=(manifest.json WebSearch.qml run.sh README.md)

check_only=false
case $# in
  0) ;;
  1) [[ $1 == --check ]] || { echo 'Usage: install.sh [--check]' >&2; exit 1; }
     check_only=true ;;
  *) echo 'Usage: install.sh [--check]' >&2; exit 1 ;;
esac

for cmd in jq omarchy omarchy-shell omarchy-launch-browser; do
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

backup="$HOME/.local/state/toolbox-web-search/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$backup"
[[ ! -e $target ]] || cp -a "$target" "$backup/plugin"

# Earlier versions linked a launcher into ~/.local/bin; the plugin replaces it.
legacy_launcher="$HOME/.local/bin/toolbox-web-search"
if [[ -L $legacy_launcher ]]; then
  cp -a "$legacy_launcher" "$backup/launcher"
  rm -- "$legacy_launcher"
fi

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
# The menu shows its Search Web row only while this plugin is installed.
omarchy menu refresh >/dev/null 2>&1 || true
printf 'Search Web installed in %s\nBackup: %s\n' "$target" "$backup"
