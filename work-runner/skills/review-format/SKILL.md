---
name: review-format
description: The shape of a code review whose final message a work queue can read: findings by severity with file and line, ending in a single VERDICT line a gate script can grep.
---

# Review format

Your final message is the review. A later work item reads it from a
file and a script greps its last line, so keep exactly this shape and
nothing after the verdict.

```
# <Kind> Review: <component>

## Summary
<one paragraph>

## Findings

### <SEVERITY>-<NNN>: <short title>
**Location:** `file:line` — `symbol`
**Issue:** <what is wrong>
**Rationale:** <why it matters; cite the standard or show the failing scenario>
**Recommendation:** <how to fix, with code when short>

(repeat; write "None." when there are no findings)

## Verdict
<one or two sentences>
VERDICT: APPROVED
```

The last line is exactly `VERDICT: APPROVED` or
`VERDICT: CHANGES_REQUESTED`. Request changes when any finding is
MEDIUM or above. Severity words are CRITICAL, HIGH, MEDIUM, LOW, with
the meanings your persona defines.

If a review from an earlier round is given to you, say for each of
its findings whether it was resolved, before your own findings.
