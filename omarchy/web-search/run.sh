#!/usr/bin/env bash
set -euo pipefail

if [[ ${1:-} == --help || ${1:-} == -h ]]; then
  cat <<'USAGE'
Usage: toolbox web-search [query...]

Search the internet in Omarchy's default browser. With no query, opens the
toolbox.web-search plugin's search box (install it with install.sh).
Set TOOLBOX_SEARCH_URL to a URL template with a literal %s placeholder to
choose a different search engine.
USAGE
  exit 0
fi

search_url=${TOOLBOX_SEARCH_URL:-https://www.google.com/search?q=%s}
[[ $search_url == *%s* ]] || {
  echo 'TOOLBOX_SEARCH_URL must contain a literal %s placeholder.' >&2
  exit 2
}
[[ $search_url == http://* || $search_url == https://* ]] || {
  echo 'TOOLBOX_SEARCH_URL must begin with http:// or https://.' >&2
  exit 2
}

# Without a query, open the plugin's search box; it calls back with the query.
(( $# )) || exec omarchy-shell shell summon toolbox.web-search '{}'
query="$*"
[[ -n ${query//[[:space:]]/} ]] || exit 0

encoded=$(printf '%s' "$query" | jq -sRr @uri)
url=${search_url//%s/$encoded}
exec omarchy-launch-browser "$url"
