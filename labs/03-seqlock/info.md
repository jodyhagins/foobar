# Brief: seqlock array

A fixed-size array of slots. Each slot publishes a value of a
trivially copyable type from exactly one writer to any number of
readers, using a sequence counter so a reader can detect that it
sampled the slot mid-write and try again. Header-only, in the project
from lab 01, following that project's `CLAUDE.md`.

## Given: the contract

```cpp
namespace me {

/// Index of a slot in a SeqlockArray. A strong type, never a raw size.
struct SlotIndex
{
    std::uint32_t value;
    auto operator<=>(SlotIndex const &) const = default;
};

/// How many times a reader retries before giving up.
struct RetryLimit
{
    std::uint32_t value;
};

/**
 * Threading contract (strict)
 *   - Exactly one writer thread per slot. Different slots may be
 *     written from different threads at the same time. A writer
 *     does not migrate between slots.
 *   - Any number of reader threads may call try_snapshot on any
 *     slot at any time.
 *   - Construction and destruction are single-threaded, outside
 *     any writer or reader activity.
 *
 * Template parameters
 *   T       Trivially copyable (static_assert): a read is a
 *           memcpy-equivalent sample that may observe a partly
 *           written slot, which is then detected and retried.
 *   NSlots  Greater than zero (static_assert).
 */
template <class T, std::size_t NSlots>
class SeqlockArray
{
public:
    using value_type = T;
    static constexpr std::size_t slot_count = NSlots;
    static constexpr RetryLimit default_retry_limit{8};

    /// Every slot starts "never written"; try_snapshot on it is nullopt.
    SeqlockArray();
    ~SeqlockArray() = default;

    SeqlockArray(SeqlockArray const &) = delete;
    SeqlockArray(SeqlockArray &&) = delete;
    SeqlockArray & operator=(SeqlockArray const &) = delete;
    SeqlockArray & operator=(SeqlockArray &&) = delete;

    /**
     * Publishes `value` into `slot`.
     * Precondition: slot.value < NSlots; the calling thread is the
     * sole writer for this slot for the array's lifetime.
     * Postcondition: later snapshots of this slot return this value
     * or a later one, and never report a torn state as success.
     */
    void store(SlotIndex slot, T value);

    /**
     * Returns a consistent copy of the slot's value, or std::nullopt
     * when the slot has never been written or the reader could not
     * observe a consistent snapshot within `retries` attempts. T is
     * returned by value; nothing exposes the slot storage.
     * Precondition: slot.value < NSlots.
     * Postcondition: a returned value is byte-identical to some value
     * passed to store() for this slot.
     */
    std::optional<T> try_snapshot(
        SlotIndex slot,
        RetryLimit retries = default_retry_limit) const;
};

} // namespace me
```

## Given: the tests

Same layout and wrappers as lab 01.

- **Examples**: never-written slot is nullopt; store then snapshot
  returns the value; a second store replaces the first; slots are
  independent; retry limit of zero on a written slot still returns
  the value when there is no writer active.
- **Property**: for any sequence of values stored into one slot, a
  snapshot after the sequence returns the last value.
- **Concurrent** (the one that matters): one writer thread stores a
  large `T` (for example an array of 16 `std::uint64_t` all equal to
  the same counter) as fast as it can; several reader threads
  snapshot continuously and assert that every successful snapshot is
  internally consistent (all elements equal). Runs clean under TSan,
  and finishes in a few seconds.

## Out of scope

- Multiple writers on one slot.
- Blocking readers, or readers that wait for a write.
- Any `T` that is not trivially copyable.

## Open decisions

1. **Reader's memory ordering**: the classic acquire on the sequence
   before the copy, and the fence-plus-relaxed-load after it, or a
   variant. Whatever is chosen must be explained in a comment at the
   access, and TSan must be clean without suppressions.
2. **Copy mechanism**: `std::memcpy` into a local, or a copy of `T`
   through a `std::atomic_ref`-style word-by-word sample.
3. **Slot padding**: whether each slot gets its own cache line.
4. **Review bench and rounds.** Default: neckbeard-nate and
   concerned-carl, two rounds.
