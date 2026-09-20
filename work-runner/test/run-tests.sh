#!/usr/bin/env bash
# run-tests.sh -- exercise the runner offline with a fake claude on PATH.
#
# Works on bash 3.2 and on Linux.  Each test builds a queue in a fresh
# temporary project directory, runs it, and checks the headers and the
# files the run left behind.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WR="$HERE/../bin/work-runner"
export PATH="$HERE/fake-claude:$PATH"
. "$HERE/../lib/frontmatter.sh"

pass=0; fail=0
ok()   { pass=$((pass + 1)); printf 'ok   %s\n' "$1"; }
bad()  { fail=$((fail + 1)); printf 'FAIL %s\n' "$1"; }
check() { if eval "$2"; then ok "$1"; else bad "$1 :: $2"; fi; }

fresh() {   # a new project dir; prints it
    local d
    d="$(mktemp -d "${TMPDIR:-/tmp}/wr-test.XXXXXX")"
    (cd "$d" && pwd)
}
item() {    # item FILE TITLE [key=value...] <<< body
    local file="$1" title="$2"; shift 2
    mkdir -p "$(dirname "$file")"
    { printf -- '---\ntitle: %s\nstatus: todo\n' "$title"
      for kv in "$@"; do printf '%s: %s\n' "${kv%%=*}" "${kv#*=}"; done
      printf -- '---\n'; cat; } > "$file"
}
run() { (cd "$P" && "$WR" run "$@") }

# ---- frontmatter helpers -------------------------------------------------
P="$(fresh)"
item "$P/x.md" "Quoted title" model='"claude-x"' <<'B'
body line 1
---
body line 2
B
check "fm_get strips quotes"          '[ "$(fm_get "$P/x.md" model)" = claude-x ]'
check "fm_get missing key is empty"    '[ -z "$(fm_get "$P/x.md" nope)" ]'
fm_set "$P/x.md" status done; fm_set "$P/x.md" newkey "a: b"
check "fm_set replaces in place"       '[ "$(fm_get "$P/x.md" status)" = done ]'
check "fm_set adds a key"              '[ "$(fm_get "$P/x.md" newkey)" = "a: b" ]'
check "fm_body keeps inner ---"        '[ "$(fm_body "$P/x.md" | tr "\n" "|")" = "body line 1|---|body line 2|" ]'
check "header still well formed"       '[ "$(sed -n 1p "$P/x.md")" = --- ] && [ "$(grep -c "^---$" "$P/x.md")" = 3 ]'

# ---- ordering, nesting, statuses, resume -------------------------------
P="$(fresh)"; Q="$(cd "$P" && "$WR" new order 2>/dev/null)"
check "new creates .work/<stamp>-name" '[ -d "$Q" ] && [ "$(basename "$(dirname "$Q")")" = .work ]'
item "$Q/0010-first.sh"        "first"  <<'B'
echo first >> order.log
B
item "$Q/0020-group/0010-a.sh" "a"      <<'B'
echo a >> order.log; test "$WR_ITEM" = 0020-group/0010-a
B
item "$Q/0020-group/0020-b.sh" "b"      <<'B'
echo b >> order.log
B
item "$Q/0030-last.sh"         "last"   <<'B'
#!/bin/sh
echo last >> order.log; echo "cwd=$PWD"
B
printf 'not an item\n' > "$Q/README.md"
run "$Q" >/dev/null 2>&1; rc=$?
check "run succeeds"                   '[ $rc -eq 0 ]'
check "depth-first sorted order"       '[ "$(tr "\n" " " < "$P/order.log")" = "first a b last " ]'
check "shebang body runs in project"   'grep -q "cwd=$P\$" "$Q/.run/0030-last/output.log"'
check "all done with exit_code 0"      '[ "$(cd "$P" && "$WR" status "$Q" | grep -c "^done ")" = 4 ] && [ "$(fm_get "$Q/0030-last.sh" exit_code)" = 0 ]'
check "started/finished recorded"      '[ -n "$(fm_get "$Q/0010-first.sh" started)" ] && [ -n "$(fm_get "$Q/0010-first.sh" finished)" ]'
run "$Q" >/dev/null 2>&1
check "second run skips done items"    '[ "$(wc -l < "$P/order.log" | tr -d " ")" = 4 ]'
run "$Q" --only 0010-first >/dev/null 2>&1
check "--only reruns a done item"      '[ "$(wc -l < "$P/order.log" | tr -d " ")" = 5 ]'

