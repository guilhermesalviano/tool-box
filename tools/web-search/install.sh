#!/usr/bin/env bash
set -euo pipefail

tool_dir=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
launcher="$HOME/.local/bin/toolbox-web-search"
menu_file="$HOME/.config/omarchy/extensions/omarchy-menu.jsonc"

check_prerequisites() {
  [[ -x "$tool_dir/run.sh" ]] || { echo 'run.sh is not executable.' >&2; exit 1; }
  command -v jq >/dev/null || { echo 'jq is required.' >&2; exit 1; }
  command -v rg >/dev/null || { echo 'ripgrep (rg) is required.' >&2; exit 1; }
  command -v omarchy-launch-browser >/dev/null || { echo 'Omarchy browser launcher is unavailable.' >&2; exit 1; }
}

if [[ ${1:-} == --check ]]; then
  check_prerequisites
  echo 'Web Search prerequisites are available.'
  exit 0
fi
[[ $# == 0 ]] || { echo 'Usage: install.sh [--check]' >&2; exit 1; }

check_prerequisites
mkdir -p "$HOME/.local/bin"
ln -sfn "$tool_dir/run.sh" "$launcher"

shared_jsonc="$tool_dir/../ask-agent/omarchy-menu.jsonc"
if [[ -L "$menu_file" && "$(readlink -f "$menu_file")" == "$(readlink -f "$shared_jsonc")" ]]; then
  echo 'The shared Tool-Box menu file already owns Search Web; refresh it with: omarchy menu refresh'
elif [[ -f "$menu_file" ]] && rg -q '"toolbox-web-search"\s*:' "$menu_file"; then
  echo 'Search Web is already present in the Omarchy menu.'
else
  echo "Add this row to $menu_file, then run: omarchy menu refresh"
  printf '%s\n' '  "toolbox-web-search": {"icon":"󰖟","label":"Search Web","description":"Search the internet in your default browser","aliases":["web","internet"],"action":"\"$HOME/.local/bin/toolbox-web-search\""},'
fi
echo "Installed $launcher"
