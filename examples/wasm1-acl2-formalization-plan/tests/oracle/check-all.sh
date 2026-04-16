#!/bin/bash
# Compile all WAT files and run oracle checks via Node.js
# Usage: cd tests/oracle && bash check-all.sh
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TMPDIR="${TMPDIR:-/tmp}"

echo "=== Compiling WAT files ==="
fail=0
for wat in "$SCRIPT_DIR"/*.wat; do
  base=$(basename "$wat" .wat)
  if wat2wasm "$wat" -o "$TMPDIR/${base}.wasm" 2>&1; then
    echo "  OK: $base.wat"
  else
    echo "  FAIL: $base.wat"
    fail=1
  fi
done

if [ $fail -ne 0 ]; then
  echo "Compilation failed, aborting."
  exit 1
fi

echo ""
echo "=== Running oracle checks ==="
node "$SCRIPT_DIR/check-all.mjs"
