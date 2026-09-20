# Brief: matching

The behaviour half of the engine. A marketable incoming order crosses
resting interest on the opposite side in price-time priority and
produces trades; the engine stamps every outbound message with a
sequence number and publishes it to the queue it was given; after any
change to the best level it publishes one top-of-book snapshot.
Builds on lab 05 in place, following the project's `CLAUDE.md`.

## Given: what is frozen

The public declarations from lab 05 do not change: the strong types,
the messages, `OrderBook`'s public member functions and
`MatchingEngine`'s. Private members, new private helpers, new
headers under `include/<name>/detail/`, and new `.cpp` files are
fine. The cancel fairy stays unimplemented.

## Given: the matching rules

- **Price-time priority.** Best price first; within a price level,
  first in, first matched.
- **Trade price is the resting price** (the maker's), never the
  aggressor's.
- **Trade quantity** is the smaller of the resting remainder and the
  aggressor's remainder.
- **`aggressor_side`** is the side of the order that just arrived
  (the taker).
- **Partial fill of a resting order** reduces it in place; its
  priority is unchanged, because its quantity only went down.
- **Full fill** removes the resting order from the book. A later
  cancel of it is `std::nullopt`.
- **The unfilled remainder** of the aggressor rests on its own side
  at its limit price, at the back of that level.
- **A modify that loses priority** (price change, or quantity
  increase) is a cancel of the old order followed by an admit of the
  new one, which may cross. A modify that keeps priority never
  crosses, because the order was already resting without crossing.
- **Cancel of a partially filled order** returns the remaining
  quantity, not the original.

## Given: publication

- `MatchingEngine` holds a `SequenceNumber` counter starting at 1.
  Every `Outbound` it publishes gets the next value; the counter
  lives in the engine, not in a book, so it is monotonic across
  symbols.
- Publication is `outbound.try_push(msg)`. When the queue is full the
  message is dropped and processing continues; the engine never
  waits on the outbound side. A line on `stderr` when that happens
  is fine.
- `TradeId` is engine-assigned, starting at 1, monotonic.
- After every `accept` that changed the best bid or the best ask of
  the affected symbol, the engine publishes exactly one `TopOfBook`
  reflecting the final state, after any trades from that `accept`.
  One `accept` that produces N trades and changes the top yields
  `Trade × N, TopOfBook`, never N snapshots.
- An `accept` that leaves both best levels unchanged (a new order
  behind the best, a cancel deep in the book) publishes no
  `TopOfBook`.
- An empty side reports `Quantity{0}` and a price the consumer must
  not read; `Price{0}` is fine.
- The book produces trades; the engine stamps and publishes them. The
  book's matching routine returns its trades to the engine by value
  (a vector of trades is fine). No pointer or reference to a resting
  order leaves the book.

## Given: the tests

Same layout and wrappers as lab 01. The unit tests are written
**before** the implementation and must fail at that point; a script
in the queue checks that they fail, and a later one checks that they
pass.

- **Examples**, each one scenario from the rules, driven through
  `MatchingEngine::accept` and observed through the outbound queue
  and through later cancels: bid crosses one ask exactly; bid
  partially fills one ask, the ask's remainder still rests with its
  priority; bid walks two asks at two prices, two trades at the
  respective resting prices, best price first; bid exceeds all
  resting asks, the remainder rests; cancel of a partially filled
  order returns the remainder; modify that loses priority re-crosses;
  first bid publishes a `TopOfBook`; a bid behind the best publishes
  none; a full fill that empties a side publishes `Quantity{0}` for
  it; an `accept` with two trades drains as `[Trade, Trade,
  TopOfBook]`; sequence numbers across a drain are strictly
  increasing.
- **Property, worked in full**: for any script of new orders with
  random sides, prices and quantities, the sum of `Trade.quantity`
  over the whole drain equals what a reference price-time simulator
  written in the test says should have crossed. Keep the reference
  under forty lines.
- **Properties**: every trade's `aggressor_side` equals the side of
  the inbound order that caused it; every trade's price equals the
  resting order's price at match time.

The queue in every test is declared before the engine, so it is
destroyed after it. Tests never read book internals; if a test needs
to know what rests, it cancels and counts the non-empty results.

## Out of scope

- The cancel fairy, still. Orders live until cancelled.
- Market orders, hidden orders, pro-rata, self-match prevention,
  depth beyond level one, order-to-trade ratio limits.
- Threads. Lab 07.
- Changing any lab 05 public declaration. If the design needs one
  changed, that is a finding for the summary, not a change.

## Open decisions

1. **Where the matching loop lives** in the book, and what it
   returns to the engine (a vector of `Trade` without `seqno` and
   `trade_id`, which the engine fills in; or a smaller "fill" struct
   the engine turns into a `Trade`).
2. **Top-of-book change detection**: compare a snapshot before and
   after each `accept`, or have the book report whether its best
   level changed.
3. **Event time**: `received_at` of the inbound message, or a clock.
4. **The reference model** for the conservation property, and how the
   order script is generated so that a useful fraction of orders
   cross.
5. **Review bench and rounds.** Default: the full bench, two rounds.
