# Lab 00 — Setup

## Goal

A project directory of your own, `work-runner` on your PATH, and the
three skills installed in the project, all checked with one smoke
test. Fifteen minutes.

Do everything inside the Docker container from `START.md`. Claude
Code runs there, not on your host.

## Steps

1. **Check the tools.** `work-runner` needs bash, awk, sed, find,
   jq and the `claude` CLI.

   ```bash
   jq --version && claude --version && cmake --version | head -1
   ```

2. **Put the runner on PATH.** `COURSE` is wherever you cloned this
   repository.

   ```bash
   export COURSE=$HOME/course              # adjust
   export PATH="$PATH:$COURSE/work-runner/bin"
   work-runner help
   ```

   Put both `export` lines in your shell profile so a new terminal
   still has them.

3. **Make a project.** Empty, its own git repository, with a link
   back to the labs so the paths in every lab resolve.

   ```bash
   mkdir -p ~/me && cd ~/me && git init
   ln -s "$COURSE/labs" labs
   printf '.build/\n.work/\nlabs\n' > .gitignore
   ```

4. **Install the skills** into the project. Symlinks, so edits in
   the course repo show up here.

   ```bash
   mkdir -p .claude/skills
   ln -s "$COURSE/skills/grill-me" .claude/skills/grill-me
   ln -s "$COURSE/skills/to-prd"   .claude/skills/to-prd
   ln -s "$COURSE/work-runner/to-work" .claude/skills/to-work
   ls -l .claude/skills
   ```

5. **Smoke-test the runner** with the queue that needs no model.

   ```bash
   mkdir -p /tmp/hello && cd /tmp/hello
   mkdir -p .work && cp -R "$COURSE/work-runner/examples/cmake-project/queue" .work/cmake
   work-runner run .work/cmake
   work-runner status .work/cmake
   cd ~/me
   ```

   Four items, all `done`, in a few seconds.

6. **Smoke-test the skills.** Start `claude` in `~/me` and type
   `/grill-me`. It should ask you what you are planning. Type
   `/exit`.

## Done when

- [ ] `work-runner help` prints usage from any directory.
- [ ] `work-runner status /tmp/hello/.work/cmake` shows four `done` items.
- [ ] `ls ~/me/.claude/skills` shows `grill-me`, `to-prd`, `to-work`.
- [ ] `~/me/labs/01-project/info.md` opens.

## Notes

- Model items default to `claude-sonnet-5`. To change the default
  for every queue you create, `export WR_DEFAULT_MODEL=<model id>`
  before `/to-work`; to change one item, edit its header.
- Read `$COURSE/work-runner/README.md` § "The model" before lab 01.
  It is short, and it is the whole tool.
