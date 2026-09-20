---
name: to-work
description: Turn a PRD file or a free-form request into a work queue for work-runner: a directory of numbered work items where deterministic steps (configure, build, test, checks) are shell scripts and only judgment work goes to a model. Use when the user asks to "queue up", "make work items for", or "prepare a work queue" for a task; the user then runs `work-runner run` themselves.
argument-hint: "<PRD path or a description of the work> [queue name]"
---

# to-work: build a work queue

You turn a request into a directory of work items that `work-runner`
executes one after another, with no human present. You do not do the
work; you write the queue and stop. The user starts the runner.

`work-runner` is on PATH or under `WORK_RUNNER/bin`, where
`WORK_RUNNER` stands for the directory the runner lives in, the one
holding `bin/`, `agents/` and `skills/` (this file is its
`to-work/SKILL.md`); its README explains the runner. `new-item.sh`, next to this SKILL.md, writes one
item with a correct header; use it for every item.

## The model to keep in your head

- A queue is a directory. Each item is a file named `NNNN-slug.ext`.
  Sorted names are the execution order. Number by tens (0010, 0020,
  ...) so an item can be inserted later.
- Sub-work items are a directory named the same way, holding its own
  numbered items. The runner walks depth-first, so `0030-queue/0010-x`
  runs after everything in `0020-*` and before `0040-*`.
- `.md` is an LLM item: the body is the prompt, sent to a fresh headless
  Claude Code session with no memory of earlier items. `.sh` is a shell
  item: the body runs as a script in the project directory.
- The header is YAML between `---` lines. The runner owns `status`,
  `started`, `finished`, `exit_code`, and for LLM items `session_id`,
  `cost_usd`, tokens and turns. You set `title`, `model`, and where
  needed `agent`, `allowed_tools`, `cwd`, `timeout`, `on_fail`.
- Every item runs with the project directory as its working directory
  and gets `WR_WORK_DIR`, `WR_ITEM`, `WR_RUN_DIR` and friends in its
  environment. Item output lands in `<queue>/.run/<item>/`
  (`response.md` for a model, `output.log` for a script). That directory
  is the only channel between items.
- A failed item stops the run. There are no loops and no branches. A
  review-and-fix cycle is unrolled into a fixed number of rounds.
- One item is one conversation with one model. A session cannot spawn
  subagents unless its header says `subagents: allow`; write that only
  when the task genuinely needs fan-out, and prefer more items instead.

## Personas and skills you can give an item

A model item may name a **persona** (`agent:`) and **skills**
(`skills:`, comma-separated) in its header. The runner resolves each
name most-specific first, first hit wins, and fails the item before
spending anything when a name is unknown:

1. directories the user passes with `work-runner run --augment DIR`;
2. the project's augment directory, `.work-runner/agents/<name>.md`
   and `.work-runner/skills/<name>/SKILL.md` (`WR_AUGMENT_DIR`
   overrides the location), for personas and skills that belong to
   this project;
3. the ones shipped with the runner, `WORK_RUNNER/agents/*.md` and
   `WORK_RUNNER/skills/*/SKILL.md`;
4. the project's own `.claude/agents/<name>.md` and
   `.claude/skills/<name>/SKILL.md`, then the same under `~/.claude`,
   used as Claude Code finds them natively. These only fill in names
   the first three do not have.

Run `ls` on those directories before you decompose, so you offer what
exists. Shipped today:

| Persona | Use for |
|---|---|
| `cpp-polymath` | implementing and fixing C++: usage example first, types that enforce it, tests as examples |
| `api-audrey` | reviewing public interfaces: swap test, bikini types, leaked lifetimes, state machines |
| `concerned-carl` | reviewing safety: memory, exceptions, edge cases, UB, resources |
| `neckbeard-nate` | reviewing standards, modern idioms, performance, minimalism |
| `picky-paula` | reviewing structure: responsibilities, decomposition, duplication, testability |
| `meticulous-mira` | reviewing tests: coverage, property tests, assertions, isolation |
| `skeptical-scott` | a last reviewer who reads the others' reviews and hunts what fell between them |
| `verdict-vince` | an aggregator who merges every review into one action list and one verdict |

| Skill | Use for |
|---|---|
| `review-format` | the review shape whose last line is `VERDICT: APPROVED` or `VERDICT: CHANGES_REQUESTED`; give it to every reviewer so the gate can grep |
| `cpp-standards` | the C++ rules the bench enforces (strong types, no bool, explicit, noexcept, nodiscard); give it to implementers and reviewers |

When the user names a persona or a skill, use it. When the user says
"the usual reviewers" or "full review", use all six reviewers, scott
last with the others' `response.md` paths in his prompt, then vince
with all seven, and gate on vince's verdict alone. When the user
names something that exists in none of the three places, say so and
stop rather than inventing a persona.

