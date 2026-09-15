#!/usr/bin/env bash
set -euo pipefail
tool_dir=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
test_dir=$(mktemp -d)
trap 'rm -rf -- "$test_dir"' EXIT
mkdir -p "$test_dir/bin" "$test_dir/tmp" "$test_dir/work"
export TMPDIR="$test_dir/tmp" TOOLBOX_AGENT_WORKDIR="$test_dir/work"
export TEST_CAPTURE="$test_dir/prompt" TEST_ARGS="$test_dir/args"
export PATH="$test_dir/bin:$PATH"
cat > "$test_dir/bin/omarchy" <<'EOF'
#!/bin/bash
printf '%s\n' "${TEST_AGENT:-codex}"
EOF
cat > "$test_dir/bin/mise" <<'EOF'
#!/bin/bash
command -v fake-codex
EOF
cat > "$test_dir/bin/fake-codex" <<'EOF'
#!/bin/bash
printf '%s\n' "$@" > "$TEST_ARGS"
while (( $# )); do
  if [[ $1 == --output-last-message ]]; then output=$2; shift; fi
  shift
done
cat > "$TEST_CAPTURE"
case ${TEST_MODE:-success} in
  failure) echo 'fixture connection error' >&2; exit 1 ;;
  empty) exit 0 ;;
  slow) sleep 30 ;;
  *) printf 'Answer with punctuation: $HOME; `echo unsafe`\nSecond line\n' > "$output" ;;
esac
EOF
chmod +x "$test_dir/bin/"*
fail() { echo "FAIL: $*" >&2; exit 1; }
question='--inline $(touch /tmp/should-not-exist) "quoted"; 日本語'
"$tool_dir/run.sh" --headless "$question" > "$test_dir/answer"
[[ $(tail -n 1 "$TEST_CAPTURE") == "$question" ]] || fail 'Question was changed'
[[ $(head -n 1 "$test_dir/answer") == 'Answer with punctuation: $HOME; `echo unsafe`' ]] || fail 'Answer was changed'
rg -q -- '--sandbox' "$TEST_ARGS" || fail 'Sandbox missing'
rg -q '^read-only$' "$TEST_ARGS" || fail 'Read-only missing'
[[ -z $(ls -A "$TMPDIR") ]] || fail 'Temporary files leaked'
"$tool_dir/run.sh" --headless '   ' > "$test_dir/blank"
[[ ! -s $test_dir/blank ]] || fail 'Blank question returned text'
for mode in failure empty; do
  if TEST_MODE=$mode "$tool_dir/answer.sh" question > "$test_dir/out" 2> "$test_dir/error"; then fail "$mode succeeded"; fi
  [[ ! -s $test_dir/out && -s $test_dir/error ]] || fail "$mode output contract"
done
if TEST_AGENT=claude "$tool_dir/answer.sh" question 2> "$test_dir/error"; then fail 'Unsupported agent succeeded'; fi
rg -q 'currently support Codex' "$test_dir/error" || fail 'Unsupported agent message'
if TEST_MODE=slow TOOLBOX_AGENT_TIMEOUT=1 "$tool_dir/answer.sh" question 2> "$test_dir/error"; then fail 'Timeout succeeded'; fi
rg -q 'timed out' "$test_dir/error" || fail 'Timeout message'
TEST_MODE=slow "$tool_dir/answer.sh" question > "$test_dir/out" 2> "$test_dir/error" &
request_pid=$!
sleep 0.2
kill -TERM "$request_pid"
status=0
wait "$request_pid" || status=$?
[[ $status == 143 ]] || fail 'Cancellation exit code'
[[ -z $(ls -A "$TMPDIR") ]] || fail 'Temporary files leaked after cancellation'
"$tool_dir/install.sh" --check
echo 'PASS: literal prompts, answer output, blank input, errors, unsupported agent, timeout, cancellation, cleanup, menu compatibility.'
