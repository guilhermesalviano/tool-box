#!/usr/bin/env bash
set -euo pipefail

tool_dir=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
test_dir=$(mktemp -d)
trap 'rm -rf -- "$test_dir"' EXIT
mkdir -p "$test_dir/bin"
export PATH="$test_dir/bin:$PATH" CAPTURE="$test_dir/capture"

cat > "$test_dir/bin/omarchy-shell" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" > "$CAPTURE"
EOF
cat > "$test_dir/bin/omarchy-launch-browser" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" > "$CAPTURE"
EOF
chmod +x "$test_dir/bin/"*

"$tool_dir/run.sh" 'quotes & spaces/日本語' 
expected='https://www.google.com/search?q=quotes%20%26%20spaces%2F%E6%97%A5%E6%9C%AC%E8%AA%9E'
[[ $(cat "$CAPTURE") == "$expected" ]] || { echo 'Positional query was not encoded correctly.' >&2; exit 1; }

"$tool_dir/run.sh"
[[ $(cat "$CAPTURE") == "shell summon toolbox.web-search {}" ]] || { echo 'No-query run did not open the plugin search box.' >&2; exit 1; }

if TOOLBOX_SEARCH_URL='ftp://bad/%s' "$tool_dir/run.sh" query 2>"$test_dir/error"; then
  echo 'Invalid URL scheme unexpectedly succeeded.' >&2
  exit 1
fi

if TOOLBOX_SEARCH_URL='https://example.test/search' "$tool_dir/run.sh" query 2>"$test_dir/error"; then
  echo 'Missing placeholder unexpectedly succeeded.' >&2
  exit 1
fi

omarchy plugin validate "$tool_dir" || { echo 'Plugin manifest is invalid.' >&2; exit 1; }

echo 'PASS: default-browser launch, plugin search box, URL encoding, validation, and plugin manifest.'
