# Lab 01 — The project

## Goal

A CMake C++20 project with doctest and rapidcheck as fetched
third-party dependencies, three sanitizer presets, one smoke test
that uses both frameworks, and a `CLAUDE.md` stating the project
rules. Every later lab builds inside it.

The point of the lab is the workflow, on a task where nothing needs
judgment. The queue you get should have **no `.md` item at all**.
If it has one, ask why.

## Steps

Follow the workflow in `labs/README.md`, with these specifics.

1. `claude` in `~/me`, then `/grill-me labs/01-project/info.md`.
   The brief fixes almost everything; expect three or four questions
   (project name, warnings-as-errors, extra presets).
2. `/to-prd`. Read `prds/*.md`. It must cite the brief by path so the
   next step can copy the CMake files from it.
3. `/clear`.
4. `/to-work prds/<slug>.md; everything deterministic; the queue must
   configure, build and test under the debug, tsan and ubsan presets`
5. Quit, run the printed `work-runner run` command.
6. Commit.

## Done when

- [ ] `work-runner status .work/<queue>` shows every item `done` and
      no `.md` item in the list.
- [ ] `ctest --preset debug`, `ctest --preset tsan` and
      `ctest --preset ubsan` each pass the smoke test.
- [ ] `CLAUDE.md` exists at the project root and states the rules
      from the brief.
- [ ] `git status` is clean after your commit; `.build/` and
      `.work/` are ignored.

## Retro

1. Open the scaffold script under `.work/<queue>/`. It is the brief
   copied out by a model. Did anything change on the way through the
   PRD? If so, was the change an improvement or a drift?
2. How long did the grill take, and how many of the questions did
   you actually have an opinion about? A brief that leaves nothing
   open is a script, not a design; a brief that leaves everything
   open is a blank page. Where should this one have been?
