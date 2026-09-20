#!/usr/bin/env bash
# context-guard.sh -- a PreToolUse hook that reads the runner's snapshot.
#
# Inside a headless session started by work-runner, WR_CONTEXT_DIR names
# the base directory of the status snapshots, and the hook's own input
# carries the session id.  Together they locate
# $WR_CONTEXT_DIR/<session_id>/status.json, which has the same shape as
# a status line's input, refreshed after every stream event.
#
# This hook blocks further tool calls once context usage passes a
# threshold, so the model has to wrap up instead of running into the
# wall.  Install it in the project's .claude/settings.json:
#
#   { "hooks": { "PreToolUse": [ { "matcher": "",
#       "hooks": [ { "type": "command",
#                    "command": "bash /path/to/context-guard.sh" } ] } ] } }
#
# WR_CONTEXT_LIMIT is the percentage (default 80).
set -eu
input="$(cat)"
[ -n "${WR_CONTEXT_DIR:-}" ] || exit 0              # not under work-runner
sid="$(printf '%s' "$input" | jq -r '.session_id // ""')"
snap="$WR_CONTEXT_DIR/$sid/status.json"
[ -f "$snap" ] || exit 0
used="$(jq -r '.context_window.used_percentage // 0' "$snap")"
limit="${WR_CONTEXT_LIMIT:-80}"
if [ "${used%.*}" -ge "$limit" ]; then
    jq -n --arg u "$used" --arg l "$limit" '{
      hookSpecificOutput: { hookEventName: "PreToolUse", permissionDecision: "deny",
        permissionDecisionReason: ("work-runner: context is \($u)% used (limit \($l)%). Stop using tools, write your summary now.") } }'
fi
exit 0
