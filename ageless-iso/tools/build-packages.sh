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

# Development builds append AGELESS_VERSION_SUFFIX (from build.py) to every
# package version, so apt on an installed system sees each build as an upgrade.
SUFFIX="${AGELESS_VERSION_SUFFIX:-}"

add_dev_changelog() {  # <package dir>
    local dir="$1" source version stamp
    source="$(dpkg-parsechangelog -l "$dir/debian/changelog" -S Source)"
    version="$(dpkg-parsechangelog -l "$dir/debian/changelog" -S Version)"
    stamp="$(date -u -R -d "@$SOURCE_DATE_EPOCH")"
    {
        printf '%s (%s%s) UNRELEASED; urgency=medium\n\n' "$source" "$version" "$SUFFIX"
        printf '  * Development build.\n\n'
        printf ' -- Ageless Linux <archive@agelesslinux.org>  %s\n\n' "$stamp"
        cat "$dir/debian/changelog"
    } > "$dir/debian/changelog.new"
    mv "$dir/debian/changelog.new" "$dir/debian/changelog"
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
    [[ -z "$SUFFIX" ]] || add_dev_changelog "$SCRATCH/packages/$name"
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
