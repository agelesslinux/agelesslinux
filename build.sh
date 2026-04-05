#!/bin/bash
# build.sh — assemble become-ageless.sh from lib/ modules
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="${SCRIPT_DIR}/become-ageless.sh"

> "$OUT"

for f in "${SCRIPT_DIR}"/lib/*.sh; do
    cat "$f" >> "$OUT"
    echo "" >> "$OUT"
done

# Trigger main when the assembled file is executed
echo 'main "$@"' >> "$OUT"

chmod +x "$OUT"
echo "Built $(basename "$OUT") ($(wc -l < "$OUT") lines)"
