# common.sh -- helpers shared by the driver and the node runners.  Sourced.
#
# Everything here works on bash 3.2 (macOS) and later.

wr_log()  { printf '[work-runner] %s\n' "$*" >&2; }
wr_warn() { printf '[work-runner] warning: %s\n' "$*" >&2; }
wr_die()  { printf '[work-runner] error: %s\n' "$*" >&2; exit "${WR_DIE_STATUS:-1}"; }

# ISO-8601 UTC timestamp, the one value written into every header.
wr_now() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# Fail early when a tool the runner needs is missing.
wr_require() {
    local tool
    for tool in "$@"; do
        command -v "$tool" >/dev/null 2>&1 || wr_die "required tool not found: $tool"
    done
}

# wr_fill NAME VALUE [NAME VALUE...]
#
# Copy stdin to stdout with every {{NAME}} replaced by VALUE, literally.
# sed's replacement would read &, | and \ in a path as syntax; awk's
# index/substr read nothing.  Values may not contain newlines.
wr_fill() {
    local spec=""
    while [ $# -ge 2 ]; do spec="$spec$1
$2
"; shift 2; done
    WR_FILL_SPEC="$spec" awk '
        BEGIN {
            n = split(ENVIRON["WR_FILL_SPEC"], part, "\n")
            for (i = 1; i + 1 <= n; i += 2) { k++; name[k] = "{{" part[i] "}}"; val[k] = part[i + 1] }
        }
        {
            line = $0
            for (i = 1; i <= k; i++) {
                out = ""
                while ((p = index(line, name[i])) > 0) {
                    out = out substr(line, 1, p - 1) val[i]
                    line = substr(line, p + length(name[i]))
                }
                line = out line
            }
            print line
        }'
}

# wr_pause SECS
#
# Sleep without a foreground child.  bash 3.2 does not run a trap when
# the foreground command was itself killed by the trapped signal (a
# Ctrl-C reaches the sleep too), so the sleep runs as a job and the
# shell sits in `wait`, which a trapped signal interrupts.
wr_pause() {
    local spid
    sleep "$1" & spid=$!
    wait "$spid" 2>/dev/null || kill "$spid" 2>/dev/null
}

# wr_kill_group PID
#
# TERM the process group led by PID, and KILL it if anything is still
# alive five seconds later.  Used for a timeout and for an interrupt.
# The liveness check is on the group, not the leader: a script that
# traps TERM keeps its children alive after the leader shell is gone.
wr_kill_group() {
    local pid="$1" i
    kill -TERM -- -"$pid" 2>/dev/null
    for i in 1 2 3 4 5; do
        kill -0 -- -"$pid" 2>/dev/null || return 0
        wr_pause 1
    done
    kill -KILL -- -"$pid" 2>/dev/null
}

# wr_run_timeout SECS FUNCTION [ARGS...]
#
# Run FUNCTION in the background and kill its whole process group if it
# is still alive after SECS seconds.  SECS of 0 means no limit.  Returns
# the function's status, or 124 on a timeout (the same convention as
# coreutils timeout, which macOS does not ship).
#
# The function runs as a job with `set -m`, so it becomes a process group
# leader and `kill -- -PID` reaches every child it spawned (claude, tee,
# jq, the script under test), not only the shell running the function.
# Background jobs read stdin from /dev/null, so the function must open
# any input it needs itself.
#
# Being its own process group also means a Ctrl-C at the terminal, or a
# TERM sent to the runner, does not reach the job on its own; the trap
# below notices either and stops the job the same way a timeout does,
# so an interrupted run leaves no session behind.  The job is polled
# once a second rather than waited on, so a job that ignores TERM still
# gets the KILL five seconds later.  The loop runs no foreground
# command (SECONDS is the clock, kill -0 the probe, wr_pause the sleep)
# so the trap is honoured on bash 3.2.
wr_run_timeout() {
    local secs="$1"; shift
    if [ "${secs:-0}" -le 0 ]; then
        "$@"
        return $?
    fi
    set -m
    "$@" &
    local pid=$!
    set +m
    local reason="" deadline rc=0
    deadline=$(( SECONDS + secs ))
    trap 'reason=interrupted' INT TERM
    while [ -z "$reason" ] && kill -0 "$pid" 2>/dev/null; do
        [ "$SECONDS" -lt "$deadline" ] || reason=timeout
        [ -n "$reason" ] || wr_pause 1
    done
    case "$reason" in
        interrupted) wr_warn "interrupted; stopping the item"; wr_kill_group "$pid" ;;
        timeout)     wr_kill_group "$pid" ;;
    esac
    trap - INT TERM
    wait "$pid" 2>/dev/null || rc=$?
    [ "$reason" = timeout ] && rc=124
    return "$rc"
}
