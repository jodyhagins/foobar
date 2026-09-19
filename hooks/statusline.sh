#!/bin/bash

# Documentation: https://code.claude.com/docs/en/statusline

source ~/.bashrc

# Read input JSON
input=$(cat)

# Get current directory from input
cwd=$(echo "$input" | jq -r '.workspace.current_dir')
MODEL=$(echo "$input" | jq -r '.model.display_name')
CONTEXT_SIZE=$(echo "$input" | jq -r '.context_window.context_window_size')
INPUT_TOKENS=$(echo "$input" | jq -r '.context_window.total_input_tokens')
OUTPUT_TOKENS=$(echo "$input" | jq -r '.context_window.total_output_tokens')
CURRENT_USAGE=$(echo "$input" | jq '.context_window.current_usage')
COST=$(echo "$input" | jq -r '.cost.total_cost_usd')

TOTAL_TOKENS=$((INPUT_TOKENS + OUTPUT_TOKENS))
if [ "$CONTEXT_SIZE" -gt 0 ]; then
    TOTAL_PERCENT_USED=$((TOTAL_TOKENS * 100 / CONTEXT_SIZE))
else
    TOTAL_PERCENT_USED=0
fi

if [ "$CURRENT_USAGE" != "null" ]; then
    CURRENT_TOKENS=$(echo "$CURRENT_USAGE" | jq '.input_tokens + .cache_creation_input_tokens + .cache_read_input_tokens')
    CURRENT_PERCENT_USED=$((CURRENT_TOKENS * 100 / CONTEXT_SIZE))
else
    CURRENT_PERCENT_USED=0
fi

case "$(printf '%s' "$MODEL" | tr '[:upper:]' '[:lower:]')" in
    *fable*)
        MODEL_COLOR="$PINK"
        ;;
    *opus*)
        MODEL_COLOR="$BLUE"
        ;;
    *sonnet*)
        MODEL_COLOR="$CYAN"
        ;;
    *haiku*)
        MODEL_COLOR="$GRAY"
        ;;
    *)
        MODEL_COLOR="$GOLD"
        ;;
esac

CTX_NUM_COLOR="${BLACK1}"
if [ ${CURRENT_PERCENT_USED} -lt 50 ]; then
    CTX_PCT_COLOR="${GREEN}"
elif [ ${CURRENT_PERCENT_USED} -lt 60 ]; then
    CTX_PCT_COLOR="${YELLOW}"
elif [ ${CURRENT_PERCENT_USED} -lt 70 ]; then
    CTX_PCT_COLOR="${PINK}"
else
    CTX_PCT_COLOR="${RED}"
fi

printf "${MODEL_COLOR}%s${NC} ${CTX_NUM_COLOR}%d (${CTX_PCT_COLOR}%d%%${CTX_NUM_COLOR})${NC} | %b" "${MODEL}" "${CURRENT_TOKENS}" "${CURRENT_PERCENT_USED}"
