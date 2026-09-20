---
title: Configure and build
status: todo
timeout: 900
---
set -euo pipefail
cmake -S . -B build -DCMAKE_BUILD_TYPE=Debug
cmake --build build --parallel
