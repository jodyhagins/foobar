---
name: cpp-standards
description: The C++ rules every reviewer on the bench checks and every implementer must meet. Load before writing or reviewing C++ in a project that follows them.
---

# C++ standards: the shared focus

These are checked by every reviewer, on purpose, because models
under-weight them. Flag a violation even if another reviewer will too.

- **Strong semantic types (CRITICAL).** Every value with meaning gets
  its own type. No naked `int`, `std::string`, `pid_t` and friends in a
  public interface. Same underlying type with two meanings means two
  strong types. The one exception is a truly universal operation such
  as `size()` returning `std::size_t`. No two public members or
  parameters of a function may share a type.
- **No `bool` (CRITICAL).** Never as a parameter, return type or
  member. Use `enum class X : bool { no, yes }` or `safe_bool`.
- **`explicit` on every constructor (HIGH)** except copy and move:
  `explicit`, `explicit(false)` when implicit conversion is intended,
  or `explicit(expr)` on wrapping and forwarding constructors.
- **`noexcept` policy (HIGH).** Copy and move constructors and
  assignments must be `noexcept`. Generic code uses
  `noexcept(noexcept(...))`. Nothing else is `noexcept`.
- **`[[nodiscard]]` (MEDIUM)** only where ignoring the return is
  almost certainly a bug, which includes most side-effect-free
  functions. If a reasonable caller would have to cast to `void`, it
  does not belong.
- **Terminology.** "Member function", never "method".

Approved patterns that must not be flagged:

```cpp
struct Foo {                                   // nested enum constants
    enum class Kind : std::uint8_t { queue, tcp, udp };
    static constexpr Kind queue = Kind::queue;
    static constexpr Kind tcp = Kind::tcp;
};

class INode {                                  // NVI: virtuals are never public
public:
    virtual ~INode() = default;
    void execute() { do_execute(); }
private:
    virtual void do_execute() = 0;
};
```

Non-thread-safe is the C++ default; do not ask for documentation of
it. Validation belongs in the type that owns the invariant, so
similar validation in two types is not duplication.
