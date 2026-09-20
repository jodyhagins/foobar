---
name: grill-me
description: Interview the user relentlessly about a plan or design until reaching shared understanding, resolving each branch of the decision tree. Use when user wants to stress-test a plan, get grilled on their design, or mentions "grill me". Takes an optional brief file that fixes part of the design.
argument-hint: "[path to a brief, e.g. labs/02-spsc-queue/info.md]"
---

Interview me relentlessly about every aspect of this plan until we reach a shared understanding. Walk down each branch of the design tree, resolving dependencies between decisions one-by-one. For each question, provide your recommended answer.

Ask the questions one at a time.

If a question can be answered by exploring the codebase, explore the codebase instead.

## The brief

If `$ARGUMENTS` names a file, read it in full before the first question. It is the brief for the thing being designed, and it is authoritative:

- Everything the brief states is settled. Do not ask about it, do not offer to change it, and do not re-decide it. Quote it back only when a later answer would contradict it.
- Ask only about what the brief leaves open. If it has a section listing open decisions, those come first, in order; then anything else you find unresolved.
- When the brief and the codebase disagree, say so and ask which wins.

When every open decision is resolved, say so in one line and stop. The next step is usually `/to-prd`, which turns this conversation into a PRD; do not write the PRD yourself.
