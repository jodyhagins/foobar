# work-runner

Orchestration by directory listing. A queue of work is a directory of
numbered files. A shell script runs them in order, one at a time. A
prompt file goes to a fresh, unattended model session; a script file
runs as a script. The YAML header at the top of each file carries the
item's properties and, once it has run, its state. That is the whole
system, and it is the way this work was done before graph-based
orchestrators existed. It is kept small on purpose so that every
moving part is visible.

Contents:

1. [The model](#the-model)
2. [Installing](#installing)
3. [Commands](#commands)
4. [Work items](#work-items)
5. [How a run works](#how-a-run-works)
6. [How a model item runs](#how-a-model-item-runs)
7. [Personas and skills](#personas-and-skills)
8. [The context snapshot and hooks](#the-context-snapshot-and-hooks)
9. [Cost and token accounting](#cost-and-token-accounting)
10. [How items communicate](#how-items-communicate)
11. [Review and fix cycles](#review-and-fix-cycles)
12. [The to-work skill](#the-to-work-skill)
13. [Examples](#examples)
14. [Extending](#extending)
15. [Testing](#testing)
16. [What it does not do](#what-it-does-not-do)
17. [File layout](#file-layout)

## The model

A **queue** is a directory. A **work item** is a file in it whose name
starts with four digits and a dash: `0010-scaffold.sh`,
`0020-implement.md`. The sorted names are the execution order. Number
by tens so an item can be inserted later.

**Sub-work items** are a directory named the same way, holding its own
numbered items. The runner walks depth-first, so
`0050-review/0010-nate.md` runs after everything in `0040-*` and
before `0060-*`. A byte-order sort of the relative paths gives exactly
that order, and that sort is the scheduler.

The **extension is the node type**. `.md` is a prompt for a model.
`.sh` is a shell script. Each type is one script in `lib/`.

The **header is the node's attributes and its state**:

```
---
title: Implement the tokenizer
provider: claude
model: claude-sonnet-5
timeout: 1800
status: todo
---
Implement the tokenizer described in docs/prd/02-tokenizer.md ...
```

You write the attributes. The runner rewrites `status` as the item
moves through `todo`, `running`, `done` or `failed`, and adds
timestamps, the exit code, and for model items the session id, cost
and token counts. Files are never moved; the queue directory under
`git diff` is the audit log.

The **body is the work**. The runner copies it out without the header
and runs exactly that: as the prompt on stdin for a model, as the
program for a script.

Five rules follow from the design:

- **Every model session starts empty.** No resume, no shared context.
  A prompt carries, or points at, everything its session needs. An
  item that depends on something a previous session "knew" is wrong.
- **One item is one conversation with one model.** The session cannot
  spawn subagents unless its header says `subagents: allow`, and the
  runner checks the result's spawn count against that afterwards. What
  a queue lists is the whole set of model conversations that will run.
- **Items talk through files.** A model's final message is saved as
  `.run/<item>/response.md`; a script's output as
  `.run/<item>/output.log`. The next item reads those. There is no
  other channel.
- **A failure stops the run.** Fix the item, reset it, run again. Done
  items are skipped, so the queue resumes where it stopped.
- **Only judgment goes to a model.** Configure, build, test, copy,
  gate: those are scripts, because they can be, and a script fails the
  same way every time. A prompt that ends with "then run the tests" is
  a bug; the tests are the next item.

## Installing

Requirements: bash 3.2 or later (the macOS default is fine), awk, sed,
find, jq, and the `claude` CLI for model items. Tested on macOS and on
Debian (bash 5.2, mawk, jq 1.6).

Put `bin` on PATH, or call `bin/work-runner` by path. The scripts find
`lib/` relative to themselves, so the directory can live anywhere and
can be copied into another project as a whole.

```
export PATH="$PATH:/path/to/work-runner/bin"
```

To make the skill available in a project, link or copy
`to-work` to that project's `.claude/skills/to-work`.

## Commands

| Command | What it does |
|---|---|
| `work-runner new <name>` | create `./.work/<timestamp>-<name>` and print its path |
| `work-runner run <queue>` | run every item that is not `done` or `skipped`, in order; stop at the first failure |
| `work-runner run --dry-run <queue>` | validate the queue and print what would run |
| `work-runner run --retry <queue>` | also re-run items whose status is `failed` |
| `work-runner run --only <item> <queue>` | run one item whatever its status |
| `work-runner run --augment <dir> <queue>` | a directory of `agents/` and `skills/` that beats every other source; repeatable |
| `work-runner status <queue>` | one line per item: status, type, name, title |
| `work-runner reset <queue> [item...]` | put `failed` and interrupted items, or the named ones, or `--all`, back to `todo` |
| `work-runner help` | usage |

The **project directory** is the directory you run the command from;
`WR_PROJECT_DIR` overrides it. Every item runs there, or in its `cwd:`
relative to it. Queues normally live at `<project>/.work/<id>`, which
is what `new` creates; add `.work/` to the project's `.gitignore`, or
commit the queue if you want the audit log in history.

Before anything runs, the queue is **validated**: a file without a
header, an extension with no runner, an unknown status, or whitespace
in a name refuses the whole run with status 2 and a message per
problem. A typo is found before the first item spends money.

Exit status: 0 when every item that ran succeeded, 1 when any item
failed, whether it stopped the run or carried on under `on_fail:
continue`, 2 when validation refused it.

## Work items

Fields every item may carry:

| Field | Meaning |
|---|---|
| `title` | shown by `status` and in the run log |
| `type` | overrides the extension when picking the runner |
| `cwd` | directory the item runs in, relative to the project |
| `timeout` | seconds; the item fails with exit 124 when exceeded; unset or 0 means no limit |
| `on_fail` | `continue` lets the run carry on after this item fails; the default stops |
| `status` | `todo`, `running`, `done`, `failed`, `skipped`; set `skipped` by hand to leave an item out |
| `started`, `finished`, `exit_code` | written by the runner |

Fields for `.md` (model) items:

| Field | Meaning |
|---|---|
| `provider` | `claude` (the only one shipped); picks `lib/llm-<provider>.sh` |
| `model` | required; passed as `--model`. It also wins over the `model:` in an agent definition |
| `agent` | run the session as this persona; resolved from the project, the augment directory, or the shipped `agents/` (see [Personas and skills](#personas-and-skills)) |
| `skills` | comma-separated skills the session must load before starting; resolved the same way |
| `allowed_tools` | when set, the session gets exactly those tools and no permission bypass; when unset, it runs with `--dangerously-skip-permissions` |
| `subagents` | `allow` lets the session spawn subagents; otherwise the subagent tool is disallowed and a result that reports spawned subagents fails the item |
| `max_budget_usd` | passed through to the CLI |
| `context_dir` | base directory for status snapshots; default `<queue>/.context` |
| `context_window_size` | tokens, for the percentage in the snapshot; default 200000 |
| `session_id`, `cost_usd`, `input_tokens`, `output_tokens`, `num_turns`, `subagents_spawned` | written by the runner from the result |

Header values are flat `key: value` pairs; a value may be wrapped in
double quotes. That is all a work item needs, and it keeps the
implementation to a few lines of awk.

The body may use four placeholders, replaced with real paths when the
item runs: `{{WR_WORK_DIR}}` (the queue), `{{WR_RUN_DIR}}` (this
item's output directory), `{{WR_ITEM}}` (its name, like
`0050-review/0010-nate`), and `{{WR_PROJECT_DIR}}`. This is how a
prompt names an earlier item's output without knowing where the queue
lives.

A `.sh` body runs with `bash`, or directly when it starts with a `#!`
line, so a queue can carry a python or perl step without a new node
type. Scripts should start with `set -euo pipefail` and print what
they check.

Every item sees these environment variables: `WR_WORK_DIR`,
`WR_ITEM`, `WR_ITEM_FILE`, `WR_RUN_DIR`, `WR_BODY`, `WR_PROJECT_DIR`,
`WR_ITEM_CWD`, `WR_ITEM_TYPE`, and `WR_HOME` (the work-runner
directory). Model sessions also get `WR_CONTEXT_DIR`.

## How a run works

`bin/work-runner run <queue>` does this:

1. Lists the items: `find` for files named `NNNN-*`, skipping hidden
   directories such as `.run`, `.context` and `.git`, sorted with
   `LC_ALL=C`.
2. Validates every item, as above.
3. For each item in order: skip it when `done` or `skipped`; stop when
   `failed` unless `--retry`; warn and re-run when `running` (a
   previous run was interrupted).
4. Resolves the node type (the `type:` field, else the extension) to
   `lib/run-<type>.sh`.
5. Creates `.run/<item>/`, writes the header-free body there as
   `body.<ext>` with the placeholders replaced, and sets `status:
   running` and `started:`.
6. Runs `lib/run-<type>.sh` with the `WR_*` environment and stdin from
   `/dev/null`.
7. Writes `finished:`, `exit_code:` and `status: done` or `failed`.
8. On failure, stops with exit 1, unless the item has `on_fail:
   continue`.

The timeout is a bash function in `lib/common.sh` rather than the
`timeout` command, which macOS lacks. It runs the item as a job in its
own process group and, when the limit passes, sends the whole group
TERM and then KILL five seconds later, so a model process and
everything it spawned go together. A Ctrl-C at the terminal, or a TERM
sent to the runner, stops the job the same way, since a job in its own
group would not see either on its own; an interrupted run leaves no
session behind, and the item is recorded as failed with the signal's
exit status.

## How a model item runs

`lib/run-llm.sh` reads `provider:` and hands over to
`lib/llm-<provider>.sh`. The Claude backend runs

```
claude -p --verbose --output-format stream-json --model <model> \
       --append-system-prompt "<lib/llm-preamble.md>" \
       [--agent <agent>] [--max-budget-usd <n>] \
       [--allowedTools <list> | --dangerously-skip-permissions] \
       < body.md
```

in the item's working directory. The preamble tells the model it is
unattended, that nobody can answer a question, where earlier items
left their output, where to leave anything for later items, and to end
with a summary. Edit `lib/llm-preamble.md` to change that contract.

The event stream is piped through `tee` into `.run/<item>/stream.jsonl`
and through `jq -f lib/statusline.jq`, which prints a one-line
description of each event to the console (text blocks, tool calls with
their main argument, the final result) so a run can be watched, and a
snapshot after each event, described in the next section.

When the session ends, the final `result` event becomes
`.run/<item>/result.json`, its text becomes `response.md`, and the
header gets `session_id`, `cost_usd`, `input_tokens`, `output_tokens`
and `num_turns`. A result with `is_error` fails the item, as does a
missing result (a crash, a kill, or the timeout). Sessions are left on
disk, so `claude --resume <session_id>` opens a failed item's session
for a post-mortem; the runner itself never resumes one.

## Personas and skills

A model item may run as a **persona** (`agent:`) and may be told to
load **skills** first (`skills:`). Both are plain files in Claude
Code's own formats: an agent is a Markdown file with `name`,
`description` and `tools` in its frontmatter and the prompt as its
body; a skill is a directory holding `SKILL.md`. The runner looks each
name up most-specific first, first hit wins, and fails the item
before the session starts when a name is found nowhere:

| Order | Where | How it reaches the session |
|---|---|---|
| 1 | directories given on the command line with `run --augment DIR`, in the order given | inline (see below) |
| 2 | the project's **augment directory**, `.work-runner/agents/` and `.work-runner/skills/` (`WR_AUGMENT_DIR` relocates it) | inline |
| 3 | the runner's own `agents/` and `skills/` | inline |
| 4 | the project's `.claude/agents/<name>.md` and `.claude/skills/<name>/SKILL.md` | natively, by name |
| 5 | the same under `~/.claude` | natively, by name |

Inline means the agent file becomes an `--agents` definition and the
skill directory is copied into a per-run plugin at
`.run/<item>/plugin/`, where the session sees it as `wr:<name>`. An
inline definition beats a native one of the same name, which is what
makes the order hold: the files written for the runner, with the
output shape its gates expect, win over copies that exist for
interactive use, and native ones only fill in names the runner does
not know. A file of the same name higher in the list replaces a lower
one for that run, so a project overrides a shipped persona by putting
its own in the augment directory, and a one-off experiment overrides
both with `--augment`. The copies the runner made are left in
`.run/<item>/` (`agent.md`, `plugin/`) so a run shows exactly what the
session was given. The header's `model:` always wins over a `model:`
in an agent file.

The preamble tells the session which skills to load ("load each of
these skills with the Skill tool and follow them: wr:review-format")
before it reads the prompt.

Shipped personas, condensed from a longer C++ review bench to their
main ideas, each ending in the same review shape:

| Persona | Role |
|---|---|
| `cpp-polymath` | the developer: usage example first, types that enforce it, compile time where possible, tests as examples |
| `api-audrey` | public interfaces only: the swap test, bikini types, leaked lifetimes, exposed state machines |
| `concerned-carl` | safety: ownership, exception paths, edge cases, undefined behaviour, resources |
| `neckbeard-nate` | standards, modern idioms, performance, minimalism |
| `picky-paula` | structure: responsibilities, decomposition, duplication, testability |
| `meticulous-mira` | tests: coverage, property tests, assertions, isolation |
| `skeptical-scott` | the gap finder: reads the specialists' reviews, then the code they did not comment on |
| `verdict-vince` | the aggregator: merges all reviews into one ordered action list and one verdict |

Shipped skills:

| Skill | Content |
|---|---|
| `review-format` | the review shape whose final line is `VERDICT: APPROVED` or `VERDICT: CHANGES_REQUESTED`, so a gate script can grep it |
| `cpp-standards` | the rules every reviewer checks: strong semantic types, no `bool`, `explicit`, the `noexcept` and `[[nodiscard]]` policies, approved patterns |

Reviewers run with `allowed_tools: Read,Grep,Glob,Bash,Skill`. What keeps
a reviewer from editing is the persona's `tools:` line, which withholds
Write and Edit; the allow list only pre-approves the listed tools so a
headless session is never stopped by a permission prompt, and it must
name Skill because the preamble asks the session to load skills. Bash
is unrestricted, so a reviewer could still write through the shell;
the prompt's "do not modify any file" is the guard there. The six reviewers plus scott and vince
form a full bench: scott's prompt names the others' `response.md`
paths, vince's names all seven, and the gate greps vince's verdict.

## The context snapshot and hooks

While a session runs, the runner keeps a JSON snapshot at

    <context_dir>/<session_id>/status.json

rewritten atomically after every event. Its shape is the JSON a Claude
Code **status line** command receives on stdin, so anything written to
read that input reads this file:

| Field | Source |
|---|---|
| `session_id`, `model.id`, `model.display_name`, `version`, `cwd`, `workspace.*`, `output_style` | the `init` event |
| `context_window.current_usage` | the usage of the most recent API call of the main session |
| `context_window.total_input_tokens` | input + cache creation + cache read of that call |
| `context_window.used_percentage`, `remaining_percentage` | input-only, the same formula Claude Code uses |
| `exceeds_200k_tokens` | input plus output of that call over 200k |
| `cost.total_cost_usd`, `total_api_duration_ms` | the final `result` event; 0 until then |
| `cost.total_duration_ms` | wall clock since the session started |
| `cost.total_lines_added`, `total_lines_removed` | counted from `Write` and `Edit` tool calls in the stream |
| `rate_limits.five_hour`, `seven_day` | from `rate_limit_event`, when one arrives |
| `work_runner.work_dir`, `item`, `run_dir`, `state`, `turns` | not in a real status line: which queue and item own this session, and whether it is `running`, `done` or `failed` |

The base directory is `context_dir:` in the header, default
`<queue>/.context`, and is exported to the session as
`WR_CONTEXT_DIR`. A hook running inside that session gets its own
session id on stdin and can therefore find its file.
`examples/hooks/context-guard.sh` is a `PreToolUse` hook that denies
further tool calls once `used_percentage` passes a threshold, which is
the kind of guard an unattended run needs and an interactive session
gets from the status line for free. Install it in the project's
`.claude/settings.json`:

```json
{ "hooks": { "PreToolUse": [ { "matcher": "",
    "hooks": [ { "type": "command", "command": "bash /path/to/context-guard.sh" } ] } ] } }
```

## Cost and token accounting

The header's `cost_usd` comes from the result event's
`total_cost_usd`, and its `input_tokens`, `output_tokens` and
`num_turns` from the result's `usage`. Both **include subagents** the
session spawned: in a probe where the main session's own turns
produced six output tokens, the result reported 272, the subagent's
share. Cost is computed by Claude Code at list price and may differ
from a bill.

By default no item spawns subagents: the runner passes
`--disallowedTools Agent,Task` unless the header says `subagents:
allow`, records the result's `subagent_stats.spawned` in the header
as `subagents_spawned`, and fails an item that spawned any without
permission. So the per-item numbers normally describe exactly one
conversation, and when they do not, the header says so.

The live snapshot is different. Only the main session's API calls
appear in the stream; a subagent's calls do not, so
`context_window` describes the main session's context, which is what
a context guard needs, and `total_lines_added` misses files a subagent
wrote. `cost.total_cost_usd` in the snapshot is 0 until the result
arrives.

Cost across a queue is a sum over headers. `work-runner status` does
not total it; a one-liner does:

```
grep -h '^cost_usd:' -r "$Q" --include='*.md' | awk '{s+=$2} END {print s}'
```

## How items communicate

Only through the file system, and only forward in time:

- **The run directory.** `.run/<item>/response.md` for a model's final
  message, `output.log` for a script's output, `stream.jsonl` and
  `result.json` for the raw record. A later item reads them by path,
  usually through `{{WR_WORK_DIR}}`.
- **The project tree.** Whatever an item writes to disk, the next item
  can read. A reviewer could write `REVIEW.md` into the project
  instead of relying on its final message.
- **The header.** The runner's status, exit code and metadata, which a
  script can read with `fm_get` from `lib/frontmatter.sh`.

An item sees only what finished before it. Two model sessions never
run at the same time and never share state.

## Review and fix cycles

The runner has no loops and no branches, so a review-fix cycle is
**unrolled into a fixed number of rounds** when the queue is written.
The SPSC example is the pattern:

```
0020-implement.md             the work
0030-build.sh, 0040-test.sh   scripted verification
0050-review-1/0010-nate.md    reviewer 1: agent: neckbeard-nate, skills: review-format, cpp-standards
0050-review-1/0020-carl.md    reviewer 2: agent: concerned-carl, same skills
0060-fix-1.md                 reads both reviews by path, applies fixes
0070-build.sh, 0080-test.sh   scripted verification again
0090-review-2/...             round 2, told where round 1's reviews are
0100-gate.sh                  greps VERDICT: APPROVED out of both round-2 reviews
```

Nothing is dynamic. Each reviewer's prompt asks for a final message in
a fixed shape ending in `VERDICT: APPROVED` or
`VERDICT: CHANGES_REQUESTED`; the fix item's prompt names the two
`response.md` paths; the gate is a script that greps them. If round 2
does not approve, the gate fails, the run stops, and a person decides:
add `0110-fix-2.md` and another round by hand, or stop. Choosing the
number of rounds up front, and having the last word be a script's,
is the discipline the tool teaches. (A queue that grows itself, with a
gate script appending items for the runner to pick up on a rescan, is
a small change to the driver and a large change to what the directory
listing tells you; it is left as an exercise.)

## The to-work skill

`to-work/SKILL.md` is a Claude Code skill that turns a request
into a queue. In an interactive session, in the project directory:

```
/to-work docs/prd/02-tokenizer.md
/to-work set up this directory as a CMake C++ project with tests
/to-work create an SPSC queue per docs/spsc.md; nate and carl review it; everything must build and pass
```

The request stays plain; the wiring between items is the skill's job.
It reads the PRD or the sentence, looks at the project, and splits the
work into items under the rule that only judgment goes to a model. It
writes each item with `new-item.sh` (next to `SKILL.md`; it produces a
correct header and refuses to overwrite), points later items at
earlier outputs with `{{WR_WORK_DIR}}`, unrolls reviews as above when
reviewers are named, validates with `work-runner run --dry-run`, and
prints the `work-runner run` command. It does not run the queue.

Say more only when you want something other than the default: a
specific place the reviews should go, three rounds instead of two, a
different model per item, an output location outside the queue.

## Examples

`examples/cmake-project/` sets up a CMake C++ project with a test.
Four items, no model at all. Copy the queue into an empty directory
and run it; it takes a couple of seconds.

`examples/spsc-queue/` implements a single-producer single-consumer
queue as `cpp-polymath`, has the `neckbeard-nate` and
`concerned-carl` personas review it with the `review-format` and
`cpp-standards` skills loaded, applies the fixes, reviews again, and
gates on the second round's verdicts. Builds and tests are scripts between every model step. A
full run on `claude-sonnet-5` under Claude Code 2.1.278 took twelve
items, about forty minutes of wall clock and about four dollars; both
round-1 reviews requested changes, both round-2 reviews approved, and
the fix item was the most expensive session at a third of the total.

Each example directory has its own README with the exact commands.

## Extending

**A node type** is a file `lib/run-<type>.sh`, executable. It is
called with the `WR_*` environment, `$WR_BODY` holding the header-free
body, and its exit status is the item's. Files named `NNNN-x.<type>`
then run through it, and `type:` in a header overrides the extension.
Source `lib/common.sh` for `wr_log`, `wr_die` and `wr_run_timeout`,
and `lib/frontmatter.sh` for `fm_get`, `fm_set`, `fm_body`.

**A provider** for `.md` items is the same shape one level down:
`lib/llm-<provider>.sh`, chosen by the header's `provider:`. It should
write `response.md` and set the header's `session_id` and cost fields
the way `lib/llm-claude.sh` does, so the rest of the queue does not
care which model ran.

**A persona or a skill** is a file in `agents/` or `skills/`, or in a
project's augment directory, in Claude Code's own format. Nothing
else changes.

**The preamble** every model session gets is `lib/llm-preamble.md`.

**The snapshot** shape is `lib/statusline.jq`; add a field there and
every session's `status.json` has it.

## Testing

`test/run-tests.sh` runs the whole runner offline against a fake
`claude` (`test/fake-claude/claude`) that emits a realistic event
stream and obeys markers in the prompt to fail, sleep, or write a
file. It covers ordering and nesting, resume, failure and `on_fail`,
reset and retry, validation, dry run, timeouts for both node types and
the absence of orphans afterwards, the KILL that follows an ignored
TERM, an interrupt while a timed item runs,
header metadata, placeholders including a project path with sed
metacharacters in it, a stream cut off mid-event, the
agent and tool flags, persona and skill resolution from every source
including the augment override, an augment path with a space in it,
and the unknown-name refusal, the
subagent default and its verification,
that every shipped persona and skill parses, and the shape of the
status snapshot including the failed-session case.

```
bash test/run-tests.sh
docker run --rm -v "$PWD:/wr:ro" debian:bookworm-slim bash -c \
  'apt-get update -qq && apt-get install -y -qq jq procps && cp -R /wr /tmp/wr && bash /tmp/wr/test/run-tests.sh'
```

Run it whenever `bin/` or `lib/` changes. The example queues are the
live tests; they cost money and need a compiler.

## What it does not do

No branching on a result, no retries inside the runner, no parallel
items, no session resume, no shared state between sessions, no
scheduling beyond the sort. Each is an exercise: add it, and notice
how quickly the directory listing stops telling you what will happen.
Parallel items in particular are forty lines of bash and a race
between two sessions editing the same tree; the sequential reviewers
in the SPSC example cost a few minutes of wall clock and buy a runner
whose whole behaviour is `ls`.

## File layout

```
work-runner/
  bin/work-runner              the driver: new, run, status, reset
  lib/common.sh                logging, timestamps, the process-group timeout
  lib/frontmatter.sh           fm_has, fm_get, fm_set, fm_body
  lib/run-shell.sh             node type shell
  lib/run-llm.sh               node type llm: dispatch on provider
  lib/llm-claude.sh            provider claude: headless Claude Code, stream parsing, snapshots
  lib/llm-preamble.md          system prompt appended to every model item
  lib/statusline.jq            stream-json events -> status-line-shaped snapshots
  agents/*.md                  shipped personas: the review bench and the developer
  skills/*/SKILL.md            shipped skills: review-format, cpp-standards
  to-work/SKILL.md             the queue-writing skill
  to-work/new-item.sh          writes one item with a correct header
  examples/cmake-project/      queue with no model items
  examples/spsc-queue/         queue with implementation, two review rounds, a gate
  examples/hooks/context-guard.sh
  test/run-tests.sh            offline suite
  test/fake-claude/claude      stand-in for the CLI
```
