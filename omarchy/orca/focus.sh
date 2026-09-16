#!/usr/bin/env bash
# Bring Orca to the front, on the given terminal when a handle is passed.
#   focus.sh [terminal-handle]
set -uo pipefail

cli=${TOOLBOX_ORCA_CLI:-$HOME/.config/orca/linux-orca-cli-shim/orca}

if [[ -n ${1:-} && -x $cli ]]; then
  "$cli" terminal switch --terminal "$1" >/dev/null 2>&1 || true
fi
hyprctl dispatch focuswindow 'class:^(orca)$' >/dev/null 2>&1 || true
