# Lab 05 — Messages and the order book

## Goal

The message schema, the strong types it needs, a per-symbol order
book with admit, cancel and modify, and an engine facade that routes
each inbound message to the right book. No matching yet: an order
that would cross simply rests. Matching is lab 06 and must not leak
into this one.

Two things are new. The brief hands you messages whose field types
break a project rule, and you have to decide how to fix them in the
grill. And the review is the full bench, so the queue is long: plan
on an hour of unattended run time, or use nate and carl if short.

## Steps

Follow the workflow in `labs/README.md`.

1. `/grill-me labs/05-order-book/info.md`. The message-type question
   comes first; have an opinion.
2. `/to-prd`, read, fix. Check that the PRD names the cancel fairy
   as out of scope, in the words the brief uses.
3. `/clear`
4. `/to-work prds/<slug>.md; full review, two rounds; between every
   model step the queue must build and pass the tests under the
   debug and ubsan presets; a final gate must fail if any file under
   include/ defines matching, trade generation or top-of-book output`
5. Run it.
6. Commit when the gate passes. Lab 06 freezes what you commit here.

## Done when

- [ ] Every item `done`, gate passed on vince's verdict.
- [ ] `ctest --preset debug` and `ctest --preset ubsan` pass.
- [ ] No two public members of any message share a type, and no
      public signature takes or returns a raw integer or a `bool`.
- [ ] `OrderBook` never returns a pointer or reference to an order.
- [ ] `grep -ri trade include/` finds only the `Trade` message and
      its fields; nothing produces one.
- [ ] The PRD and the code both say the cancel fairy is not
      implemented.

## Retro

1. Did any session try to match? Search the `.run/*/response.md`
   files for "cross" or "match". If one did, what in the brief or
   the PRD pulled it there?
2. Skeptical Scott reads the other reviews and then the code nobody
   commented on. What did he find that the six missed, and would a
   seventh specialist have found it?