# ---- failure stops, reset, retry, on_fail continue ----------------------
P="$(fresh)"; Q="$(cd "$P" && "$WR" new fail 2>/dev/null)"
item "$Q/0010-ok.sh"   "ok"   <<'B'
echo ok >> log
B
item "$Q/0020-bad.sh"  "bad"  <<'B'
echo bad >> log; exit 3
B
item "$Q/0030-soft.sh" "soft" on_fail=continue <<'B'
echo soft >> log; exit 4
B
item "$Q/0040-end.sh"  "end"  <<'B'
echo end >> log
B
run "$Q" >/dev/null 2>&1; rc=$?
check "failure stops the run"          '[ $rc -eq 1 ] && [ "$(fm_get "$Q/0020-bad.sh" status)" = failed ] && [ "$(fm_get "$Q/0020-bad.sh" exit_code)" = 3 ]'
check "later items untouched"          '[ "$(fm_get "$Q/0030-soft.sh" status)" = todo ] && [ "$(tr "\n" " " < "$P/log")" = "ok bad " ]'
run "$Q" >/dev/null 2>&1; rc=$?
check "rerun refuses a failed item"    '[ $rc -eq 1 ] && [ "$(wc -l < "$P/log" | tr -d " ")" = 2 ]'
printf -- '---\ntitle: bad\nstatus: failed\n---\necho bad >> log\n' > "$Q/0020-bad.sh"
run "$Q" --retry >/dev/null 2>&1; rc=$?
check "--retry reruns; on_fail continue" '[ $rc -eq 1 ] && [ "$(tr "\n" " " < "$P/log")" = "ok bad bad soft end " ]'
check "soft failure recorded"          '[ "$(fm_get "$Q/0030-soft.sh" status)" = failed ] && [ "$(fm_get "$Q/0040-end.sh" status)" = done ]'
(cd "$P" && "$WR" reset "$Q") >/dev/null 2>&1
check "reset puts failed back to todo" '[ "$(fm_get "$Q/0030-soft.sh" status)" = todo ] && [ -z "$(fm_get "$Q/0030-soft.sh" exit_code)" ] && [ "$(fm_get "$Q/0040-end.sh" status)" = done ]'
(cd "$P" && "$WR" reset "$Q" --all) >/dev/null 2>&1
check "reset --all"                    '[ "$(cd "$P" && "$WR" status "$Q" | grep -c "^todo ")" = 4 ]'

# ---- validation and dry run ---------------------------------------------
P="$(fresh)"; Q="$(cd "$P" && "$WR" new bad 2>/dev/null)"
item "$Q/0010-fine.sh" "fine" <<'B'
echo ran > ran
B
printf 'no header\n' > "$Q/0020-noheader.sh"
item "$Q/0030-what.py" "python" <<'B'
print("hi")
B
run "$Q" >/dev/null 2>&1; rc=$?
check "invalid queue refused, status 2" '[ $rc -eq 2 ] && [ ! -e "$P/ran" ]'
rm "$Q/0020-noheader.sh" "$Q/0030-what.py"
out="$(run "$Q" --dry-run 2>/dev/null)"
check "dry run lists, runs nothing"    '[ "$out" = "$(printf "%-8s %-6s %s" todo shell 0010-fine)" ] && [ ! -e "$P/ran" ] && [ "$(fm_get "$Q/0010-fine.sh" status)" = todo ]'

# ---- timeout --------------------------------------------------------------
P="$(fresh)"; Q="$(cd "$P" && "$WR" new slow 2>/dev/null)"
item "$Q/0010-slow.sh" "slow" timeout=1 <<'B'
sleep 5; echo never > never
B
start=$(date +%s); run "$Q" >/dev/null 2>&1 || true; took=$(( $(date +%s) - start ))
check "timeout kills the item (124)"   '[ "$(fm_get "$Q/0010-slow.sh" exit_code)" = 124 ] && [ $took -lt 5 ]'
sleep 1
check "no orphan left behind"          '[ ! -e "$P/never" ]'

