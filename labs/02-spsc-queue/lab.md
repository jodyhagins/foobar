# Lab 02 — SPSC queue

## Goal

A lock-free single-producer single-consumer ring buffer, header-only,
with example tests, property tests, a two-thread test, and a clean run
under TSan. Two reviewers look at it, twice.

This is the first lab where a model writes code. Watch what the queue
does between the model steps: every claim the model makes about
building or passing is checked by a script it did not write.

## Steps

Follow the workflow in `labs/README.md`.

1. `/grill-me labs/02-spsc-queue/info.md`
2. `/to-prd`, read the PRD, fix it by talking.
3. `/clear`
4. `/to-work prds/<slug>.md; neckbeard-nate and concerned-carl review
   it, two rounds; between every model step the queue must build and
   pass the tests under the debug and tsan presets`
5. Run it. Expect roughly a dozen items and half an hour. While it
   runs, tail `.work/<queue>/.run/*/response.md` as they appear.
6. Commit when the gate passes.

## Done when

- [ ] Every item is `done`; the last item is a gate script that found
      `VERDICT: APPROVED` in both round-two reviews.
- [ ] `ctest --preset debug` and `ctest --preset tsan` pass.
- [ ] `include/<name>/SpscQueue.hpp` exposes exactly the contract in
      the brief: no `size()`, no `empty()`, no accessor that returns a
      pointer or reference into the ring.
- [ ] The test file has at least one `rc::doctest::check` property and
      one test that runs a producer thread against a consumer thread.

## Retro

1. Read both round-one reviews. Which findings did the fix item
   accept, which did it decline, and did round two agree with the
   declines? Pick one finding and decide for yourself who was right.
2. Did the model, in any session, say the tests passed when the next
   script showed otherwise? Find the item in `.work/<queue>/` and
   read its `response.md` next to the following `output.log`.
