#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
test_root="$project_root/build/security-tests"
mkdir -p "$test_root/module-cache"
swiftc -swift-version 5 -module-cache-path "$test_root/module-cache" -framework Security \
  "$project_root/desktop/macos/SecurityCore.swift" "$project_root/desktop/macos/SecurityTests.swift" \
  -o "$test_root/SecurityTests"
"$test_root/SecurityTests"
