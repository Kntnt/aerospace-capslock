#!/bin/bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
mkdir -p "$project_dir/bin"
xcrun swiftc -O "$project_dir/src/aerospace-shortcuts.swift" -o "$project_dir/bin/aerospace-shortcuts"
