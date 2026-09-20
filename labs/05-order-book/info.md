# Brief: messages and the order book

The data half of a limit-order matching engine: the messages that
enter and leave it, the strong types those messages are made of, a
per-symbol order book that admits, cancels and modifies resting
orders, and an engine facade that owns one book per symbol and routes
each inbound message to it. Header-only unless a `.cpp` is clearly
better, in the project from lab 01, following its `CLAUDE.md`. The
outbound side uses the `SpscQueue` from lab 02.

**No matching in this lab.** A new order that would cross the book
rests on its side like any other. Trades and top-of-book snapshots
are produced in lab 06; here the engine emits nothing.

## Given: the strong types

One header per type under `include/<name>/`, each a `struct` with a
single `value` member and a defaulted `operator<=>`, except `Side`.

| Type | Underlying | Meaning |
|---|---|---|
| `Symbol` | `std::uint32_t` | instrument handle; one book per symbol |
| `OrderId` | `std::uint64_t` | engine-assigned on admission, unique across all books |
| `ClientOrderId` | `std::uint64_t` | gateway-assigned; (`GatewayId`, `ClientOrderId`) is unique per live order |
| `GatewayId` | `std::uint16_t` | which gateway sent the order (exists if lab 04 was done) |
| `TradeId` | `std::uint64_t` | engine-assigned per trade |
| `Price` | `std::int64_t` | integer ticks; no floating point anywhere |
| `Quantity` | `std::uint64_t` | lots |
| `SequenceNumber` | `std::uint64_t` | stamp on every outbound message (exists if lab 04 was done) |
| `TimestampNs` | `std::int64_t` | nanoseconds since the Unix epoch |
| `Side` | `enum class Side : std::uint8_t { bid, ask }` | book side; `bid`/`ask` rather than `buy`/`sell` because the engine reasons about sides |

## Given: the messages

Every message is a value type: strong types only, no pointers, no
references, no owning containers, so a message can be copied into a
queue slot and remain self-contained. Fields and meanings are fixed.

```
NewOrder      received_at: TimestampNs, gateway: GatewayId,
              client_order_id: ClientOrderId, symbol: Symbol,
              side: Side, price: Price, quantity: Quantity
              Add a resting or marketable limit order.

ModifyOrder   received_at: TimestampNs, order_id: OrderId,
              new_price: Price, new_quantity: Quantity
              Replace price and/or quantity. Reducing quantity keeps
              queue priority; increasing quantity or changing price
              loses it.

CancelOrder   received_at: TimestampNs, order_id: OrderId
              Remove an admitted order.

Inbound       std::variant<NewOrder, ModifyOrder, CancelOrder>

Trade         event_time: TimestampNs, seqno: SequenceNumber,
              trade_id: TradeId, symbol: Symbol, price: Price,
              quantity: Quantity, maker order id, taker order id,
              aggressor_side: Side
              A match. aggressor_side is the side of the order that
              crossed (the taker); the other side was resting (the
              maker). Produced in lab 06; defined here.

TopOfBook     event_time: TimestampNs, seqno: SequenceNumber,
              symbol: Symbol, best bid price and quantity,
              best ask price and quantity
              A side with no resting interest reports Quantity{0};
              its price is unspecified and consumers gate on the
              quantity first. Produced in lab 06; defined here.

Outbound      std::variant<Trade, TopOfBook>
```

**The types of four fields are open**, because as written they break
the project rule that no two public members of a type share a type:
`Trade` has two `OrderId` members, and `TopOfBook` has two `Price`
and two `Quantity` members. See open decision 1.

## Given: the order book

```cpp
namespace me {

/// A per-symbol limit-order book. One instance per Symbol.
class OrderBook
{
public:
    explicit OrderBook(Symbol symbol) noexcept;

    /**
     * Rests an order at (side, price, quantity) and returns the
     * OrderId assigned to it. Fresh: never previously returned by any
     * OrderBook for any symbol. A value; nothing exposes storage.
     * (In lab 06 a marketable order matches first and only the
     * remainder rests. Not here.)
     */
    OrderId admit(Side side, Price price, Quantity quantity);

    /**
     * Removes an admitted order. Returns the quantity resting when
     * the cancel took effect, or std::nullopt when the order is not
     * in the book: already cancelled, already filled, or never
     * admitted. A second cancel of the same id is std::nullopt.
     */
    std::optional<Quantity> cancel(OrderId id);

    /**
     * Replaces price and quantity. Keeps queue priority only when
     * the price is unchanged and the quantity decreases; otherwise
     * the order goes to the back of its new level. Returns the
     * quantity that was resting before the change, or std::nullopt
     * when the order is not in the book.
     */
    std::optional<Quantity> modify(OrderId id, Price new_price, Quantity new_quantity);

    Symbol symbol() const noexcept;
};

} // namespace me
```