P="$(fresh)"; Q="$(cd "$P" && "$WR" new quick 2>/dev/null)"
item "$Q/0010-quick.sh" "quick" timeout=300 <<'B'
echo quick
B
start=$(date +%s); run "$Q" 2>&1 | cat > /dev/null; took=$(( $(date +%s) - start ))
check "timed item releases stdout promptly" '[ $took -lt 5 ]'
check "no timer sleep left behind"     '! pgrep -f "^sleep 300$" >/dev/null'

# a job that ignores TERM is KILLed five seconds later
P="$(fresh)"; Q="$(cd "$P" && "$WR" new stubborn 2>/dev/null)"
item "$Q/0010-stubborn.sh" "stubborn" timeout=1 <<'B'
trap "" TERM
sleep 30; echo survived > survived
B
start=$(date +%s); run "$Q" >/dev/null 2>&1 || true; took=$(( $(date +%s) - start ))
check "TERM-ignoring item is KILLed (124)" '[ "$(fm_get "$Q/0010-stubborn.sh" exit_code)" = 124 ] && [ $took -lt 15 ]'
check "nothing of it survives the KILL"   '! pgrep -f "^sleep 30$" >/dev/null && [ ! -e "$P/survived" ]'

# ---- interrupt: Ctrl-C must reach a timed item in its own process group --
P="$(fresh)"; Q="$(cd "$P" && "$WR" new intr 2>/dev/null)"
item "$Q/0010-slow.sh" "slow" timeout=60 <<'B'
sleep 4; echo orphan > orphan.txt
B
set -m
(cd "$P" && "$WR" run "$Q") >/dev/null 2>&1 &
drv=$!
set +m
sleep 1
kill -INT -- -"$drv" 2>/dev/null
wait "$drv" 2>/dev/null
sleep 4
check "interrupt kills the timed item"  '[ ! -e "$P/orphan.txt" ]'
check "interrupted item recorded failed" '[ "$(fm_get "$Q/0010-slow.sh" status)" = failed ] && [ "$(fm_get "$Q/0010-slow.sh" exit_code)" -gt 128 ]'

# ---- llm items through the fake claude -----------------------------------
P="$(fresh)"; Q="$(cd "$P" && "$WR" new llm 2>/dev/null)"
item "$Q/0010-ask.md" "ask" model=claude-test-1 <<'B'
The answer is FORTY-TWO. FAKE_WRITE note.txt
Second line of the prompt.
B
item "$Q/0020-check.sh" "check" <<'B'
grep -q FORTY-TWO "$WR_WORK_DIR/.run/0010-ask/response.md" && grep -q FORTY-TWO note.txt
test "{{WR_WORK_DIR}}/.run/0010-ask" = "$WR_WORK_DIR/.run/0010-ask"
test "{{WR_RUN_DIR}}" = "$WR_RUN_DIR" && test "{{WR_ITEM}}" = 0020-check && test "{{WR_PROJECT_DIR}}" = "$WR_PROJECT_DIR"
B
item "$Q/0030-review.md" "review" model=claude-test-2 agent=concerned-carl allowed_tools='Read,Grep' context_dir=ctx <<'B'
LGTM
B
item "$Q/0040-nomodel.md" "no model" <<'B'
whatever
B
run "$Q" >/dev/null 2>&1; rc=$?
check "placeholders and response reach next item" '[ "$(fm_get "$Q/0020-check.sh" status)" = done ]'
check "llm header gets metadata"       '[ "$(fm_get "$Q/0010-ask.md" cost_usd)" = 0.0123 ] && [ "$(fm_get "$Q/0010-ask.md" input_tokens)" = 3210 ] && [ "$(fm_get "$Q/0010-ask.md" output_tokens)" = 20 ] && [ "$(fm_get "$Q/0010-ask.md" num_turns)" = 2 ]'
sid="$(fm_get "$Q/0010-ask.md" session_id)"
S="$Q/.context/$sid/status.json"
check "status.json under .context/<session_id>" '[ -f "$S" ]'
check "status.json is statusline-shaped" '[ "$(jq -r ".model.id" "$S")" = claude-test-1 ] && [ "$(jq -r ".context_window.current_usage.cache_read_input_tokens" "$S")" = 3000 ] && [ "$(jq -r ".context_window.total_input_tokens" "$S")" = 3210 ] && [ "$(jq -r ".context_window.used_percentage" "$S")" = 1 ] && [ "$(jq -r ".cost.total_cost_usd" "$S")" = 0.0123 ] && [ "$(jq -r ".cost.total_lines_added" "$S")" = 1 ] && [ "$(jq -r ".rate_limits.five_hour.used_percentage" "$S")" = 25 ] && [ "$(jq -r ".work_runner.item" "$S")" = 0010-ask ] && [ "$(jq -r ".work_runner.state" "$S")" = done ] && [ "$(jq -r ".session_id" "$S")" = "$sid" ]'
check "body is header-free prompt"     '[ "$(head -n 1 "$Q/.run/0010-ask/body.md")" = "The answer is FORTY-TWO. FAKE_WRITE note.txt" ] && [ "$(wc -l < "$Q/.run/0010-ask/body.md" | tr -d " ")" = 2 ]'
sid2="$(fm_get "$Q/0030-review.md" session_id)"
check "context_dir relative to project" '[ -f "$P/ctx/$sid2/status.json" ]'
check "agent and allowed_tools passed"  '[ "$(jq -r "select(.type==\"system\") | .fake.agent" "$Q/.run/0030-review/stream.jsonl")" = concerned-carl ] && [ "$(jq -r "select(.type==\"system\") | .fake.tools" "$Q/.run/0030-review/stream.jsonl")" = Read,Grep ]'
check "llm item without model fails"    '[ $rc -eq 1 ] && [ "$(fm_get "$Q/0040-nomodel.md" status)" = failed ]'

