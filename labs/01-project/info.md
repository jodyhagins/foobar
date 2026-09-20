# Brief: the project

A CMake C++20 project that every later lab adds to. Header-only
library under `include/`, tests under `tests/`, doctest and rapidcheck
fetched by CMake and pinned to commits, one sanitizer per build
directory selected by preset.

This brief was built and tested as written: the smoke test passes
under the `debug` (ASan), `tsan` and `ubsan` presets with AppleClang
17. Copy it; do not redesign it.

The name `me` appears throughout as the CMake project name, the
namespace, the include directory and the `ME_` option prefix. That
name is an open decision (see the end). Whatever is chosen replaces
`me` and `ME_` consistently everywhere.

## Given: layout

```
CMakeLists.txt
CMakePresets.json
CLAUDE.md
.gitignore
cmake/CompileOptions.cmake
cmake/Sanitizer.cmake
cmake/ThirdParty.cmake
include/me/version.hpp
src/CMakeLists.txt
tests/CMakeLists.txt
tests/main.cpp
tests/smoke_ut.cpp
tests/testing/doctest.hpp
tests/testing/rapidcheck.hpp
```

## Given: the files

`CMakeLists.txt`

```cmake
cmake_minimum_required(VERSION 3.27)

project(me
        VERSION 0.1.0
        DESCRIPTION "matching engine parts"
        LANGUAGES CXX)

list(PREPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/cmake")

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
if (NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Debug)
endif ()

option(ME_BUILD_TESTS "build the tests" ON)
set(ME_SANITIZER "asan" CACHE STRING "Sanitizer: none | asan | tsan | ubsan")
set_property(CACHE ME_SANITIZER PROPERTY STRINGS none asan tsan ubsan)

find_package(Threads REQUIRED)
include(FetchContent)
include(CTest)
include(Sanitizer)
include(CompileOptions)
include(ThirdParty)

me_apply_sanitizer("${ME_SANITIZER}")
me_create_compile_options_target()
link_libraries(me_compile_options)

add_subdirectory(src)
if (ME_BUILD_TESTS)
    add_subdirectory(tests)
endif ()
```

`cmake/Sanitizer.cmake`

```cmake
# One sanitizer per build directory.  Pick it with the preset.
function(me_apply_sanitizer flavour)
    if (flavour STREQUAL "none")
        return()
    elseif (flavour STREQUAL "asan")
        set(flags -fsanitize=address -fno-omit-frame-pointer)
    elseif (flavour STREQUAL "tsan")
        set(flags -fsanitize=thread)
    elseif (flavour STREQUAL "ubsan")
        set(flags -fsanitize=undefined -fno-sanitize-recover=all)
    else ()
        message(FATAL_ERROR "unknown sanitizer '${flavour}'")
    endif ()
    message(STATUS "Sanitizer: ${flavour}")
    add_compile_options(${flags} -g)
    add_link_options(${flags})
endfunction()
```

`cmake/CompileOptions.cmake`

```cmake
# Warnings for OUR code only.  Third-party code is fetched with -w
# (see ThirdParty.cmake) and never sees this target.
function(me_create_compile_options_target)
    add_library(me_compile_options INTERFACE)
    target_compile_options(me_compile_options INTERFACE
            -Wall -Wextra -pedantic
            -Wcast-align -Wcast-qual -Wconversion -Wformat=2
            -Wnon-virtual-dtor -Wold-style-cast -Woverloaded-virtual
            -Wsign-conversion -Wshadow -Wswitch-enum -Wundef -Wunused
            -Werror)
endfunction()
```

`cmake/ThirdParty.cmake`

