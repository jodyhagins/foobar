#!/usr/bin/env bash
# run-shell.sh -- node type `shell`: run the item body as a script.
#
# The body was copied header-free to $WR_BODY by the driver.  It runs in
# $WR_ITEM_CWD with the WR_* variables in its environment.  If the body
# starts with a #! line it is executed directly, so a queue can carry a
# python or perl step without a new node type; otherwise bash runs it.
# Output goes to the console and to $WR_RUN_DIR/output.log.  The item
# fails when the script exits non-zero, or when `timeout:` seconds pass.
set -euo pipefail
. "$WR_LIB/common.sh"
. "$WR_LIB/frontmatter.sh"

timeout="$(fm_get "$WR_ITEM_FILE" timeout)"

run_script() {
    cd "$WR_ITEM_CWD"
    if head -n 1 "$WR_BODY" | grep -q '^#!'; then
        chmod +x "$WR_BODY"
        "$WR_BODY" 2>&1 | tee "$WR_RUN_DIR/output.log"
    else
        bash "$WR_BODY" 2>&1 | tee "$WR_RUN_DIR/output.log"
    fi
}

wr_run_timeout "${timeout:-0}" run_script
