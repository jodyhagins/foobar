# Brief: SPSC queue

A bounded, lock-free ring buffer with exactly one producer thread and
exactly one consumer thread. It is the transport between the matching
engine and everything around it in labs 05 to 07. Header-only, in the
project from lab 01, following the rules in that project's `CLAUDE.md`.

## Given: the contract

The public surface is fixed. Names, template parameters and
semantics below are not open; the implementation behind them is.

```cpp
namespace me {

/**
 * Lock-free SPSC ring buffer.
 *
 * Threading contract
 *   - Exactly one thread (the producer) may call try_push and
 *     try_emplace.
 *   - Exactly one thread (the consumer) may call try_pop.
 *   - Any other concurrent access pattern is undefined behaviour.
 *   - Construction and destruction happen on one thread with no
 *     producer or consumer activity in flight, and the caller
 *     establishes a synchronisation edge (typically thread::join)
 *     between the last try_push / try_pop and the destructor.
 *
 * Template parameters
 *   T         Must be nothrow-move-constructible and
 *             nothrow-destructible (static_assert), because the
 *             queue cannot recover from a throwing move without
 *             breaking its lock-free guarantee.
 *   Capacity  Maximum number of elements held at any instant. A
 *             power of two and at least 2 (static_assert). A queue
 *             of capacity 1024 is a different type from one of 2048.
 */
template <class T, std::size_t Capacity>
class SpscQueue
{
public:
    using value_type = T;
    static constexpr std::size_t capacity = Capacity;

    enum class PushResult : bool { full, pushed };

    /// Empty queue, ready for one producer and one consumer.
    SpscQueue();

    /// Destroys any elements still present. See the threading contract.
    ~SpscQueue();

    SpscQueue(SpscQueue const &) = delete;
    SpscQueue(SpscQueue &&) = delete;
    SpscQueue & operator=(SpscQueue const &) = delete;
    SpscQueue & operator=(SpscQueue &&) = delete;

    /**
     * Publishes by move. On `full`, no move has happened: the
     * caller's object is intact and may be retried. On `pushed`,
     * exactly one later try_pop by the consumer observes this value.
     * Producer thread only.
     */
    PushResult try_push(T && value);

    /**
     * Publishes by copy. On `full`, `value` is untouched. May throw
     * whatever T's copy constructor throws; a throw leaves the queue
     * unchanged. Producer thread only.
     */
    PushResult try_push(T const & value);

    /**
     * Constructs in place. On `full`, no T is constructed. A throw
     * from T's constructor leaves the queue unchanged. Producer
     * thread only.
     */
    template <class... Args>
    PushResult try_emplace(Args &&... args);

    /**
     * Consumes one element by value; std::nullopt if the queue was
     * empty at the moment of the call. No pointer or reference into
     * queue storage is ever returned. Consumer thread only.
     */
    std::optional<T> try_pop();
};

} // namespace me
```

What is deliberately absent, and must stay absent:

- **No `size()` and no `empty()`.** Any count visible to both threads
  is a race, and a value that is wrong by the time it is read is a
  lie. Models like to add these "for convenience"; the reviewers will
  flag them, and the gate will not pass with them present.
- **No `front()`, `peek()`, or anything returning `T &` or `T *`.**
- **No `init()`, `reset()`, `clear()`.** Construction is the only
  way to get an empty queue.

## Given: the tests

Tests live in `tests/`, use the two wrappers under `tests/testing/`,
and get their own binary and `add_test` line in `tests/CMakeLists.txt`,
in the shape of the smoke test from lab 01.

- **Examples** (doctest): empty pop returns nullopt; push then pop
  returns the value; a full queue reports `full` and the caller's
  object is intact; wrap-around past the end of the storage; values
  pop in push order; a move-only `T` works; element destructors run
  exactly once each (a counting type).
- **Properties** (`rc::doctest::check`): for any sequence of push and
  pop operations, the queue behaves like a `std::deque` bounded at
  `Capacity`; for any list of values that fits, popping returns
  exactly that list.
- **Two threads**: a producer moves at least one million integers to
  a consumer; every value arrives, in order. Must finish in a few
  seconds and run clean under TSan.

## Out of scope

- Multiple producers or multiple consumers. That is lab 04.
- Blocking or waiting operations. Callers spin or yield; the queue
  never sleeps.
- Dynamic capacity, or heap storage of the ring.
- Batch push or pop.

## Open decisions

1. **Slot storage.** How a `T` lives in the ring without being
   default-constructed: a union slot with `std::construct_at` /
   `std::destroy_at`, or something else. (`std::aligned_storage` is
   deprecated.)
2. **Cache-line separation** of the producer's and consumer's
   indices: `std::hardware_destructive_interference_size`, a constant
   64, or a configure-time value. Note that GCC warns on the standard
   constant in ABI positions.
3. **Cached indices.** Whether each side keeps a cached copy of the
   other side's index to avoid a shared load on the fast path.
4. **The property test's reference model** and how the operation
   sequence is generated.
5. **Review bench and rounds.** The default is neckbeard-nate and
   concerned-carl, two rounds.
