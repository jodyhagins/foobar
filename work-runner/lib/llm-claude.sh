#!/usr/bin/env bash
# llm-claude.sh -- provider `claude`: run the item body as a headless
# Claude Code prompt.
#
# Header fields this backend reads:
#   model                required; passed as --model
#   agent                optional; run the session as this persona
#   skills               optional; comma-separated skills the session must
#                        load first
#
# Persona and skill names are resolved most-specific first, first hit
# wins, and an unknown name fails the item before the session starts:
#   1. directories given with `work-runner run --augment DIR`, in order
#   2. the project's augment directory, $WR_AUGMENT_DIR or
#      <project>/.work-runner
#   3. the runner's own agents/ and skills/
#   4. the project's .claude/agents and .claude/skills
#   5. the same under ~/.claude
# 1-3 hold files written for the runner (agents/<name>.md,
# skills/<name>/SKILL.md) and are passed inline: the agent as an
# --agents definition, the skill copied into a per-run plugin and named
# wr:<name>.  4-5 are Claude Code's own and are passed by name.  An
# inline definition beats a native one of the same name, which is what
# lets 1-3 win.
#   subagents            optional; `allow` lets the session spawn subagents.
#                        Otherwise the Agent tool is disallowed, and a result
#                        that reports spawned subagents fails the item anyway
#   allowed_tools        optional; when set the session gets only those
#                        tools and no permission bypass, otherwise it runs
#                        with --dangerously-skip-permissions
#   max_budget_usd       optional; passed as --max-budget-usd
#   timeout              optional; seconds, 0 or unset means no limit
#   context_dir          optional; base directory for the status snapshots,
#                        default <queue>/.context.  The snapshot for this
#                        session is <context_dir>/<session_id>/status.json
#   context_window_size  optional; tokens, default 200000
#
# Each session starts fresh: no --resume, no --continue.  The prompt is
# the body on stdin, plus lib/llm-preamble.md as an appended system
# prompt so the model knows it is unattended and where earlier items left
# their output.
#
# Claude Code is run with --output-format stream-json so the run can be
# watched.  The raw stream is kept in $WR_RUN_DIR/stream.jsonl; the
# final `result` event becomes result.json and its text response.md; the
# header gets session_id, cost_usd, input_tokens, output_tokens and
# num_turns.  While the session runs, every event refreshes
# <context_dir>/<session_id>/status.json, in the shape a status line
# command receives, so a hook inside the session can look up its own
# context usage by session id (WR_CONTEXT_DIR is in its environment).
set -euo pipefail
. "$WR_LIB/common.sh"
. "$WR_LIB/frontmatter.sh"
wr_require claude jq

