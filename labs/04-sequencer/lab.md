# Lab 04 — Sequencer (optional)

## Goal

A multi-producer single-consumer sequencer: several gateway threads
submit payloads, one consumer claims them, and every admitted payload
carries a strictly increasing sequence number. Built on the queue from
lab 02.

Nothing in lab 05 or 06 needs this. Lab 07 can use it in front of the
engine instead of a single queue, which is what a real exchange does.

## Steps

Follow the workflow in `labs/README.md`.

1. `/grill-me labs/04-sequencer/info.md`
2. `/to-prd`, read, fix.
3. `/clear`
4. `/to-work prds/<slug>.md; neckbeard-nate and concerned-carl review
   it, two rounds; between every model step the queue must build and
   pass the tests under the debug and tsan presets`
5. Run it.
6. Commit when the gate passes.

## Done when

- [ ] Every item `done`, gate passed.
- [ ] `ctest --preset tsan` passes, including a test with at least
      three gateway threads and one consumer.
- [ ] `try_claim` returns `std::optional<Sequenced<Payload>>` by
      value; the sequencer keeps no pointer into a returned payload.
- [ ] The lab 02 queue is unchanged (`git diff` on its header is
      empty after this lab).

## Retro

1. The ordering guarantee only speaks about submissions that do not
   overlap in time. How did the test establish "completed strictly
   before" between two threads without a sleep?
2. Which of the reviewers noticed something about the lab 02 queue,
   now that it has a second user?
