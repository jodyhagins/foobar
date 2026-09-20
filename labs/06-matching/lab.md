# Lab 06 — Matching

## Goal

Price-time-priority matching inside the order book, and an engine
that publishes `Trade` and `TopOfBook` messages to its outbound queue
with a monotonic sequence number. The lab 05 headers are frozen: a
gate script fails the run if their public signatures changed.

This is the lab where models say "matching works" before the test
binary has been rebuilt. The queue routes around that: every claim
is followed by a script.

## Steps

Follow the workflow in `labs/README.md`. Commit lab 05 first; the
freeze gate compares against `HEAD`.

1. `/grill-me labs/06-matching/info.md`
2. `/to-prd`, read, fix.
3. `/clear`
4. `/to-work prds/<slug>.md; full review, two rounds; between every
   model step the queue must build and pass the tests under the
   debug and ubsan presets; the first item after the scaffold must
   be failing tests written before the implementation; a gate after
   every model step must fail if git diff against HEAD touches the
   public declarations of OrderBook, MatchingEngine or the messages`
5. Run it.
6. Commit when the gate passes.

## Done when

- [ ] Every item `done`, gate passed.
- [ ] `ctest --preset debug` and `ctest --preset ubsan` pass.
- [ ] `git diff HEAD~ -- include/` shows additions only in the
      private parts and new files; no public signature from lab 05
      changed.
- [ ] The test binary has one `rc::doctest::check` property that
      compares total traded quantity against a reference model.
- [ ] A drain of the outbound queue after one `accept` that caused
      two trades yields `[Trade, Trade, TopOfBook]`, in that order.

## Retro

1. For each model item, was `ctest` run inside the session before it
   claimed success? `grep -c ctest .work/<queue>/.run/<item>/stream.jsonl`
   answers it. For any item where the answer is zero and the
   following script passed anyway, what would have caught a lie?
2. Read the conservation property's reference model. How long is it?
   If it is over forty lines it is its own attack surface; could the
   property have been stated against a simpler invariant?