model="$(fm_get "$WR_ITEM_FILE" model)"
[ -n "$model" ] || wr_die "$WR_ITEM: an llm item needs 'model:' in its header"
agent="$(fm_get "$WR_ITEM_FILE" agent)"
skills="$(fm_get "$WR_ITEM_FILE" skills)"
subagents="$(fm_get "$WR_ITEM_FILE" subagents)"
allowed_tools="$(fm_get "$WR_ITEM_FILE" allowed_tools)"
max_budget="$(fm_get "$WR_ITEM_FILE" max_budget_usd)"
timeout="$(fm_get "$WR_ITEM_FILE" timeout)"
context_dir="$(fm_get "$WR_ITEM_FILE" context_dir)"
context_dir="${context_dir:-$WR_WORK_DIR/.context}"
case "$context_dir" in /*) ;; *) context_dir="$WR_PROJECT_DIR/$context_dir" ;; esac
context_window_size="$(fm_get "$WR_ITEM_FILE" context_window_size)"
context_window_size="${context_window_size:-200000}"
mkdir -p "$context_dir"
export WR_CONTEXT_DIR="$context_dir"

preamble="$(wr_fill ITEM "$WR_ITEM" WORK_DIR "$WR_WORK_DIR" RUN_DIR "$WR_RUN_DIR" < "$WR_LIB/llm-preamble.md")"

args=(-p --verbose --output-format stream-json --model "$model")
# One item is one conversation with one model unless the header says
# `subagents: allow`.  Agent is the subagent tool's name; Task its old one.
[ "$subagents" = allow ] || args+=(--disallowedTools "Agent,Task")

# ---- persona and skills ----------------------------------------------------
# The search path for runner-format personas and skills, most specific
# first.  WR_AUGMENT_DIRS is colon-separated, set by `run --augment`.
search_dirs=()
old_ifs="$IFS"; IFS=:
for d in ${WR_AUGMENT_DIRS:-}; do [ -n "$d" ] && search_dirs+=("$d"); done
IFS="$old_ifs"
search_dirs+=("${WR_AUGMENT_DIR:-$WR_PROJECT_DIR/.work-runner}" "$WR_HOME")
plugin_dir="$WR_RUN_DIR/plugin"
rm -rf "$plugin_dir"

# wr_agent_json FILE NAME: an inline --agents definition built from an
# agent file in Claude Code's own format (frontmatter with description
# and tools, body is the prompt).  The model is left out so the header's
# model: stays in charge.
wr_agent_json() {
    fm_body "$1" > "$WR_RUN_DIR/agent-prompt.md"
    jq -n --arg name "$2" --arg desc "$(fm_get "$1" description)" \
          --arg tools "$(fm_get "$1" tools)" --rawfile prompt "$WR_RUN_DIR/agent-prompt.md" \
        '{($name): ({description: $desc, prompt: $prompt}
                    + (if $tools == "" then {} else {tools: ($tools | split(",") | map(gsub("^\\s+|\\s+$"; "")))} end))}'
}

if [ -n "$agent" ]; then
    agent_from=""
    for d in "${search_dirs[@]}"; do
        [ -f "$d/agents/$agent.md" ] && { agent_from="$d/agents/$agent.md"; break; }
    done
    if [ -n "$agent_from" ]; then
        cp "$agent_from" "$WR_RUN_DIR/agent.md"
        args+=(--agents "$(wr_agent_json "$agent_from" "$agent")")
    elif [ -f "$WR_PROJECT_DIR/.claude/agents/$agent.md" ] || [ -f "$HOME/.claude/agents/$agent.md" ]; then
        agent_from="native"
    else
        wr_die "$WR_ITEM: unknown agent '$agent'; looked for agents/$agent.md in: ${search_dirs[*]}, then $WR_PROJECT_DIR/.claude/agents and ~/.claude/agents"
    fi
    args+=(--agent "$agent")
fi

skill_refs=""
for skill in $(printf '%s' "$skills" | tr ',' ' '); do
    skill_from=""
    for d in "${search_dirs[@]}"; do
        [ -f "$d/skills/$skill/SKILL.md" ] && { skill_from="$d/skills/$skill"; break; }
    done
    if [ -n "$skill_from" ]; then
        mkdir -p "$plugin_dir/skills"
        cp -R "$skill_from" "$plugin_dir/skills/$skill"
        skill_refs="$skill_refs wr:$skill"
    elif [ -f "$WR_PROJECT_DIR/.claude/skills/$skill/SKILL.md" ] || [ -f "$HOME/.claude/skills/$skill/SKILL.md" ]; then
        skill_refs="$skill_refs $skill"
    else
        wr_die "$WR_ITEM: unknown skill '$skill'; looked for skills/$skill/SKILL.md in: ${search_dirs[*]}, then $WR_PROJECT_DIR/.claude/skills and ~/.claude/skills"
    fi
done
if [ -d "$plugin_dir/skills" ]; then
    mkdir -p "$plugin_dir/.claude-plugin"
    printf '{"name": "wr", "description": "skills for work item %s", "version": "1.0.0"}\n' "$WR_ITEM" \
        > "$plugin_dir/.claude-plugin/plugin.json"
    args+=(--plugin-dir "$plugin_dir")
fi
if [ -n "$skill_refs" ]; then
    preamble="$preamble

Before anything else, load each of these skills with the Skill tool and follow them:$(printf '%s' "$skill_refs" | sed 's/ \([^ ]*\)/ \1,/g; s/,$//')."
fi
args+=(--append-system-prompt "$preamble")
[ -n "$max_budget" ] && args+=(--max-budget-usd "$max_budget")
if [ -n "$allowed_tools" ]; then
    args+=(--allowedTools "$allowed_tools")
else
    args+=(--dangerously-skip-permissions)
fi

stream="$WR_RUN_DIR/stream.jsonl"
: > "$stream"
wr_log "claude --model $model${agent:+ --agent $agent}${skill_refs:+ skills:$skill_refs}${allowed_tools:+ --allowedTools $allowed_tools}$([ "$subagents" = allow ] && printf ' subagents:allow') (cwd $WR_ITEM_CWD)"

call_claude() {
    cd "$WR_ITEM_CWD"
    claude "${args[@]}" < "$WR_BODY" 2> "$WR_RUN_DIR/stderr.log" \
    | tee "$stream" \
    | jq -r -n -R --unbuffered -f "$WR_LIB/statusline.jq" \
        --arg cwd "$WR_ITEM_CWD" --arg project_dir "$WR_PROJECT_DIR" \
        --arg transcript_path "$stream" --arg model "$model" \
        --arg context_window_size "$context_window_size" \
        --arg work_dir "$WR_WORK_DIR" --arg item "$WR_ITEM" --arg run_dir "$WR_RUN_DIR" \
    | while IFS= read -r sid && IFS= read -r display && IFS= read -r snapshot; do
        if [ -n "$sid" ]; then
            mkdir -p "$context_dir/$sid"
            printf '%s\n' "$snapshot" > "$context_dir/$sid/status.json.tmp"
            mv "$context_dir/$sid/status.json.tmp" "$context_dir/$sid/status.json"
        fi
        [ -n "$display" ] && wr_log "  $display"
    done
    return 0
}

rc=0
wr_run_timeout "${timeout:-0}" call_claude || rc=$?

# A kill can land while tee is mid-line, so the last line may be a
# truncated event; read leniently, or the good events before it are lost.
result="$(jq -cR 'fromjson? | select(.type == "result")' "$stream" 2>/dev/null | tail -n 1 || true)"
if [ -z "$result" ]; then
    # Killed, timed out, or crashed before the result event.  Record the
    # session id anyway (the session is on disk for `claude --resume`),
    # and stop the snapshot claiming the session is still running.
    [ "$rc" -eq 124 ] && wr_warn "$WR_ITEM: timed out after ${timeout}s"
    wr_warn "$WR_ITEM: claude produced no result (exit $rc); see $WR_RUN_DIR/stderr.log"
    session_id="$(jq -rR 'fromjson? | select(.type == "system" and .subtype == "init") | .session_id' "$stream" 2>/dev/null | head -n 1 || true)"
    if [ -n "$session_id" ]; then
        fm_set "$WR_ITEM_FILE" session_id "$session_id"
        snap="$context_dir/$session_id/status.json"
        if [ -f "$snap" ]; then
            jq --arg why "$([ "$rc" -eq 124 ] && echo timeout || echo killed)" \
               '.work_runner.state = "failed" | .work_runner.reason = $why' "$snap" > "$snap.tmp" \
                && mv "$snap.tmp" "$snap"
        fi
    fi
    [ "$rc" -eq 0 ] && rc=1
    exit "$rc"
fi

printf '%s\n' "$result" > "$WR_RUN_DIR/result.json"
printf '%s\n' "$result" | jq -r '.result // ""' > "$WR_RUN_DIR/response.md"

session_id="$(printf '%s' "$result" | jq -r '.session_id // ""')"
fm_set "$WR_ITEM_FILE" session_id "$session_id"
fm_set "$WR_ITEM_FILE" cost_usd "$(printf '%s' "$result" | jq -r '.total_cost_usd // 0')"
fm_set "$WR_ITEM_FILE" input_tokens "$(printf '%s' "$result" | jq -r '(.usage.input_tokens // 0) + (.usage.cache_creation_input_tokens // 0) + (.usage.cache_read_input_tokens // 0)')"
fm_set "$WR_ITEM_FILE" output_tokens "$(printf '%s' "$result" | jq -r '.usage.output_tokens // 0')"
fm_set "$WR_ITEM_FILE" num_turns "$(printf '%s' "$result" | jq -r '.num_turns // 0')"
spawned="$(printf '%s' "$result" | jq -r '.subagent_stats.spawned // 0')"
fm_set "$WR_ITEM_FILE" subagents_spawned "$spawned"
[ -n "$session_id" ] && wr_log "context snapshot: $context_dir/$session_id/status.json"

if [ "$(printf '%s' "$result" | jq -r '.is_error')" = "true" ]; then
    wr_warn "$WR_ITEM: claude reported an error ($(printf '%s' "$result" | jq -r '.subtype')): $(head -c 300 "$WR_RUN_DIR/response.md")"
    exit 1
fi
[ "$rc" -eq 0 ] || exit "$rc"
if [ "$subagents" != allow ] && [ "$spawned" -gt 0 ]; then
    wr_warn "$WR_ITEM: session spawned $spawned subagent(s) but the header does not say 'subagents: allow'"
    exit 1
fi

wr_log "response (first lines of $WR_RUN_DIR/response.md):"
head -n 12 "$WR_RUN_DIR/response.md" | sed 's/^/    /' >&2
exit 0
