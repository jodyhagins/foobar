---
title: Gate on the round-2 verdicts
status: todo
---
set -euo pipefail
ok=0
for r in 0010-nate 0020-carl; do
    f="{{WR_WORK_DIR}}/.run/0090-review-2/$r/response.md"
    verdict="$(grep -o 'VERDICT: [A-Z_]*' "$f" | tail -n 1 || true)"
    echo "$r: ${verdict:-no verdict found}"
    [ "$verdict" = "VERDICT: APPROVED" ] || ok=1
done
[ "$ok" -eq 0 ] || { echo "gate: a reviewer did not approve; read the reviews above and add a fix round"; exit 1; }
echo "gate: both reviewers approved"
