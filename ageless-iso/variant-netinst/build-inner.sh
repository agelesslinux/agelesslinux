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

IMAGE_NAME="ageless-${AGELESS_CODENAME}-${AGELESS_VERSION}${AGELESS_VERSION_SUFFIX:-}-${ARCH}-netinst"
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
        *:ageless-maker_*|*:ageless-flagrant-*_*|*:ageless-device_*) continue ;;
    esac
    cp "$deb" local/
done

# simple-cdd 0.6.9 always mirrors the i386 d-i images for amd64 builds (for
# 32-bit UEFI), but trixie no longer ships an i386 installer, so the mirror
# step 404s. Run a copy with that block removed and tell debian-cd to skip
# 32-bit UEFI. Fails loudly once upstream changes, so the hack gets dropped.
sed '/For amd64 builds: debian-cd/,/a="i386")))/d' /usr/bin/build-simple-cdd > build-simple-cdd
if cmp -s /usr/bin/build-simple-cdd build-simple-cdd; then
    echo "E: simple-cdd i386 workaround no longer applies; remove it" >&2
    exit 1
fi
export DISABLE_UEFI_32=1

# simple-cdd refuses to run as root unless told otherwise (--force-root).
python3 build-simple-cdd \
    --conf profiles/ageless.conf \
    --dist "$DEBIAN_SUITE" \
    --debian-mirror "$MIRROR" \
    --security-mirror "$SECURITY_MIRROR" \
    --local-packages "$WORK_DIR/local" \
    --profiles ageless \
    --auto-profiles ageless \
    --force-root \
    --dvd \
    --verbose \
    2>&1 | tee "$OUT_DIR/${IMAGE_NAME}.build.log"

iso="$(find images -name '*.iso' | head -n1)"
[[ -n "$iso" ]] || { echo "E: simple-cdd produced no ISO" >&2; exit 1; }
mv "$iso" "$OUT_DIR/${IMAGE_NAME}.iso"
cd "$OUT_DIR"
sha256sum "${IMAGE_NAME}.iso" > "${IMAGE_NAME}.iso.sha256"
echo "I: built $OUT_DIR/${IMAGE_NAME}.iso ($(du -h "${IMAGE_NAME}.iso" | cut -f1))"
