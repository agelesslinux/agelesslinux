#!/bin/bash
# tools/build-packages.sh — build every source package under packages/ into
# .debs and index them as a flat apt repository. Runs inside the build
# container. Usage: build-packages.sh <out-dir>
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${1:?usage: build-packages.sh <out-dir>}"
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"

export SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-$(git -C "$ROOT" log -1 --format=%ct 2>/dev/null || date +%s)}"

# Build from a scratch copy so the checkout stays clean (and may be read-only).
SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT
mkdir -p "$SCRATCH/packages"
cp -a "$ROOT/common" "$SCRATCH/"

for src in "$ROOT"/packages/*/; do
    name="$(basename "$src")"
    [[ -f "$src/debian/control" ]] || continue
    echo "I: building $name"
    cp -a "$src" "$SCRATCH/packages/$name"
    (cd "$SCRATCH/packages/$name" && dpkg-buildpackage -b -us -uc >"$OUT/$name.build.log" 2>&1) || {
        tail -40 "$OUT/$name.build.log" >&2
        echo "E: $name failed to build (log: $OUT/$name.build.log)" >&2
        exit 1
    }
done

mv "$SCRATCH"/packages/*.deb "$OUT/"
cd "$OUT"
apt-ftparchive packages . > Packages
gzip -9nkf Packages
echo "I: $(ls ./*.deb | wc -l) packages in $OUT"