To add a persona or skill for a project, write it in the augment
directory in Claude Code's own format (frontmatter with `name`,
`description`, `tools`; body is the prompt or the skill text). To
change a shipped one for one project, put a file of the same name in
the augment directory; it wins.

## The rule that matters most

**Only judgment goes to a model. Everything deterministic is a script.**

Shell item: creating directories and boilerplate you can write out
verbatim, `cmake` configure, building, running tests, formatting,
checking that a file exists or contains a marker, copying agent
definitions into place, git operations, gates that grep a verdict out
of a review. If you can write the exact commands now, it is a script.

LLM item: designing or writing code from a specification, fixing what
a build or a review reported, reviewing code, writing documentation
that needs understanding of the code.

A build or test never goes in a prompt as "then run the tests". It is
the next item, as a script, and it fails loudly on its own.

## Protocol

1. **Read the request.** `$ARGUMENTS` is a path to a PRD or a
   description in words, optionally followed by a queue name. Read a
   PRD file in full. When the PRD cites another file by path (a brief,
   a header that fixes an API, a document that pins dependencies),
   read that file too: it holds the verbatim content a scaffold script
   or a prompt must carry. Look at the project directory (the current
   directory) enough to know what exists: build system, test framework,
   language, existing `.claude/agents`.
2. **Decompose** into ordered items. For each feature or component:
   an LLM item that implements it, then a script that builds, then a
   script that tests. Group a feature and its verification in a
   sub-directory when there are more than two or three items for it.
   Put a scaffold script first when the project needs setup that can
   be written verbatim. Put a final gate script last.
3. **Reviews.** When the user names reviewers (for example
   `neckbeard-nate` or `concerned-carl`), each reviewer is one LLM
   item with `agent: <name>`, `skills: review-format` (plus
   `cpp-standards` for C++), and `allowed_tools: Read,Grep,Glob,Bash,Skill`.
   Its final message is the review; the runner saves it as
   `.run/<item>/response.md`, and its last line is `VERDICT: APPROVED`
   or `VERDICT: CHANGES_REQUESTED`. Follow the reviews with an LLM
   item that reads them by path and applies the fixes, then the build
   and test scripts again, then a gate script that greps the
   verdicts. Two rounds is the default; the user can ask for more.
4. **Write every LLM prompt to be self-contained.** The session that
   reads it knows nothing about earlier items. Restate the
   specification it needs (or point at the PRD file by path), name the
   files it must produce, name the build and test commands the next
   items will run so it can run them itself first, and tell it to
   finish with a short summary. Say what "done" means.
5. **Create the queue and the items.**

   ```
   Q=$(work-runner new <name>)
   <skill dir>/new-item.sh "$Q/0010-scaffold.sh" --title "Scaffold the project" <<'EOF'
   ...
   EOF
   <skill dir>/new-item.sh "$Q/0020-impl.md" --title "Implement X" --model claude-sonnet-5 <<'EOF'
   ...
   EOF
   ```

   Scripts should start with `set -euo pipefail` and print what they
   check. Use `timeout:` on anything that could hang. Use `on_fail:
   continue` only for items whose failure the gate will evaluate.
6. **Validate**: `work-runner run --dry-run "$Q"` must list every item
   with no warnings. Then `work-runner status "$Q"`.
7. **Report** the queue path, the item list with one line each, and
   the command to start it: `work-runner run "$Q"`. Do not run it.

## Example decompositions

"Set up this directory as a CMake C++ project with tests":

```
0010-scaffold.sh      write CMakeLists.txt, src/, tests/ skeleton, .gitignore (verbatim)
0020-configure.sh     cmake -S . -B build
0030-build.sh         cmake --build build
0040-test.sh          ctest --test-dir build --output-on-failure
```

Note that nothing here needed a model.

"Create an SPSC queue per spec, nate and carl review it, everything
must build and pass":

```
0010-scaffold.sh              CMakeLists.txt and directories, verbatim
0020-implement.md             agent: cpp-polymath, skills: cpp-standards
0030-build.sh                 configure and build
0040-test.sh                  ctest
0050-review-1/0010-nate.md    agent: neckbeard-nate, skills: review-format, cpp-standards
0050-review-1/0020-carl.md    agent: concerned-carl, same skills
0060-fix-1.md                 read both reviews, apply the fixes, rebuild, retest
0070-build.sh
0080-test.sh
0090-review-2/...             second round, same shape
0100-fix-2.md
0110-build.sh
0120-test.sh
0130-gate.sh                  both round-2 verdicts must be APPROVED
```
