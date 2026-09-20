# Lab 03 — Seqlock array (optional)

## Goal

An array of seqlock-protected slots, each publishing a trivially
copyable value from one writer to any number of readers, with a test
that provokes torn reads and proves they are detected, under TSan.

Nothing in later labs needs this component. Do it for the TSan
exercise: a seqlock is the primitive where a plausible-looking
implementation compiles, works on the happy path, and is undefined
behaviour under a concurrent reader.

## Steps

Follow the workflow in `labs/README.md`.

1. `/grill-me labs/03-seqlock/info.md`
2. `/to-prd`, read, fix.
3. `/clear`
4. `/to-work prds/<slug>.md; neckbeard-nate and concerned-carl review
   it, two rounds; between every model step the queue must build and
   pass the tests under the debug and tsan presets`
5. Run it.
6. Commit when the gate passes.

## Done when

- [ ] Every item `done`, gate passed.
- [ ] `ctest --preset tsan` passes, and the test binary includes a
      test with one writer thread and several reader threads.
- [ ] `try_snapshot` returns `std::optional<T>` by value and nothing
      exposes the slot storage.

## Retro

1. Did TSan ever fail during the run? Find the item. If the fix added
   a fence or changed a memory order, read the fixed code and say
   which two accesses the change orders and why that is enough.
2. Concerned Carl worries about everything. Which of his findings
   was the one that mattered?