```cmake
# Every dependency is pinned to a commit, with the ref it came from in
# a trailing comment, so two builds of the same commit are the same.
# Third-party code is compiled with warnings off; our warnings are on
# our targets only (CompileOptions.cmake).
set(_SAVED_CXX_FLAGS "${CMAKE_CXX_FLAGS}")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -w")

if (ME_BUILD_TESTS)
    # Debug info at -g3 so the sanitizer reports carry macro names.
    string(REGEX REPLACE "(^| )-g([0-9]?)( |$)" "\\1-g3\\3" tmp "${CMAKE_CXX_FLAGS_DEBUG}")
    set(CMAKE_CXX_FLAGS_DEBUG "${tmp}")

    message(STATUS "Processing third-party DocTest...")
    FetchContent_Declare(
            DocTest
            GIT_REPOSITORY https://github.com/jodyhagins/doctest.git
            GIT_TAG 75dfbdafddfb5356070aa8f1325d656971d9ed9f  # dev
            GIT_SHALLOW ON
            SYSTEM
            EXCLUDE_FROM_ALL
    )
    FetchContent_MakeAvailable(DocTest)

    message(STATUS "Processing third-party RapidCheck...")
    set(RC_ENABLE_DOCTEST ON)
    FetchContent_Declare(
            rapidcheck
            GIT_REPOSITORY https://github.com/jodyhagins/rapidcheck.git
            GIT_TAG e879d1872f54c42a85f834b8b42c415127e07ae8  # wjh-master
            GIT_SHALLOW ON
            SYSTEM
            EXCLUDE_FROM_ALL
    )
    FetchContent_MakeAvailable(rapidcheck)
endif ()

set(CMAKE_CXX_FLAGS "${_SAVED_CXX_FLAGS}")
```

`CMakePresets.json`

```json
{
  "version": 6,
  "configurePresets": [
    {
      "name": "base", "hidden": true, "generator": "Ninja",
      "binaryDir": "${sourceDir}/.build/${presetName}",
      "cacheVariables": { "CMAKE_BUILD_TYPE": "Debug" }
    },
    { "name": "debug", "inherits": "base", "cacheVariables": { "ME_SANITIZER": "asan" } },
    { "name": "tsan",  "inherits": "base", "cacheVariables": { "ME_SANITIZER": "tsan" } },
    { "name": "ubsan", "inherits": "base", "cacheVariables": { "ME_SANITIZER": "ubsan" } },
    { "name": "none",  "inherits": "base", "cacheVariables": { "ME_SANITIZER": "none" } }
  ],
  "buildPresets": [
    { "name": "debug", "configurePreset": "debug" },
    { "name": "tsan",  "configurePreset": "tsan" },
    { "name": "ubsan", "configurePreset": "ubsan" },
    { "name": "none",  "configurePreset": "none" }
  ],
  "testPresets": [
    { "name": "debug", "configurePreset": "debug", "output": { "outputOnFailure": true } },
    { "name": "tsan",  "configurePreset": "tsan",  "output": { "outputOnFailure": true } },
    { "name": "ubsan", "configurePreset": "ubsan", "output": { "outputOnFailure": true } },
    { "name": "none",  "configurePreset": "none",  "output": { "outputOnFailure": true } }
  ]
}
```

`src/CMakeLists.txt`

```cmake
# The library is header-only for now; labs add headers under include/me/.
add_library(me INTERFACE)
add_library(me::me ALIAS me)
target_include_directories(me INTERFACE "${PROJECT_SOURCE_DIR}/include")
target_link_libraries(me INTERFACE Threads::Threads)
```

`include/me/version.hpp`

```cpp
#ifndef ME_VERSION_HPP
#define ME_VERSION_HPP
namespace me {
inline constexpr char const * version = "0.1.0";
}
#endif
```

`tests/testing/doctest.hpp` — every test includes this, never
`<doctest/doctest.h>` directly, so the configuration is in one place.

```cpp
#ifndef ME_TESTING_DOCTEST_HPP
#define ME_TESTING_DOCTEST_HPP

#define DOCTEST_CONFIG_TREAT_CHAR_STAR_AS_STRING
#define DOCTEST_CONFIG_ORDER_BY_DEFAULT "rand"
#define DOCTEST_CONFIG_NO_SEED_IN_INTRO_DEFAULT false
#define DOCTEST_CONFIG_INITIALIZE_RAND_SEED

#include <doctest/doctest.h>

#endif
```

