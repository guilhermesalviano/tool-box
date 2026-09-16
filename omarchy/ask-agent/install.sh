#!/usr/bin/env bash
# Install this folder as the toolbox.ask-agent Omarchy shell plugin: a menu
# that replaces omarchy.menu, adding inline Ask AI answers, a working Apps list,
# and the Search Web rows.
set -euo pipefail

tool_dir=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
plugins_dir="$HOME/.config/omarchy/plugins"
plugin_id=$(jq -r .id "$tool_dir/manifest.json")
target="$plugins_dir/$plugin_id"
plugin_files=(manifest.json Menu.qml MenuModel.js BarWidget.qml AskPane.qml menu.jsonc answer.sh run.sh README.md)

check_only=false
case $# in
  0) ;;
  1) [[ $1 == --check ]] || { echo 'Usage: install.sh [--check]' >&2; exit 1; }
     check_only=true ;;
  *) echo 'Usage: install.sh [--check]' >&2; exit 1 ;;
esac

for cmd in jq omarchy omarchy-shell; do
  command -v "$cmd" >/dev/null || { echo "$cmd is required." >&2; exit 1; }
done

# Stage exactly the files the plugin needs, then validate before touching anything.
stage=$(mktemp -d)
trap 'rm -rf -- "$stage"' EXIT
for file in "${plugin_files[@]}"; do cp "$tool_dir/$file" "$stage/"; done
omarchy plugin validate "$stage"

if [[ $check_only == true ]]; then
  echo "$plugin_id is a valid Omarchy plugin."
  exit 0
fi

backup="$HOME/.local/state/toolbox-ask-agent/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$backup"
cp -a "$HOME/.config/omarchy/shell.json" "$backup/shell.json" 2>/dev/null || true
[[ ! -e $target ]] || cp -a "$target" "$backup/plugin"

# Earlier versions patched a `<username>.menu` clone, linked a launcher into
# ~/.local/bin, and symlinked the user's menu extension into this repo. The
# plugin now carries all of that itself, so retire those pieces.
for legacy in "$plugins_dir"/*.menu; do
  [[ -f $legacy/.toolbox-ask-agent ]] || continue
  legacy_id=$(basename "$legacy")
  omarchy plugin disable "$legacy_id" >/dev/null || true
  mv -- "$legacy" "$backup/legacy-$legacy_id"
done
legacy_launcher="$HOME/.local/bin/toolbox-ask-agent"
if [[ -L $legacy_launcher ]]; then
  cp -a "$legacy_launcher" "$backup/launcher"
  rm -- "$legacy_launcher"
fi
menu_ext="$HOME/.config/omarchy/extensions/omarchy-menu.jsonc"
if [[ -L $menu_ext && $(readlink "$menu_ext") == */ask-agent/omarchy-menu.jsonc ]]; then
  cp -a "$menu_ext" "$backup/omarchy-menu.jsonc.link"
  rm -- "$menu_ext"
  template="${OMARCHY_PATH:-/usr/share/omarchy}/config/omarchy/extensions/omarchy-menu.jsonc"
  [[ ! -f $template ]] || cp "$template" "$menu_ext"
fi

mkdir -p "$plugins_dir"
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
# The menu is keepLoaded, so a rescan keeps the previous QML component.
# Restart the shell so the menu actually runs the code just installed.
omarchy restart shell
printf 'Ask AI installed in %s\nBackup: %s\n' "$target" "$backup"
