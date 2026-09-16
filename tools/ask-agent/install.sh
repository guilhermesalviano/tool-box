#!/usr/bin/env bash
# Prepare/validate in a temporary directory before touching the live menu.
set -euo pipefail
tool_dir=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
source_dir=${OMARCHY_PATH:-/usr/share/omarchy}/shell/plugins/menu
plugin_id="${USER:-$(id -un)}.menu"
target="$HOME/.config/omarchy/plugins/$plugin_id"

# Validate arguments before doing any work, so a typo cannot run a patch.
check_only=false
case $# in
  0) ;;
  1) [[ $1 == --check ]] || { echo 'Usage: install.sh [--check]' >&2; exit 1; }
     check_only=true ;;
  *) echo 'Usage: install.sh [--check]' >&2; exit 1 ;;
esac

stage=$(mktemp -d)
trap 'rm -rf -- "$stage"' EXIT
cp -a "$source_dir/." "$stage/"
patch --batch --fuzz=0 "$stage/Menu.qml" "$tool_dir/menu.patch"
cp "$tool_dir/AskPane.qml" "$stage/AskPane.qml"

if [[ $check_only == true ]]; then
  echo 'Menu patch applies cleanly to the installed Omarchy version.'
  exit 0
fi

command -v rg >/dev/null || { echo 'ripgrep (rg) is required.' >&2; exit 1; }
rg -q '"toolbox-ask-agent"\s*:' "$HOME/.config/omarchy/extensions/omarchy-menu.jsonc" || {
  echo "Add the toolbox-ask-agent row from $tool_dir/omarchy-menu.jsonc to your menu extension first." >&2
  exit 1
}

stamp=$(date +%Y%m%d-%H%M%S)
backup="$HOME/.local/state/toolbox-ask-agent/$stamp"
mkdir -p "$backup"
cp -a "$HOME/.config/omarchy/shell.json" "$backup/shell.json"
if [[ -e $target ]]; then
  # Never silently replace another customized menu.
  [[ -f $target/.toolbox-ask-agent ]] || {
    echo "An existing custom menu exists at $target. Merge menu.patch manually." >&2
    exit 1
  }
  cp -a "$target" "$backup/plugin"
else
  omarchy plugin clone omarchy.menu
fi
cp "$stage/Menu.qml" "$stage/AskPane.qml" "$target/"
touch "$target/.toolbox-ask-agent"
mkdir -p "$HOME/.local/bin"
launcher="$HOME/.local/bin/toolbox-ask-agent"
[[ ! -e $launcher && ! -L $launcher ]] || cp -a "$launcher" "$backup/launcher"
ln -sfn "$tool_dir/run.sh" "$launcher"
# A plugin rescan can keep the previous QML component cached. Restart the
# shell so the menu actually runs the code just installed.
omarchy restart shell
printf 'Ask AI installed in %s\nBackup: %s\n' "$target" "$backup"
