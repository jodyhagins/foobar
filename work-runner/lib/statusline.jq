# statusline.jq -- fold Claude Code's stream-json events into snapshots in
# the shape a status line command receives on stdin.
#
# Run with `jq -r -n -R --unbuffered -f statusline.jq`, with the event
# stream on stdin as raw lines (a truncated last line is skipped) and
# these --arg values: cwd, project_dir, transcript_path, model,
# context_window_size, work_dir, item, run_dir.  For every event
# it prints three lines: the session id, a one-line description of the
# event for the console (possibly empty), and the snapshot as one line of
# JSON.  The caller writes each snapshot to <context_dir>/<session_id>/
# status.json, where a hook running inside that session can read it.
#
# Field by field, from the status line documentation:
#   context_window.current_usage      usage of the most recent API call
#   context_window.total_input_tokens input + cache creation + cache read
#   context_window.used_percentage    input-only, like Claude Code computes it
#   cost.total_cost_usd               known only from the final result event;
#                                     0 until then (Claude Code prices calls
#                                     client-side, this script does not)
#   cost.total_lines_added/removed    counted from Write and Edit tool calls
#   rate_limits                       from rate_limit_event, when one arrives
# Extra, not in a real status line: `work_runner` says which queue and item
# produced this session and whether it is still running.

def display_name:
  sub("^claude-"; "") | split("-")[0] | (.[0:1] | ascii_upcase) + .[1:];

def lines(s): (s // "" | tostring | split("\n") | length);

def initial: {
  cwd: $cwd,
  session_id: "",
  transcript_path: $transcript_path,
  model: { id: $model, display_name: ($model | display_name) },
  workspace: { current_dir: $cwd, project_dir: $project_dir, added_dirs: [] },
  version: "",
  output_style: { name: "default" },
  cost: { total_cost_usd: 0, total_duration_ms: 0, total_api_duration_ms: 0,
          total_lines_added: 0, total_lines_removed: 0 },
  context_window: { total_input_tokens: 0, total_output_tokens: 0,
                    context_window_size: ($context_window_size | tonumber),
                    used_percentage: null, remaining_percentage: null,
                    current_usage: null },
  exceeds_200k_tokens: false,
  work_runner: { work_dir: $work_dir, item: $item, run_dir: $run_dir,
                 state: "running", started_at: now, turns: 0 }
};

def with_model(m):
  if m then .model.id = m | .model.display_name = (m | display_name) else . end;

def apply(e):
  if e.type == "system" and e.subtype == "init" then
    .version = (e.claude_code_version // .version)
    | with_model(e.model)
    | .output_style.name = (e.output_style // .output_style.name)
    | .cwd = (e.cwd // .cwd) | .workspace.current_dir = .cwd
  elif e.type == "assistant" then
    (e.message.usage // {}) as $u
    | with_model(e.message.model)
    | .context_window.current_usage = {
        input_tokens: ($u.input_tokens // 0),
        output_tokens: ($u.output_tokens // 0),
        cache_creation_input_tokens: ($u.cache_creation_input_tokens // 0),
        cache_read_input_tokens: ($u.cache_read_input_tokens // 0) }
    | (.context_window.current_usage
       | .input_tokens + .cache_creation_input_tokens + .cache_read_input_tokens) as $in
    | .context_window.total_input_tokens = $in
    | .context_window.total_output_tokens = .context_window.current_usage.output_tokens
    | .context_window.used_percentage = (($in * 100 / .context_window.context_window_size) | floor)
    | .context_window.remaining_percentage = (100 - .context_window.used_percentage)
    | .exceeds_200k_tokens = (($in + .context_window.current_usage.output_tokens) > 200000)
    | .work_runner.turns += ([e.message.content[]? | select(.type == "text")] | length)
    | reduce (e.message.content[]? | select(.type == "tool_use")) as $t (.;
        if $t.name == "Write" then
          .cost.total_lines_added += lines($t.input.content)
        elif $t.name == "Edit" then
          .cost.total_lines_added += lines($t.input.new_string)
          | .cost.total_lines_removed += lines($t.input.old_string)
        else . end)
  elif e.type == "rate_limit_event" then
    (e.rate_limit_info.unifiedWindows // {}) as $w
    | .rate_limits = ({}
        + (if $w.five_hour then { five_hour: { used_percentage: ($w.five_hour.utilization * 100),
                                               resets_at: $w.five_hour.resetsAt } } else {} end)
        + (if $w.seven_day then { seven_day: { used_percentage: ($w.seven_day.utilization * 100),
                                               resets_at: $w.seven_day.resetsAt } } else {} end))
  elif e.type == "result" then
    .cost.total_cost_usd = (e.total_cost_usd // 0)
    | .cost.total_api_duration_ms = (e.duration_api_ms // 0)
    | .work_runner.state = (if e.is_error then "failed" else "done" end)
    | .work_runner.turns = (e.num_turns // .work_runner.turns)
    | .work_runner.finished_at = now
  else . end
  | .session_id = (e.session_id // .session_id)
  | .cost.total_duration_ms = (((now - .work_runner.started_at) * 1000) | floor);

def squash: tostring | gsub("\\s+"; " ");

def display(e):
  if e.type == "system" and e.subtype == "init" then
    "session \(e.session_id) model \(e.model // "?") claude-code \(e.claude_code_version // "?")"
  elif e.type == "assistant" then
    [ e.message.content[]?
      | if .type == "text" then "text: " + (.text | squash | .[0:160])
        elif .type == "tool_use" then
          "tool " + .name + ": " + ((.input.file_path // .input.command // .input.pattern
                                     // .input.skill // .input.description // .input.prompt // "")
                                    | squash | .[0:120])
        else empty end ] | join("; ")
  elif e.type == "result" then
    "result: \(e.subtype), \(e.num_turns // 0) turns, $\(e.total_cost_usd // 0)"
  else "" end;

foreach (inputs | fromjson? // empty) as $e (initial; apply($e); .session_id, display($e), tojson)
