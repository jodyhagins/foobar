#!/usr/bin/env bash
# new-item.sh -- write one work item with a well-formed header.
#
#   new-item.sh FILE --title "..." [options] < body
#
# FILE is the item's path inside the queue, e.g. $Q/0020-build.sh or
# $Q/0030-queue/0010-implement.md.  The extension picks the node type.
# The body comes from stdin.  Options become header fields:
#
#   --title T            required
#   --model M            llm items; default $WR_DEFAULT_MODEL or claude-sonnet-5
#   --provider P         llm items; default claude
#   --agent NAME         llm items; run as this persona (project, augment or shipped)
#   --skills LIST        llm items; skills to load first, comma-separated
#   --subagents allow    llm items; let the session spawn subagents (off by default)
#   --allowed-tools L    llm items; restrict tools, e.g. "Read,Grep,Glob"
#   --max-budget-usd N   llm items
#   --context-dir D      llm items; where status snapshots go
#   --cwd D              directory the item runs in, relative to the project
#   --timeout S          seconds
#   --on-fail continue   keep running the queue when this item fails
#   --field key=value    any other header field
#
# Refuses to overwrite an existing file.
set -eu
[ $# -ge 1 ] || { sed -n '2,24p' "$0"; exit 2; }
file="$1"; shift
title=""; model=""; provider=""; agent=""; skills=""; subagents=""; tools=""; budget=""; ctx=""; cwd=""; timeout=""; onfail=""
extra=""
while [ $# -gt 0 ]; do
    case "$1" in
        --title) title="$2"; shift ;;
        --model) model="$2"; shift ;;
        --provider) provider="$2"; shift ;;
        --agent) agent="$2"; shift ;;
        --skills) skills="$2"; shift ;;
        --subagents) subagents="$2"; shift ;;
        --allowed-tools) tools="$2"; shift ;;
        --max-budget-usd) budget="$2"; shift ;;
        --context-dir) ctx="$2"; shift ;;
        --cwd) cwd="$2"; shift ;;
        --timeout) timeout="$2"; shift ;;
        --on-fail) onfail="$2"; shift ;;
        --field) extra="$extra${2%%=*}: ${2#*=}
"; shift ;;
        *) echo "new-item.sh: unknown option $1" >&2; exit 2 ;;
    esac
    shift
done
[ -n "$title" ] || { echo "new-item.sh: --title is required" >&2; exit 2; }
[ ! -e "$file" ] || { echo "new-item.sh: refusing to overwrite $file" >&2; exit 1; }
case "$(basename "$file")" in
    [0-9][0-9][0-9][0-9]-*) ;;
    *) echo "new-item.sh: item names start with four digits and a dash: $(basename "$file")" >&2; exit 2 ;;
esac
ext="${file##*.}"
if [ "$ext" = md ]; then
    model="${model:-${WR_DEFAULT_MODEL:-claude-sonnet-5}}"
    provider="${provider:-claude}"
fi
mkdir -p "$(dirname "$file")"
{
    printf -- '---\n'
    printf 'title: %s\n' "$title"
    [ -n "$provider" ] && printf 'provider: %s\n' "$provider"
    [ -n "$model" ]    && printf 'model: %s\n' "$model"
    [ -n "$agent" ]    && printf 'agent: %s\n' "$agent"
    [ -n "$skills" ]   && printf 'skills: %s\n' "$skills"
    [ -n "$subagents" ] && printf 'subagents: %s\n' "$subagents"
    [ -n "$tools" ]    && printf 'allowed_tools: %s\n' "$tools"
    [ -n "$budget" ]   && printf 'max_budget_usd: %s\n' "$budget"
    [ -n "$ctx" ]      && printf 'context_dir: %s\n' "$ctx"
    [ -n "$cwd" ]      && printf 'cwd: %s\n' "$cwd"
    [ -n "$timeout" ]  && printf 'timeout: %s\n' "$timeout"
    [ -n "$onfail" ]   && printf 'on_fail: %s\n' "$onfail"
    [ -n "$extra" ]    && printf '%s' "$extra"
    printf 'status: todo\n'
    printf -- '---\n'
    cat
} > "$file"
echo "$file"
