---
title: Write the project skeleton
status: todo
---
set -euo pipefail
[ ! -e CMakeLists.txt ] || { echo "CMakeLists.txt exists; refusing to scaffold over it"; exit 1; }
mkdir -p src tests
cat > CMakeLists.txt <<'CM'
cmake_minimum_required(VERSION 3.20)
project(hello LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
add_library(hello src/hello.cpp)
target_include_directories(hello PUBLIC src)
add_executable(hello_main src/main.cpp)
target_link_libraries(hello_main PRIVATE hello)
enable_testing()
add_executable(hello_test tests/hello_test.cpp)
target_link_libraries(hello_test PRIVATE hello)
add_test(NAME hello_test COMMAND hello_test)
CM
cat > src/hello.hpp <<'HPP'
#pragma once
#include <string>
std::string greeting(std::string const& name);
HPP
cat > src/hello.cpp <<'CPP'
#include "hello.hpp"
std::string greeting(std::string const& name) { return "Hello, " + name + "!"; }
CPP
cat > src/main.cpp <<'CPP'
#include "hello.hpp"
#include <iostream>
int main() { std::cout << greeting("world") << '\n'; }
CPP
cat > tests/hello_test.cpp <<'CPP'
#include "hello.hpp"
#include <cstdlib>
int main() { return greeting("x") == "Hello, x!" ? EXIT_SUCCESS : EXIT_FAILURE; }
CPP
printf 'build/\n.work/\n' > .gitignore
echo "scaffolded: $(find CMakeLists.txt src tests -type f | sort | tr '\n' ' ')"
