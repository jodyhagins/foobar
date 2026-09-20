# Brief: wiring and the end-to-end run

Three pieces of glue and one program. A runner pulls inbound messages
from a queue and feeds the engine on a thread the caller owns. A
consumer program constructs the pipeline, drives it with a fixed
script of orders from a gateway thread, prints every trade and
top-of-book snapshot, and exits. An end-to-end test does the same
with assertions, under TSan. Builds on labs 02, 05 and 06 in place,
following the project's `CLAUDE.md`.

The pipeline:

```
gateway thread  --> InboundQueue  --> EngineRunner::run (engine thread)
                                              |
                                      MatchingEngine::accept
                                              |
                                      OutboundQueue --> consumer (main thread)
```

The inbound transport is the lab 02 `SpscQueue`, which allows exactly
one gateway thread. The lab 04 `Sequencer`, if it exists, can stand
in for it and allow several; see open decision 1.

## Given: what is frozen

Every public declaration from labs 05 and 06. The cancel fairy is
still not implemented.

## Given: the runner

```cpp
namespace me {

inline constexpr std::size_t inbound_queue_capacity = 4096;
using InboundQueue = SpscQueue<Inbound, inbound_queue_capacity>;

/**
 * Pulls Inbound messages from the inbound queue and hands each to
 * the engine. Owns no thread: the caller spawns one and invokes run()
 * on it. Holds references, never copies. Only one EngineRunner may
 * exist per inbound queue, because it is the queue's single consumer.
 */
class EngineRunner
{
public:
    EngineRunner(InboundQueue & inbound, MatchingEngine & engine, StopSignal & stop) noexcept;

    /**
     * Loops on the calling thread: pop, accept, repeat. When a pop
     * finds nothing, yields (std::this_thread::yield) rather than
     * spinning hot. Returns once the stop signal is set AND two
     * consecutive pops found nothing, so a producer that stopped
     * after a final push is fully drained. Never throws out; an
     * exception from accept is logged to stderr and the loop
     * continues.
     */
    void run();
};

} // namespace me
```

`StopSignal` is a type to define: it is set once by the owner to say
"producers have stopped", read many times by the runner, and it
follows the no-`bool` rule. An atomic of an `enum class : bool` is one
answer; see open decision 2. The writer uses release and the reader
uses acquire; nothing stronger without a reason in a comment.

## Given: the consumer program

`apps/consumer/main.cpp`, built as `consumer` by a new
`apps/CMakeLists.txt` that the top-level `CMakeLists.txt` adds. It:

1. Constructs the outbound queue, the inbound queue, the engine (with
   the outbound queue), the stop signal, and the runner. The queues
   outlive everything that uses them.
2. Starts the engine thread running `runner.run()`.
3. Starts a gateway thread that pushes a fixed script of `NewOrder`
   messages for one symbol: an ask, a bid that crosses it, a bid that
   rests. Then sets the stop signal.
4. On the main thread, pops the outbound queue and prints one line
   per message: `Trade seq=… price=… qty=…` or
   `TopOfBook seq=… bid_qty=… ask_qty=…`. It knows how many messages
   the script produces and stops after that many. Yields between
   empty pops.
5. Joins both threads and exits 0.

It must print at least one `Trade` line and finish in well under five
seconds. It is run by a script in the queue under the `tsan` preset
with a timeout, and that script fails on any `WARNING:
ThreadSanitizer` line on stderr.

## Given: the tests

Same layout and wrappers as lab 01. A new test binary for the runner.

- **Runner example**: push three non-crossing orders, each improving
  the best price, start the runner on a thread, set stop, join; the
  outbound queue then holds the three `TopOfBook` messages the engine
  publishes for them.
- **End to end**: same construction as the program, driven from the
  test with a deterministic script long enough to produce several
  trades. The main thread drains until the runner has stopped and
  two consecutive pops are empty. Asserts: every trade's maker and
  taker ids were issued by the engine (collected from the script's
  effects, not from book internals); every `seqno` across the drain
  is strictly increasing; the trade count matches the reference
  model from lab 06 applied to the script. No `sleep`. A watchdog
  thread with a five-second deadline prints the state and aborts if
  the test hangs, so a stuck test is a failure and not a wait.
- Everything runs clean under TSan. No suppressions, no test excluded
  from the TSan preset.

## Out of scope

- The cancel fairy.
- Cross-process transport: shared memory, sockets, files. Everything
  is one process.
- Back-pressure. The gateway drops or retries on a full inbound
  queue; the engine drops on a full outbound queue, as in lab 06.
- Multiple engine threads or multiple engines.
- Printing anything but the two message kinds.

## Open decisions

1. **Inbound transport**: the lab 02 `SpscQueue` with one gateway
   thread (the default), or the lab 04 `Sequencer` with two or more
   gateway threads, in which case `EngineRunner` takes the sequencer
   and `try_claim` replaces `try_pop`, and the end-to-end test uses
   two gateways.
2. **The stop signal's type** under the no-`bool` rule.
3. **How the end-to-end test knows the drain is complete** without a
   sleep: a count from the reference model, or stop-plus-two-empties.
4. **What the consumer prints for the price on an empty side**
   (nothing, since consumers gate on quantity).
5. **Review bench and rounds.** Default: the full bench, two rounds.
