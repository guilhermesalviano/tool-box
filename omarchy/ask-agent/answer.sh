#!/usr/bin/env bash
# Machine-facing backend: stdout is only the answer, stderr is only an error.
#
#   answer.sh <question...>   Answer with Omarchy's default agent.
#   answer.sh --agent-info    Print {"id","name","inline"} for the default agent.
#
# Exit codes: 0 answered, 1 failed, 3 the agent has no inline mode here (the
# caller can open the question in the agent's own terminal instead).
set -euo pipefail

agent=${TOOLBOX_AGENT:-$(omarchy default agent 2>/dev/null || true)}

agent_name() {
  case $1 in
    claude) echo 'Claude Code' ;;
    codex) echo 'Codex' ;;
    copilot) echo 'GitHub Copilot' ;;
    cursor-agent) echo 'Cursor' ;;
    gemini) echo 'Gemini' ;;
    grok) echo 'Grok' ;;
    hermes) echo 'Hermes' ;;
    muse) echo 'Muse Code' ;;
    omp) echo 'Oh My Pi' ;;
    openclaw) echo 'OpenClaw' ;;
    opencode) echo 'OpenCode' ;;
    pi) echo 'Pi' ;;
    crush) echo 'Crush' ;;
    *) echo "$1" ;;
  esac
}

# Agents with a one-shot mode that can be locked to answering in text only.
# Anything else is still usable through `omarchy agent prompt`.
inline_supported() {
  [[ $1 == codex || $1 == claude ]]
}

if [[ ${1:-} == --agent-info ]]; then
  inline=false
  [[ -z $agent ]] || ! inline_supported "$agent" || inline=true
  jq -nc --arg id "$agent" --arg name "$( [[ -n $agent ]] && agent_name "$agent" )" --argjson inline "$inline" \
    '{id: $id, name: $name, inline: $inline}'
  exit 0
fi

question="$*"
[[ -n ${question//[[:space:]]/} ]] || exit 0
if [[ -z $agent ]]; then
  echo 'No default agent is set. Choose one in Setup → Default → Agent.' >&2
  exit 1
fi
name=$(agent_name "$agent")
if ! inline_supported "$agent"; then
  printf '%s cannot answer inside the menu yet. Open the question in %s instead.\n' "$name" "$name" >&2
  exit 3
fi

# Resolve an already installed executable; Omarchy's wrappers run an update
# check on every invocation, which should not happen for a search query.
agent_bin=${TOOLBOX_AGENT_BIN:-}
[[ -n $agent_bin || $agent != codex ]] || agent_bin=${TOOLBOX_AGENT_CODEX_BIN:-}
if [[ -z $agent_bin ]]; then
  agent_bin=$(mise which "$agent" 2>/dev/null || command -v "$agent" 2>/dev/null) || {
    printf '%s is not installed. Install it through Setup → Default → Agent, or set TOOLBOX_AGENT_BIN.\n' "$name" >&2
    exit 1
  }
fi
[[ -x $agent_bin ]] || { printf 'The configured %s executable does not exist.\n' "$name" >&2; exit 1; }
workdir=${TOOLBOX_AGENT_WORKDIR:-$HOME/Work}
[[ -d $workdir ]] || { printf 'Workspace does not exist: %s\n' "$workdir" >&2; exit 1; }
limit=${TOOLBOX_AGENT_TIMEOUT:-180}
[[ $limit =~ ^[1-9][0-9]*$ ]] || { echo 'TOOLBOX_AGENT_TIMEOUT must be a positive number of seconds.' >&2; exit 1; }

umask 077
scratch=$(mktemp -d "${TMPDIR:-/tmp}/toolbox-ask.XXXXXXXX")
child=''
cleanup() {
  if [[ -n $child ]]; then
    kill -TERM "$child" 2>/dev/null || true
    wait "$child" 2>/dev/null || true
  fi
  rm -rf -- "$scratch"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM HUP
printf '%s\n\n%s\n' \
  'Answer this question concisely for an inline desktop search panel. Explain only; do not change files or system settings. Each request is independent. Prefer plain text with short paragraphs.' \
  "$question" > "$scratch/prompt"

# Each agent answers one question and exits, with every way of acting on the
# system turned off. The prompt goes in on stdin so it is never read as an option.
case $agent in
  codex)
    command=("$agent_bin" -a never exec --sandbox read-only --skip-git-repo-check
      --ephemeral --color never --cd "$workdir" --output-last-message "$scratch/answer" -)
    answer_from=file ;;
  claude)
    # --tools "" leaves Claude no tools at all, so it can only reply in text.
    command=("$agent_bin" --print --tools "" --strict-mcp-config --no-session-persistence
      --output-format text)
    answer_from=stdout ;;
esac

# No subshell: `child` must be the timeout process so cancelling reaches the agent.
timeout --signal=TERM --kill-after=5s "${limit}s" env -C "$workdir" "${command[@]}" \
  < "$scratch/prompt" > "$scratch/stdout" 2> "$scratch/error" &
child=$!
status=0
wait "$child" || status=$?
child=''
[[ $answer_from == file ]] || mv "$scratch/stdout" "$scratch/answer"
if (( status == 124 || status == 137 )); then
  printf 'The request timed out after %s seconds. Try a shorter question or retry.\n' "$limit" >&2
  exit 1
elif (( status != 0 )); then
  printf '%s could not answer. Check your connection and %s sign-in.\n' "$name" "$name" >&2
  # Keep errors useful without flooding the panel with the full execution log.
  tail -c 2500 "$scratch/error" >&2
  exit 1
elif [[ ! -s $scratch/answer || -z $(tr -d '[:space:]' < "$scratch/answer") ]]; then
  printf '%s returned no answer. Please retry.\n' "$name" >&2
  exit 1
fi
cat "$scratch/answer"
