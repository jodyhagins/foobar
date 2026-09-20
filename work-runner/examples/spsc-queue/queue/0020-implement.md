---
title: Implement the SPSC queue and its tests
provider: claude
model: claude-sonnet-5
agent: cpp-polymath
skills: cpp-standards
timeout: 1800
status: todo
---
Implement a single-producer single-consumer queue in this C++20 project.

Write exactly these two files (CMakeLists.txt already references them;
do not edit it):

1. `include/spsc/queue.hpp`, header only, namespace `spsc`:
   - `template <class T, std::size_t Capacity> class queue` where
     Capacity is a power of two, enforced with `static_assert`.
   - Lock-free ring buffer over `std::array` storage, with head and
     tail `std::atomic<std::size_t>` on separate cache lines
     (`alignas(std::hardware_destructive_interference_size)` if
     available, else 64).
   - The interface follows the cpp-standards skill you load, which
     forbids `bool`, so the results are enums:
     `enum class push_status : bool { full, pushed }` and
     `enum class pop_status : bool { empty, popped }`, nested in the
     class. Members: `push_status try_push(T const&)`,
     `push_status try_push(T&&)`, `pop_status try_pop(T&)`,
     `std::size_t size() const`, and
     `static constexpr std::size_t capacity()`. Both `try_push`
     overloads and `try_pop` are `[[nodiscard]]`.
   - Correct acquire/release ordering, one producer thread and one
     consumer thread only; document that contract in a comment.
   - No dynamic allocation, no exceptions thrown by the queue itself.
2. `tests/spsc_queue_test.cpp`, a plain `main` returning non-zero on
   the first failure (no test framework), covering: empty and full
   behaviour, wrap-around past the end of the storage, values popping
   in push order, and a two-thread test that moves 1,000,000 integers
   from a producer to a consumer and checks every value arrives in
   order. Keep the threaded test under a few seconds.

Then build and run the tests yourself before finishing:

    cmake -S . -B build -DCMAKE_BUILD_TYPE=Debug && cmake --build build && ctest --test-dir build --output-on-failure

The next items in this queue run the same commands and fail the queue
if they fail. Finish with a short summary of the design choices.
