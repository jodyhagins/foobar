# Lab 07 — Wiring and the end-to-end run

## Goal

A runner that feeds the engine from an inbound queue on its own
thread, a consumer program that hosts the whole pipeline and prints
what comes out, and an end-to-end test with three threads that is
clean under TSan. This is where the lab 02 queue, the lab 05 messages
and the lab 06 engine meet, and the screen tells you whether it
works.

## Steps

Follow the workflow in `labs/README.md`. Commit lab 06 first.

1. `/grill-me labs/07-ipc/info.md`
2. `/to-prd`, read, fix.
3. `/clear`
4. `/to-work prds/<slug>.md; full review, two rounds; between every
   model step the queue must build and pass the tests under the
   debug and tsan presets, and run the consumer program under the
   tsan preset checking that it prints at least one Trade line and
   exits 0 within five seconds; a gate after every model step must
   fail if git diff against HEAD touches the public declarations
   from labs 05 and 06`
5. Run it.
6. Commit when the gate passes. Then run the consumer yourself:

   ```bash
   cmake --build --preset debug && ./.build/debug/apps/consumer
   ```

## Done when

- [ ] Every item `done`, gate passed.
- [ ] `ctest --preset debug` and `ctest --preset tsan` pass, and the
      TSan run of the consumer prints no `WARNING: ThreadSanitizer`.
- [ ] The consumer prints at least one `Trade` line and exits 0.
- [ ] No `std::atomic_thread_fence` anywhere, or if there is one, a
      comment at it names the two accesses it orders.
- [ ] The cancel fairy still has no code in it.

## Retro

1. If TSan reported anything during the run, what did the fix change?
   A memory order, a fence, or the structure? Which of those is a
   fix and which is a silencer?
2. You now have seven queue directories under `.work/`. Total their
   cost with the one-liner in the work-runner README. Which lab cost
   the most, and was it the one with the hardest code or the one
   with the longest review?