# ---- placeholders survive sed metacharacters in the project path ---------
P="$(fresh)/a&b|c\\d"; mkdir -p "$P"; Q="$(cd "$P" && "$WR" new meta 2>/dev/null)"
item "$Q/0010-check.sh" "check" <<'B'
test "{{WR_PROJECT_DIR}}" = "$WR_PROJECT_DIR" && test "{{WR_WORK_DIR}}" = "$WR_WORK_DIR"
B
item "$Q/0020-ask.md" "ask" model=m <<'B'
hello
B
(cd "$P" && "$WR" run "$Q") >/dev/null 2>&1; rc=$?
check "placeholders with & | \\ in path"  '[ $rc -eq 0 ] && [ "$(fm_get "$Q/0010-check.sh" status)" = done ]'
check "preamble with & | \\ in path"      'jq -r "select(.type==\"system\") | .fake.system" "$Q/.run/0020-ask/stream.jsonl" | grep -qF "work queue at $Q"'

# ---- personas and skills: shipped, augment, project, unknown -------------
P="$(fresh)"; Q="$(cd "$P" && "$WR" new persona 2>/dev/null)"
mkdir -p "$P/.claude/agents" "$P/.claude/skills/local-skill" "$P/.work-runner/agents" "$P/.work-runner/skills/aug-skill"
printf -- '---\nname: local-agent\ndescription: project agent\n---\nlocal prompt\n' > "$P/.claude/agents/local-agent.md"
printf -- '---\nname: local-skill\ndescription: project skill\n---\nlocal skill\n' > "$P/.claude/skills/local-skill/SKILL.md"
printf -- '---\nname: neckbeard-nate\ndescription: augmented nate\ntools: Read, Grep\n---\nAUGMENTED NATE PROMPT\n' > "$P/.work-runner/agents/neckbeard-nate.md"
printf -- '---\nname: aug-skill\ndescription: augment skill\n---\naug skill body\n' > "$P/.work-runner/skills/aug-skill/SKILL.md"
item "$Q/0010-shipped.md"  "shipped persona" model=m agent=api-audrey skills=review-format <<'B'
audrey
B
item "$Q/0020-augment.md"  "augment persona" model=m agent=neckbeard-nate skills='aug-skill, local-skill' <<'B'
nate
B
item "$Q/0030-project.md"  "project persona" model=m agent=local-agent <<'B'
local
B
item "$Q/0035-collide.md" "shipped beats native" model=m agent=picky-paula skills=review-format <<'B'
paula
B
item "$Q/0036-cli.md"     "cli augment beats all" model=m agent=concerned-carl skills=aug-skill <<'B'
carl
B
item "$Q/0040-unknown.md"  "unknown persona" model=m agent=nobody <<'B'
nobody
B
# native copies of shipped names, which must lose to the shipped files
mkdir -p "$P/.claude/skills/review-format"
printf -- '---\nname: picky-paula\ndescription: native paula\n---\nNATIVE PAULA\n' > "$P/.claude/agents/picky-paula.md"
printf -- '---\nname: review-format\ndescription: native\n---\nnative\n' > "$P/.claude/skills/review-format/SKILL.md"
# a --augment directory on the command line, above the project augment dir
mkdir -p "$P/cli-aug/agents" "$P/cli-aug/skills/aug-skill"
printf -- '---\nname: concerned-carl\ndescription: cli carl\n---\nCLI CARL\n' > "$P/cli-aug/agents/concerned-carl.md"
printf -- '---\nname: aug-skill\ndescription: cli skill\n---\nCLI SKILL\n' > "$P/cli-aug/skills/aug-skill/SKILL.md"
HOME="$P" run "$Q" --augment "$P/cli-aug" >/dev/null 2>&1; rc=$?      # isolated HOME: no ~/.claude agents or skills
init() { jq -c 'select(.type=="system" and .subtype=="init") | .fake' "$Q/.run/$1/stream.jsonl"; }
check "shipped agent passed inline"     '[ "$(init 0010-shipped | jq -r ".agents[\"api-audrey\"].prompt" | grep -c "API Audrey")" -ge 1 ] && [ "$(init 0010-shipped | jq -r ".agent")" = api-audrey ]'
check "shipped agent tools as array"    '[ "$(init 0010-shipped | jq -c ".agents[\"api-audrey\"].tools")" = "[\"Read\",\"Glob\",\"Grep\",\"Bash\",\"Skill\"]" ]'
check "shipped skill copied to plugin"  '[ -f "$Q/.run/0010-shipped/plugin/skills/review-format/SKILL.md" ] && [ -f "$Q/.run/0010-shipped/plugin/.claude-plugin/plugin.json" ] && [ "$(init 0010-shipped | jq -r .plugin_dir)" = "$Q/.run/0010-shipped/plugin" ]'
check "preamble names wr:skill"         'init 0010-shipped | jq -r .system | grep -q "follow them: wr:review-format\.$"'
check "augment agent beats shipped"     '[ "$(init 0020-augment | jq -r ".agents[\"neckbeard-nate\"].prompt")" = "AUGMENTED NATE PROMPT" ] && [ "$(init 0020-augment | jq -c ".agents[\"neckbeard-nate\"].tools")" = "[\"Read\",\"Grep\"]" ]'
check "augment and project skills"      'init 0020-augment | jq -r .system | grep -q "follow them: wr:aug-skill, local-skill\.$" && [ "$(tail -n 1 "$Q/.run/0020-augment/plugin/skills/aug-skill/SKILL.md")" = "CLI SKILL" ] && [ ! -e "$Q/.run/0020-augment/plugin/skills/local-skill" ]'
check "shipped beats project native"    '[ "$(init 0035-collide | jq -r ".agents[\"picky-paula\"].prompt" | grep -c "Picky Paula")" -ge 1 ] && [ -f "$Q/.run/0035-collide/plugin/skills/review-format/SKILL.md" ] && grep -q "VERDICT" "$Q/.run/0035-collide/plugin/skills/review-format/SKILL.md"'
check "--augment beats project augment"  '[ "$(init 0036-cli | jq -r ".agents[\"concerned-carl\"].prompt")" = "CLI CARL" ] && [ "$(cat "$Q/.run/0036-cli/plugin/skills/aug-skill/SKILL.md" | tail -n 1)" = "CLI SKILL" ]'

