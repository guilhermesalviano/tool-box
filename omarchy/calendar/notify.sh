#!/usr/bin/env bash
# Announce one calendar event: notify.sh <key> <title> <body> <url>
# Several bars (one per monitor) ask at the same minute, and the shell may
# restart; the stamp directory makes sure each occurrence is announced once.
set -euo pipefail

key=$1 title=$2 body=$3 url=$4
stamps="$HOME/.local/state/toolbox-calendar/notified"
mkdir -p "$stamps"
[[ $key =~ ^[A-Za-z0-9@._-]+$ ]] || exit 1
mkdir "$stamps/$key" 2>/dev/null || exit 0
find "$stamps" -mindepth 1 -maxdepth 1 -type d -mtime +2 -exec rm -rf -- {} + 2>/dev/null || true

# A title starting with "-" would be read as an option; a zero-width space keeps it text.
[[ $title != -* ]] || title=$'\u200b'"$title"
args=("$title" "$body" -g 󰃭 -u normal --app-name Calendar)
[[ $url != https://* ]] || args+=(--exec omarchy-launch-browser "$url")
exec omarchy notification send "${args[@]}"
