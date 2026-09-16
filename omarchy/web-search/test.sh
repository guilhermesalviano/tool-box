#!/usr/bin/env bash
set -euo pipefail

tool_dir=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
test_dir=$(mktemp -d)
trap 'rm -rf -- "$test_dir"' EXIT
mkdir -p "$test_dir/bin"
export PATH="$test_dir/bin:$PATH" CAPTURE="$test_dir/capture"

cat > "$test_dir/bin/omarchy" <<'EOF'
#!/usr/bin/env bash
if [[ $1 == menu && $2 == input ]]; then
  printf '%s\n' 'quotes & spaces/日本語'
else
  printf '%s\n' chromium
fi
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
[[ $(cat "$CAPTURE") == "$expected" ]] || { echo 'Menu query was not encoded correctly.' >&2; exit 1; }

if TOOLBOX_SEARCH_URL='ftp://bad/%s' "$tool_dir/run.sh" query 2>"$test_dir/error"; then
  echo 'Invalid URL scheme unexpectedly succeeded.' >&2
  exit 1
fi

if TOOLBOX_SEARCH_URL='https://example.test/search' "$tool_dir/run.sh" query 2>"$test_dir/error"; then
  echo 'Missing placeholder unexpectedly succeeded.' >&2
  exit 1
fi

echo 'PASS: default-browser launch, menu input, URL encoding, and validation.'
