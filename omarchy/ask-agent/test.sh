#!/usr/bin/env bash
set -euo pipefail
tool_dir=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
test_dir=$(mktemp -d)
trap 'rm -rf -- "$test_dir"' EXIT
mkdir -p "$test_dir/bin" "$test_dir/tmp" "$test_dir/work"
export TMPDIR="$test_dir/tmp" TOOLBOX_AGENT_WORKDIR="$test_dir/work"
export TEST_CAPTURE="$test_dir/prompt" TEST_ARGS="$test_dir/args" TEST_CWD="$test_dir/cwd"
real_path=$PATH
export PATH="$test_dir/bin:$PATH"

# `omarchy default agent` answers with $TEST_AGENT; an empty value means unset.
cat > "$test_dir/bin/omarchy" <<'EOF'
#!/bin/bash
[[ -z ${TEST_AGENT-codex} ]] || printf '%s\n' "${TEST_AGENT-codex}"
EOF
# `mise which <agent>` resolves to the matching fake agent.
cat > "$test_dir/bin/mise" <<'EOF'
#!/bin/bash
command -v "fake-$2"
EOF
# Both fakes record their arguments, working directory and prompt, then answer
# according to $TEST_MODE. Codex writes its answer to a file; Claude to stdout.
for agent in codex claude; do
  cat > "$test_dir/bin/fake-$agent" <<EOF
#!/bin/bash
agent=$agent
EOF
  cat >> "$test_dir/bin/fake-$agent" <<'EOF'
printf '%s\n' "$@" > "$TEST_ARGS"
pwd > "$TEST_CWD"
output=''
while (( $# )); do
  if [[ $1 == --output-last-message ]]; then output=$2; shift; fi
  shift
done
cat > "$TEST_CAPTURE"
reply() { if [[ $agent == codex ]]; then cat > "$output"; else cat; fi; }
case ${TEST_MODE:-success} in
  failure) echo 'fixture connection error' >&2; exit 1 ;;
  empty) printf '  \n' | reply ;;
  slow) exec -a toolbox-ask-test-sleeper sleep 30 ;;
  *) printf 'Answer with punctuation: $HOME; `echo unsafe`\nSecond line\n' | reply ;;
esac
EOF
done
chmod +x "$test_dir/bin/"*
fail() { echo "FAIL: $*" >&2; exit 1; }
question='--inline $(touch /tmp/should-not-exist) "quoted"; 日本語'

for agent in codex claude; do
  export TEST_AGENT=$agent
  "$tool_dir/run.sh" --headless "$question" > "$test_dir/answer"
  [[ $(tail -n 1 "$TEST_CAPTURE") == "$question" ]] || fail "$agent: question was changed"
  [[ $(head -n 1 "$test_dir/answer") == 'Answer with punctuation: $HOME; `echo unsafe`' ]] || fail "$agent: answer was changed"
  [[ $(cat "$TEST_CWD") == "$TOOLBOX_AGENT_WORKDIR" ]] || fail "$agent: not run in the workspace"
  [[ -z $(ls -A "$TMPDIR") ]] || fail "$agent: temporary files leaked"
  "$tool_dir/run.sh" --headless '   ' > "$test_dir/blank"
  [[ ! -s $test_dir/blank ]] || fail "$agent: blank question returned text"
  for mode in failure empty; do
    if TEST_MODE=$mode "$tool_dir/answer.sh" question > "$test_dir/out" 2> "$test_dir/error"; then fail "$agent: $mode succeeded"; fi
    [[ ! -s $test_dir/out && -s $test_dir/error ]] || fail "$agent: $mode output contract"
  done
  if TEST_MODE=slow TOOLBOX_AGENT_TIMEOUT=1 "$tool_dir/answer.sh" question 2> "$test_dir/error"; then fail "$agent: timeout succeeded"; fi
  rg -q 'timed out' "$test_dir/error" || fail "$agent: timeout message"

  # Cancelling the request must stop the agent itself, not only this script.
  TEST_MODE=slow "$tool_dir/answer.sh" question > "$test_dir/out" 2> "$test_dir/error" &
  request_pid=$!
  sleep 0.3
  kill -TERM "$request_pid"
  status=0
  wait "$request_pid" || status=$?
  [[ $status == 143 ]] || fail "$agent: cancellation exit code"
  sleep 0.2
  ! pgrep -f toolbox-ask-test-sleeper > /dev/null || fail "$agent: agent kept running after cancellation"
  [[ -z $(ls -A "$TMPDIR") ]] || fail "$agent: temporary files leaked after cancellation"
done

# Each agent is locked to answering in text.
TEST_AGENT=codex "$tool_dir/answer.sh" question > /dev/null
rg -q -- '^--sandbox$' "$TEST_ARGS" && rg -q '^read-only$' "$TEST_ARGS" || fail 'codex: read-only sandbox missing'
TEST_AGENT=claude "$tool_dir/answer.sh" question > /dev/null
mapfile -t claude_args < "$TEST_ARGS"
[[ ${claude_args[0]} == --print ]] || fail 'claude: --print missing'
for i in "${!claude_args[@]}"; do
  [[ ${claude_args[$i]} != --tools ]] || tools_value=${claude_args[$((i + 1))]-missing}
done
[[ ${tools_value-missing} == '' ]] || fail 'claude: tools are not disabled'
rg -q '^--strict-mcp-config$' "$TEST_ARGS" && rg -q '^--no-session-persistence$' "$TEST_ARGS" || fail 'claude: MCP or session flags missing'

# The old Codex-specific override still works.
TOOLBOX_AGENT_CODEX_BIN="$test_dir/bin/fake-codex" TEST_AGENT=codex PATH="$test_dir/bin:/usr/bin" \
  "$tool_dir/answer.sh" question > /dev/null || fail 'TOOLBOX_AGENT_CODEX_BIN override'

# Other agents are offered their own terminal (exit 3); no agent at all is an error.
status=0
TEST_AGENT=gemini "$tool_dir/answer.sh" question > "$test_dir/out" 2> "$test_dir/error" || status=$?
[[ $status == 3 && ! -s $test_dir/out ]] || fail 'unsupported agent should exit 3 with no answer'
rg -q 'Open the question in Gemini' "$test_dir/error" || fail 'unsupported agent message'
status=0
TEST_AGENT='' "$tool_dir/answer.sh" question 2> "$test_dir/error" || status=$?
[[ $status == 1 ]] && rg -q 'No default agent' "$test_dir/error" || fail 'unset agent message'

[[ $(TEST_AGENT=claude "$tool_dir/answer.sh" --agent-info) == '{"id":"claude","name":"Claude Code","inline":true}' ]] || fail 'agent info: claude'
[[ $(TEST_AGENT=gemini "$tool_dir/answer.sh" --agent-info) == '{"id":"gemini","name":"Gemini","inline":false}' ]] || fail 'agent info: gemini'
[[ $(TEST_AGENT='' "$tool_dir/answer.sh" --agent-info) == '{"id":"","name":"","inline":false}' ]] || fail 'agent info: unset'

PATH=$real_path "$tool_dir/install.sh" --check > /dev/null || fail 'Plugin is invalid'
echo 'PASS: codex and claude answers, locked-down flags, errors, timeout, cancellation, cleanup, agent fallback, plugin manifest.'