## Given: the engine facade

```cpp
namespace me {

inline constexpr std::size_t outbound_queue_capacity = 4096;
using OutboundQueue = SpscQueue<Outbound, outbound_queue_capacity>;

/**
 * Owns one OrderBook per Symbol, created on first use, and routes
 * each Inbound to it: NewOrder -> admit, ModifyOrder -> modify,
 * CancelOrder -> cancel. Return values are discarded in this lab.
 *
 * The outbound queue is injected by reference and owned by the
 * caller, which must keep it alive longer than the engine. In this
 * lab nothing is pushed to it.
 */
class MatchingEngine
{
public:
    explicit MatchingEngine(OutboundQueue & outbound) noexcept;

    /// Processes one inbound message. Takes it by value.
    void accept(Inbound msg);
};

} // namespace me
```

`Symbol` is the map key as itself; it is not converted to an integer
or a string to be a key. `OrderBook` is not default-constructible, so
the map must cope (`std::map::try_emplace` does). A `ModifyOrder` and
a `CancelOrder` carry only an `OrderId`, so the engine needs a way to
find the book that holds an id.

## Given: the invariants

1. Every `OrderId` returned by `admit`, from any book, is distinct.
2. `cancel` of an id returns a value the first time and
   `std::nullopt` every time after.
3. `modify` then `cancel` returns the modified quantity, not the
   original.
4. Within one price level, orders are in admission order, except
   that a modify which loses priority moves the order to the back.
5. The engine never exposes a book, an order, or a reference to
   either. Messages in, messages out, nothing in between.

## Given: the tests

Same layout and wrappers as lab 01.

- **Examples** for `OrderBook`, one per invariant and per sentence
  in the contract above: symbol reported; fresh ids; cancel of
  admitted returns its quantity; cancel of unknown is nullopt; cancel
  twice; modify with reduced quantity returns the previous quantity;
  modify of unknown is nullopt; modify that changes price then
  cancel returns the new quantity.
- **Examples** for `MatchingEngine`: two symbols route to two books
  (observable through a later cancel returning a quantity for the
  right symbol); cancel through the engine of an id admitted through
  the engine.
- **Properties**: for any number of admits, all ids are distinct;
  for any admit followed by any sequence of cancel and modify on that
  id, the first cancel returns a value and every later one is
  nullopt; admit, modify to `q'`, cancel returns `q'`.

Every literal in a test is wrapped in its strong type. A test that
reads `book.admit(Side::bid, 100, 10)` is wrong.

## Out of scope

- **The cancel fairy is not implemented. Orders are assumed to live
  forever unless explicitly cancelled by an inbound `CancelOrder`.**
  Day-order expiry, time-in-force, self-match prevention and
  risk-driven mass cancels are all the cancel fairy's job and are out
  of scope for labs 05 to 07. The PRD says this in these words.
- Matching, trade generation, top-of-book publication (lab 06).
- Market orders, hidden orders, pro-rata allocation, more than one
  level of depth in `TopOfBook`.
- Threads. Everything here runs on the caller's thread.

## Open decisions

1. **The doubled field types.** `Trade` needs two order ids that
   cannot be swapped; `TopOfBook` needs a bid and an ask price and a
   bid and an ask quantity. Distinct wrapper types (`MakerOrderId`,
   `TakerOrderId`, `BidPrice`, `AskPrice`, `BidQuantity`,
   `AskQuantity`), or a tagged level struct (`BidLevel`, `AskLevel`,
   each holding a `Price` and a `Quantity`), or another shape that
   the reviewers' swap test accepts. The reviewers will enforce the
   rule; choose with that in mind.
2. **Book storage**: ordered map of price to a FIFO of orders, with
   an id index, or something else. Whatever it is, priority within a
   level is observable only through cancel and modify results in this
   lab, and through trades in the next.
3. **Finding a book from an `OrderId`** in the engine: a reverse map
   from id to symbol, or ids that encode their symbol.
4. **`OrderId` allocation**: a single counter shared by all books
   (invariant 1 says across all books).
5. **Review bench and rounds.** Default: the full bench, two rounds.
   The cheaper choice is neckbeard-nate and concerned-carl.
