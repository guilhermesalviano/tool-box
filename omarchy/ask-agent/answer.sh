#!/usr/bin/env bash
# Machine-facing backend: stdout is only the answer, stderr is only an error.
set -euo pipefail

question="$*"
[[ -n ${question//[[:space:]]/} ]] || exit 0
agent=$(omarchy default agent)
if [[ $agent != codex ]]; then
  printf 'Inline answers currently support Codex. Your default agent is %s. Choose Codex in Setup → Default → Agent.\n' "${agent:-not set}" >&2
  exit 1
fi

# Resolve an already installed executable; Omarchy's wrapper runs an update
# on every invocation, which should not happen for a search query.
codex_bin=${TOOLBOX_AGENT_CODEX_BIN:-}
if [[ -z $codex_bin ]]; then
  codex_bin=$(mise which codex 2>/dev/null) || {
    echo 'Codex is not installed in mise. Install it through Setup → Default → Agent, or set TOOLBOX_AGENT_CODEX_BIN.' >&2
    exit 1
  }
fi
[[ -x $codex_bin ]] || { echo 'The configured Codex executable does not exist.' >&2; exit 1; }
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

timeout --signal=TERM --kill-after=5s "${limit}s" \
  "$codex_bin" -a never exec --sandbox read-only --skip-git-repo-check \
  --ephemeral --color never --cd "$workdir" \
  --output-last-message "$scratch/answer" - \
  < "$scratch/prompt" > "$scratch/events" 2> "$scratch/error" &
child=$!
status=0
wait "$child" || status=$?
child=''
if (( status == 124 || status == 137 )); then
  printf 'The request timed out after %s seconds. Try a shorter question or retry.\n' "$limit" >&2
  exit 1
elif (( status != 0 )); then
  echo 'Codex could not answer. Check your connection and Codex sign-in.' >&2
  # Keep errors useful without flooding the panel with the full execution log.
  tail -c 2500 "$scratch/error" >&2
  exit 1
elif [[ ! -s $scratch/answer ]]; then
  echo 'Codex returned no answer. Please retry.' >&2
  exit 1
fi
cat "$scratch/answer"
