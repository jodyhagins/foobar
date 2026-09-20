---
title: Run the tests
status: todo
timeout: 300
---
set -euo pipefail
ctest --test-dir build --output-on-failure