# an augment directory whose path has a space
mkdir -p "$P/aug dir/agents"
printf -- '---\nname: api-audrey\ndescription: spaced audrey\n---\nSPACED AUDREY\n' > "$P/aug dir/agents/api-audrey.md"
HOME="$P" run "$Q" --only 0010-shipped --augment "$P/aug dir" >/dev/null 2>&1
check "augment path with a space"        '[ "$(init 0010-shipped | jq -r ".agents[\"api-audrey\"].prompt")" = "SPACED AUDREY" ]'
check "project agent passed natively"   '[ "$(init 0030-project | jq -c .agents)" = "{}" ] && [ "$(init 0030-project | jq -r .agent)" = local-agent ] && [ "$(init 0030-project | jq -r .plugin_dir)" = "" ]'
check "unknown agent fails before run"  '[ $rc -eq 1 ] && [ "$(fm_get "$Q/0040-unknown.md" status)" = failed ] && [ ! -e "$Q/.run/0040-unknown/stream.jsonl" -o ! -s "$Q/.run/0040-unknown/stream.jsonl" ]'
check "every shipped agent parses"      'for a in "$HERE"/../agents/*.md; do n=$(basename "$a" .md); [ "$(fm_get "$a" name)" = "$n" ] || exit 1; [ -n "$(fm_get "$a" description)" ] || exit 1; done'
check "every shipped skill parses"      'for k in "$HERE"/../skills/*/SKILL.md; do n=$(basename "$(dirname "$k")"); [ "$(fm_get "$k" name)" = "$n" ] || exit 1; done'

