#!/usr/bin/env bash
# run-llm.sh -- node type `llm`: send the item body to a model.
#
# The header's `provider:` picks the script that talks to the model,
# lib/llm-<provider>.sh, in the same way the extension picked this
# script.  Only `claude` ships; adding one is one file.
set -euo pipefail
. "$WR_LIB/common.sh"
. "$WR_LIB/frontmatter.sh"

provider="$(fm_get "$WR_ITEM_FILE" provider)"
provider="${provider:-${WR_DEFAULT_PROVIDER:-claude}}"
backend="$WR_LIB/llm-$provider.sh"
[ -x "$backend" ] || wr_die "$WR_ITEM: unknown provider '$provider' (no $backend)"
exec "$backend"
