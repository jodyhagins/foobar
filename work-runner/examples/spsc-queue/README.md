# Example: an SPSC queue, reviewed by nate and carl

The request was: "create a single-producer single-consumer queue as a
header-only C++20 library with tests; have the neckbeard-nate and
concerned-carl agents review it; everything must build and all tests
must pass."

The shape of the queue is the lesson. The runner has no loops, so the
review-fix cycle is unrolled: one implementation, one review round, one
fix, a second review round, and a gate that reads the second round's
verdicts. Builds and tests are scripts between every model step, so
the model never gets to say "the tests pass" without a script having
checked.

    mkdir /tmp/spsc && cd /tmp/spsc
    cp -R $WORK_RUNNER/examples/spsc-queue/queue .work/spsc
    work-runner run .work/spsc

The reviewers are the `neckbeard-nate` and `concerned-carl` personas
shipped in `work-runner/agents/`, and the implementer and fixer run as
`cpp-polymath`; nothing has to be installed in the project. Reviewer
items also load the shipped `review-format` and `cpp-standards`
skills (`skills:` in the header), so the review shape the gate greps
and the C++ rules the bench enforces come from one place. Each review
is the model's final message, which the runner saves as
`.run/<item>/response.md`; the fix item and the gate read it from
there through the `{{WR_WORK_DIR}}` placeholder. The example needs
cmake and a C++20 compiler.
