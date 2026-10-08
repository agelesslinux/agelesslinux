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

# Development builds append AGELESS_VERSION_SUFFIX (from build.py, e.g.
# ~14.gabc1234) to the version at the top of every changelog. "~" sorts before
# the release, so 0.1.0~14.gabc1234 < 0.1.0. Release builds (empty suffix)
# must come from finalized changelogs. See tools/release.py.
SUFFIX="${AGELESS_VERSION_SUFFIX:-}"

set_build_version() {  # <package dir>
    local changelog="$1/debian/changelog" dist
    dist="$(dpkg-parsechangelog -l "$changelog" -S Distribution)"
    if [[ -z "$SUFFIX" && "$dist" == UNRELEASED ]]; then
        echo "E: $(basename "$1"): release build, but debian/changelog is UNRELEASED (tools/release.py finalize)" >&2
        exit 1
    fi
    [[ -z "$SUFFIX" ]] || sed -i "1s/(\([^)]*\))/(\1${SUFFIX})/" "$changelog"
}

for src in "$ROOT"/packages/*/; do
    name="$(basename "$src")"
    [[ -f "$src/debian/control" ]] || continue
    if [[ "$name" == ageless-keyring ]] && ! compgen -G "$src/keys/*.asc" >/dev/null; then
        echo "I: skipping ageless-keyring: no archive key in packages/ageless-keyring/keys/ yet"
        continue
    fi
    echo "I: building $name${SUFFIX:+ (version suffix $SUFFIX)}"
    cp -a "$src" "$SCRATCH/packages/$name"
    set_build_version "$SCRATCH/packages/$name"
    # An older build image may lack a build dependency; install it if we can.
    if ! (cd "$SCRATCH/packages/$name" && dpkg-checkbuilddeps >/dev/null 2>&1) && [[ $EUID -eq 0 ]]; then
        echo "I: installing build dependencies for $name"
        (cd "$SCRATCH/packages/$name" && apt-get update -qq && \
            apt-get build-dep -y -qq --no-install-recommends ./ >/dev/null)
    fi
    (cd "$SCRATCH/packages/$name" && dpkg-buildpackage -b -us -uc >"$OUT/$name.build.log" 2>&1) || {
        tail -40 "$OUT/$name.build.log" >&2
        echo "E: $name failed to build (log: $OUT/$name.build.log)" >&2
        exit 1
    }
done

# Replace earlier builds of the same binary packages, so out/debs (and the apt
# archive made from it) carries one version of each.
for deb in "$SCRATCH"/packages/*.deb; do
    rm -f "$OUT/$(dpkg-deb -f "$deb" Package)"_*.deb
done
mv "$SCRATCH"/packages/*.deb "$OUT/"
cd "$OUT"
apt-ftparchive packages . > Packages
gzip -9nkf Packages
echo "I: $(ls ./*.deb | wc -l) packages in $OUT"
