#!/bin/bash
# variant-netinst/build-inner.sh — build the Ageless Linux netinstall ISO
# with simple-cdd (stock debian-installer + preseed). Runs INSIDE the build
# container; contributors call build.py.
#
# Inputs (environment, set by build.py): ARCH, STANCE, DEBS_DIR, WORK_DIR,
# OUT_DIR, SNAPSHOT — see variant-live/build-inner.sh.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$HERE")"
. "$ROOT/common/release.env"

: "${ARCH:?}" "${STANCE:?}" "${DEBS_DIR:?}" "${WORK_DIR:?}" "${OUT_DIR:?}"
SNAPSHOT="${SNAPSHOT:-none}"

IMAGE_NAME="ageless-${AGELESS_CODENAME}-${AGELESS_VERSION}-${ARCH}-netinst"
case "$STANCE" in
    standard) stance_pkgs="ageless-compliance ageless-standard" ;;
    flagrant) stance_pkgs="ageless-refusal ageless-flagrant"; IMAGE_NAME="${IMAGE_NAME}-flagrant" ;;
    *) echo "unknown stance: $STANCE" >&2; exit 2 ;;
esac

if [[ "$SNAPSHOT" != none ]]; then
    MIRROR="https://snapshot.debian.org/archive/debian/${SNAPSHOT}/"
    SECURITY_MIRROR="https://snapshot.debian.org/archive/debian-security/${SNAPSHOT}/"
else
    MIRROR="http://deb.debian.org/debian/"
    SECURITY_MIRROR="http://deb.debian.org/debian-security/"
fi

rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR/profiles" "$WORK_DIR/local" "$OUT_DIR"
cd "$WORK_DIR"

# Profiles with the stance substituted in.
for f in "$HERE"/profiles/*; do
    sed -e "s|@STANCE_PACKAGES@|${stance_pkgs// /\\n}|" \
        -e "s|@PKGSEL_INCLUDE@|${stance_pkgs} ageless-desktop-mate|" \
        "$f" > "profiles/$(basename "$f")"
done
chmod +x profiles/ageless.postinst
echo "ARCHES=\"$ARCH\"" >> profiles/ageless.conf

# Only the chosen stance goes on the medium.
for deb in "$DEBS_DIR"/*.deb; do
    base="$(basename "$deb")"
    case "$STANCE:$base" in
        standard:ageless-refusal_*|standard:ageless-flagrant_*) continue ;;
        flagrant:ageless-compliance_*|flagrant:ageless-standard_*) continue ;;
        *:ageless-maker_*) continue ;;
    esac
    cp "$deb" local/
done

# simple-cdd refuses to run as root unless told otherwise (--force-root).
build-simple-cdd \
    --conf profiles/ageless.conf \
    --dist "$DEBIAN_SUITE" \
    --debian-mirror "$MIRROR" \
    --security-mirror "$SECURITY_MIRROR" \
    --local-packages "$WORK_DIR/local" \
    --profiles ageless \
    --auto-profiles ageless \
    --force-root \
    2>&1 | tee "$OUT_DIR/${IMAGE_NAME}.build.log"

iso="$(find tmp/images -name '*.iso' | head -n1)"
[[ -n "$iso" ]] || { echo "E: simple-cdd produced no ISO" >&2; exit 1; }
mv "$iso" "$OUT_DIR/${IMAGE_NAME}.iso"
cd "$OUT_DIR"
sha256sum "${IMAGE_NAME}.iso" > "${IMAGE_NAME}.iso.sha256"
echo "I: built $OUT_DIR/${IMAGE_NAME}.iso ($(du -h "${IMAGE_NAME}.iso" | cut -f1))"