`tests/testing/rapidcheck.hpp` — every property test includes this.

```cpp
#ifndef ME_TESTING_RAPIDCHECK_HPP
#define ME_TESTING_RAPIDCHECK_HPP

#include "testing/doctest.hpp"
#include <rapidcheck/doctest.h>
#include <rapidcheck.h>

#endif
```

`tests/main.cpp`

```cpp
#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include "testing/doctest.hpp"
```

`tests/smoke_ut.cpp` — also the model for every property test in later
labs: a property is `rc::doctest::check("description", lambda)` inside
a `TEST_CASE`; the lambda's parameters are generated, and it asserts
with `RC_ASSERT`. There is no separate property macro in this fork.

```cpp
#include "me/version.hpp"
#include "testing/rapidcheck.hpp"

#include <string_view>

TEST_CASE("doctest runs")
{
    CHECK(std::string_view{me::version} == "0.1.0");
}

TEST_CASE("rapidcheck runs")
{
    rc::doctest::check("addition is commutative", [](int a, int b) {
        RC_ASSERT(a + b == b + a);
    });
}
```

`tests/CMakeLists.txt` — one test binary per component; later labs add
lines of the same shape. `rapidcheck_doctest` already carries
`rapidcheck`, so it is not linked twice.

```cmake
add_executable(smoke_ut main.cpp smoke_ut.cpp)
target_include_directories(smoke_ut PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(smoke_ut PRIVATE me::me doctest rapidcheck_doctest)
add_test(NAME smoke COMMAND smoke_ut)
```

`.gitignore`

```
.build/
.work/
labs
```

## Given: the commands

```
cmake --preset debug && cmake --build --preset debug && ctest --preset debug
cmake --preset tsan  && cmake --build --preset tsan  && ctest --preset tsan
cmake --preset ubsan && cmake --build --preset ubsan && ctest --preset ubsan
```

The first configure fetches and builds both frameworks; allow a few
minutes and a network connection.

## Given: the rules, written into `CLAUDE.md`

The project follows the rules the review bench enforces
(`work-runner/skills/cpp-standards`). `CLAUDE.md` at the project root
states them so every session sees them:

- Every value with a meaning has its own type. No naked `int`,
  `std::size_t`, `std::string` or `bool` in a public signature or a
  public member. Same representation with two meanings is two types.
  No two parameters of one function, and no two public members of one
  type, share a type. The only exception is a universal idiom such as
  `size()` returning `std::size_t`.
- No `bool` as a parameter, return type or member. Use an
  `enum class X : bool { no, yes }` named for what it means.
- Every constructor is `explicit` except copy and move.
- Copy and move operations are `noexcept`. Generic code uses
  `noexcept(noexcept(...))`. Nothing else is `noexcept`.
- `[[nodiscard]]` only where ignoring the result is almost certainly
  a bug.
- Nothing returns a pointer or reference into a container's or
  queue's storage. Values cross an API boundary by value,
  `std::optional`, or a function object that is handed the value.
- Tests use doctest through `tests/testing/doctest.hpp` and
  rapidcheck through `tests/testing/rapidcheck.hpp`. Every component
  has example-based tests and at least one property test.
- Build with the presets above. One sanitizer per build directory.
- Say "member function", never "method".

`CLAUDE.md` also names the layout and the three command lines.

## Out of scope

- Installing or packaging the library.
- A `main` program. The library is consumed by tests until lab 07.
- Any component. This lab is the empty project.

## Open decisions

1. The project name that replaces `me` and `ME_` everywhere.
2. Whether warnings are errors (`-Werror` in `CompileOptions.cmake`).
   The default is yes.
3. Whether to add presets for a second compiler (for example
   `debug-gcc`, `debug-clang`). The default is no: one compiler, three
   sanitizers.
