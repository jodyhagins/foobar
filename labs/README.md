# Labs

Seven small labs build the parts of a matching engine. Every lab has
the same shape, and the shape is the lesson: you never type C++, and
you never write a workflow prompt. You answer questions, a PRD gets
written, the PRD becomes a queue of work items, and a shell script
runs the queue while you watch.

| Lab | Builds | Needs |
|---|---|---|
| [00-setup](00-setup.md) | your project directory, the tools, the skills | Docker image from `START.md` |
| [01-project](01-project/lab.md) | a CMake project with doctest and rapidcheck | 00 |
| [02-spsc-queue](02-spsc-queue/lab.md) | single-producer single-consumer queue | 01 |
| [03-seqlock](03-seqlock/lab.md) | seqlock array (optional; nothing later needs it) | 01 |
| [04-sequencer](04-sequencer/lab.md) | multi-gateway sequencer (optional; lab 07 can use it) | 02 |
| [05-order-book](05-order-book/lab.md) | messages, strong types, per-symbol order book, engine routing | 02 |
| [06-matching](06-matching/lab.md) | price-time matching, trades, top of book | 05 |
| [07-ipc](07-ipc/lab.md) | engine thread, consumer app, end-to-end test under TSan | 06 |

## The workflow every lab uses

Each lab directory holds two files. `lab.md` is the assignment: what
to type, what "done" looks like, and two questions to answer when it
is over. `info.md` is the brief: what is given, what is out of
scope, and what is left for you to decide. You read `lab.md`; the
model reads `info.md`.

1. **Grill.** In your project, start `claude` and type
   `/grill-me labs/NN-name/info.md`. The model reads the brief and
   interviews you about what it leaves open, one question at a time,
   with a recommendation each time. Answer until it says every
   decision is resolved.
2. **PRD.** Type `/to-prd`. The model turns the conversation into
   `prds/<slug>.md`. It will check its module list with you. Read
   the file it wrote; fix anything wrong by telling it.
3. **Clear.** Type `/clear`. The PRD file is the handoff; the
   conversation is not.
4. **Queue.** Type the `/to-work` line from the lab. The model writes
   a directory of numbered work items under `.work/` and prints the
   `work-runner run` command. It does not run it. Look at the items:
   `.sh` for everything deterministic, `.md` for judgment only.
5. **Run.** Quit `claude`, run the printed command, and watch. Each
   item's output lands in `.work/<queue>/.run/<item>/`. A failed item
   stops the run; fix the item, `work-runner reset`, run again.
6. **Check** the done-when list in the lab, commit, and answer the
   retro questions in a sentence or two each.

The reviewers named in the `/to-work` lines are the personas shipped
with `work-runner/agents/`. Two reviewers is cheap; the full bench
(six reviewers, a gap finder, an aggregator) is thorough and slow.
Each lab says which it expects; use the cheaper one when short on time.
