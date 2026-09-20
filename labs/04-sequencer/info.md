# Brief: sequencer

A serializer in front of the matching engine. Several gateways, each
on its own thread, submit inbound payloads; one consumer thread claims
them one at a time; each admitted payload is stamped with a sequence
number that is unique and strictly increasing in claim order.
Header-only, in the project from lab 01, following its `CLAUDE.md`,
and using the `SpscQueue` from lab 02 unchanged.

## Given: the strong types

Create each in its own header under `include/<name>/` if it does not
exist. Every one is a `struct` with a single `value` member and a
defaulted `operator<=>`.

| Type | Underlying | Meaning |
|---|---|---|
| `GatewayId` | `std::uint16_t` | which gateway submitted; `0 .. GatewayCount-1` |
| `GatewayCount` | `std::uint16_t` | how many gateways a sequencer accepts |
| `SequenceNumber` | `std::uint64_t` | the stamp; starts at 1 |

## Given: the contract

```cpp
namespace me {

/// A payload wearing its sequence number and the gateway that sent it.
/// Consumers receive this by value, never a pointer into the sequencer.
template <class Payload>
struct Sequenced
{
    SequenceNumber seq;
    GatewayId from;
    Payload msg;
};

/**
 * Multi-producer / single-consumer sequencer.
 *
 * Ordering guarantee
 *   If try_submit on gateway A completes strictly before try_submit
 *   on gateway B starts (happens-before in the C++ memory model),
 *   the SequenceNumber returned for A is strictly less than the one
 *   returned for B. Submissions that overlap in time may be ordered
 *   either way, and callers assume nothing about it.
 *
 * Threading contract
 *   - Each GatewayId is used by exactly one thread for the
 *     sequencer's lifetime; that thread calls try_submit.
 *   - Exactly one consumer thread calls try_claim.
 *   - Construction and destruction are single-threaded with
 *     nothing in flight.
 *
 * Template parameters
 *   Payload   Nothrow-move-constructible and nothrow-destructible.
 *   Capacity  In-flight bound between admission and consumption.
 *             A power of two, at least 2.
 */
template <class Payload, std::size_t Capacity>
class Sequencer
{
public:
    using value_type = Payload;
    using sequenced_type = Sequenced<Payload>;

    enum class SubmitResult : bool { full, admitted };

    /// Accepts submissions from gateways 0 .. gateways.value - 1.
    /// Precondition: gateways.value > 0.
    explicit Sequencer(GatewayCount gateways);
    ~Sequencer();

    Sequencer(Sequencer const &) = delete;
    Sequencer(Sequencer &&) = delete;
    Sequencer & operator=(Sequencer const &) = delete;
    Sequencer & operator=(Sequencer &&) = delete;

    /**
     * Admits a payload from `from`. Returns the assigned sequence
     * number, or std::nullopt when the in-flight buffer was full, in
     * which case `msg` is untouched and no sequence number is used.
     * Precondition: from.value < gateways.value; the calling thread
     * is the sole caller for this GatewayId.
     */
    std::optional<SequenceNumber> try_submit(GatewayId from, Payload msg);

    /**
     * Claims the next sequenced payload, or std::nullopt when none is
     * ready. The returned value owns its payload.
     * Postcondition: the `seq` of successive returned values is
     * strictly increasing, with no gaps.
     */
    std::optional<sequenced_type> try_claim();
};

} // namespace me
```

## Given: the tests

Same layout and wrappers as lab 01.

- **Examples**: claim on empty is nullopt; one submit then one claim
  returns the payload with `seq == 1` and the right `from`; two
  submits from one gateway claim in order with `seq` 1 then 2; a full
  buffer reports nullopt and the payload is untouched; after a full
  report, one claim makes room for exactly one more submit.
- **Property**: for any interleaving of submits from several gateways
  on one thread, the claimed sequence numbers are `1, 2, 3, ...` with
  no gaps and each claimed `from` matches its submit.
- **Concurrent**: at least three gateway threads each submit a
  deterministic script of payloads carrying (gateway, local index);
  one consumer claims until every payload arrived. Assert that
  sequence numbers are strictly increasing, that each gateway's
  payloads arrive in that gateway's submit order, and that nothing is
  lost or duplicated. Clean under TSan, bounded in time.
- **Ordering**: a test that submits on gateway A, joins or otherwise
  synchronises, then submits on gateway B, and asserts `seq(A) <
  seq(B)`.

## Out of scope

- Fairness between gateways under contention.
- Persisting or replaying the sequence.
- Multiple consumers.
- Changing `SpscQueue` from lab 02. If it needs to change, that is a
  finding to report, not a change to make here.

## Open decisions

1. **Architecture**: one `SpscQueue` per gateway with the consumer
   merging them and stamping on claim, or a single shared ring with a
   compare-and-swap on the sequence counter at submit time. Each
   changes where the sequence number is assigned and what the
   ordering guarantee costs. The per-gateway-queue design satisfies
   the guarantee as written; think about why before choosing the
   other.
2. **Where the stamp happens** (submit or claim), and how the
   ordering guarantee is preserved by that choice.
3. **Merge policy** in the consumer, if there are per-gateway queues:
   round-robin, or oldest-first by a submit timestamp.
4. **Review bench and rounds.** Default: neckbeard-nate and
   concerned-carl, two rounds.
