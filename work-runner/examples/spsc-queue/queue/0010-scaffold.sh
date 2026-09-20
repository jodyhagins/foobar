---
title: Scaffold the project
status: todo
---
set -euo pipefail
mkdir -p include tests
if [ ! -e CMakeLists.txt ]; then
cat > CMakeLists.txt <<'CM'
cmake_minimum_required(VERSION 3.20)
project(spsc LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
find_package(Threads REQUIRED)
add_library(spsc INTERFACE)
target_include_directories(spsc INTERFACE ${CMAKE_CURRENT_SOURCE_DIR}/include)
enable_testing()
add_executable(spsc_queue_test tests/spsc_queue_test.cpp)
target_link_libraries(spsc_queue_test PRIVATE spsc Threads::Threads)
target_compile_options(spsc_queue_test PRIVATE -Wall -Wextra -Wpedantic -Werror)
add_test(NAME spsc_queue_test COMMAND spsc_queue_test)
CM
fi
printf 'build/\n.work/\n' > .gitignore
ls CMakeLists.txt include tests