# ---- subagents: disallowed by default, verified from the result -----------
P="$(fresh)"; Q="$(cd "$P" && "$WR" new sub 2>/dev/null)"
item "$Q/0010-default.md" "default"       model=m <<'B'
plain
B
item "$Q/0020-allowed.md" "allowed"       model=m subagents=allow <<'B'
fan out FAKE_SPAWN 3
B
item "$Q/0030-sneaky.md"  "not allowed"   model=m <<'B'
sneaky FAKE_SPAWN 2
B
item "$Q/0040-after.sh"   "after"         <<'B'
true
B
run "$Q" >/dev/null 2>&1; rc=$?
init() { jq -c 'select(.type=="system" and .subtype=="init") | .fake' "$Q/.run/$1/stream.jsonl"; }
check "Agent tool disallowed by default" '[ "$(init 0010-default | jq -r .disallowed)" = "Agent,Task" ] && [ "$(fm_get "$Q/0010-default.md" subagents_spawned)" = 0 ]'
check "subagents: allow lifts it"        '[ "$(init 0020-allowed | jq -r .disallowed)" = "" ] && [ "$(fm_get "$Q/0020-allowed.md" status)" = done ] && [ "$(fm_get "$Q/0020-allowed.md" subagents_spawned)" = 3 ]'
check "spawning without allow fails"     '[ $rc -eq 1 ] && [ "$(fm_get "$Q/0030-sneaky.md" status)" = failed ] && [ "$(fm_get "$Q/0030-sneaky.md" subagents_spawned)" = 2 ] && [ "$(fm_get "$Q/0040-after.sh" status)" = todo ]'

P="$(fresh)"; Q="$(cd "$P" && "$WR" new llmfail 2>/dev/null)"
item "$Q/0010-boom.md" "boom" model=m <<'B'
FAKE_FAIL please
B
item "$Q/0020-after.sh" "after" <<'B'
true
B
run "$Q" >/dev/null 2>&1; rc=$?
check "model error fails the item"     '[ $rc -eq 1 ] && [ "$(fm_get "$Q/0010-boom.md" status)" = failed ] && [ "$(fm_get "$Q/0020-after.sh" status)" = todo ]'
check "error snapshot says failed"     '[ "$(jq -r ".work_runner.state" "$Q/.context/$(fm_get "$Q/0010-boom.md" session_id)/status.json")" = failed ]'

P="$(fresh)"; Q="$(cd "$P" && "$WR" new llmslow 2>/dev/null)"
item "$Q/0010-slow.md" "slow" model=m timeout=1 <<'B'
FAKE_SLEEP 5
B
run "$Q" >/dev/null 2>&1 || true
check "llm timeout -> exit 124"        '[ "$(fm_get "$Q/0010-slow.md" exit_code)" = 124 ]'
check "timeout snapshot marked failed" '[ "$(jq -r ".work_runner.state + \" \" + .work_runner.reason" "$Q/.context/$(fm_get "$Q/0010-slow.md" session_id)/status.json")" = "failed timeout" ]'

P="$(fresh)"; Q="$(cd "$P" && "$WR" new llmcut 2>/dev/null)"
item "$Q/0010-cut.md" "cut off" model=m <<'B'
FAKE_TRUNCATE here
B
run "$Q" >/dev/null 2>&1; rc=$?
check "truncated stream: item fails cleanly" '[ $rc -eq 1 ] && [ "$(fm_get "$Q/0010-cut.md" status)" = failed ] && [ "$(fm_get "$Q/0010-cut.md" exit_code)" = 1 ]'
check "truncated stream: session id kept"   'sid="$(fm_get "$Q/0010-cut.md" session_id)"; [ -n "$sid" ] && [ "$(jq -r ".work_runner.state + \" \" + .work_runner.reason" "$Q/.context/$sid/status.json")" = "failed killed" ]'

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
