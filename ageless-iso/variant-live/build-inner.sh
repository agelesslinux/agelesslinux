#!/bin/bash
# variant-live/build-inner.sh — build the Ageless Linux live ISO (MATE +
# Calamares) with live-build. Runs INSIDE the build container as root;
# contributors call build.py, never this script directly.
#
# Inputs (environment, set by build.py):
#   ARCH       amd64 | arm64
#   STANCE     standard | flagrant
#   DEBS_DIR   directory holding the ageless-* .debs built by build-packages.sh
#   WORK_DIR   scratch directory for the live-build tree
#   OUT_DIR    where the finished ISO + checksums land
#   SNAPSHOT   snapshot.debian.org timestamp, or "none"
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$HERE")"
# shellcheck source=../common/release.env
. "$ROOT/common/release.env"

: "${ARCH:?}" "${STANCE:?}" "${DEBS_DIR:?}" "${WORK_DIR:?}" "${OUT_DIR:?}"
SNAPSHOT="${SNAPSHOT:-none}"

IMAGE_NAME="ageless-${AGELESS_CODENAME}-${AGELESS_VERSION}-${ARCH}-live"
[[ "$STANCE" == flagrant ]] && IMAGE_NAME="${IMAGE_NAME}-flagrant"

if [[ "$SNAPSHOT" != none ]]; then
    MIRROR="https://snapshot.debian.org/archive/debian/${SNAPSHOT}/"
    SECURITY_MIRROR="https://snapshot.debian.org/archive/debian-security/${SNAPSHOT}/"
    # Snapshot Release files are past their Valid-Until by design.
    APT_OPTS=(--apt-options "--yes -o Acquire::Check-Valid-Until=false -o Acquire::Retries=5")
else
    MIRROR="http://deb.debian.org/debian/"
    SECURITY_MIRROR="http://security.debian.org/debian-security/"
    APT_OPTS=(--apt-options "--yes -o Acquire::Retries=5")
fi

case "$ARCH" in
    amd64) BOOTLOADERS="grub-efi,syslinux"; FLAVOUR="amd64" ;;
    arm64) BOOTLOADERS="grub-efi";          FLAVOUR="arm64" ;;
    *) echo "unsupported arch: $ARCH" >&2; exit 2 ;;
esac

rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR" "$OUT_DIR"
cd "$WORK_DIR"

lb config \
    --mode debian \
    --distribution "$DEBIAN_SUITE" \
    --architecture "$ARCH" \
    --linux-flavours "$FLAVOUR" \
    --archive-areas "main contrib non-free-firmware" \
    --mirror-bootstrap "$MIRROR" \
    --mirror-chroot "$MIRROR" \
    --mirror-chroot-security "$SECURITY_MIRROR" \
    --mirror-binary "http://deb.debian.org/debian/" \
    --mirror-binary-security "http://security.debian.org/debian-security/" \
    --security true \
    --updates true \
    "${APT_OPTS[@]}" \
    --apt-recommends true \
    --binary-images iso-hybrid \
    --bootloaders "$BOOTLOADERS" \
    --debian-installer none \
    --firmware-chroot true \
    --firmware-binary false \
    --cache-packages false \
    --checksums sha256 \
    --image-name "$IMAGE_NAME" \
    --iso-application "$AGELESS_NAME" \
    --iso-preparer "Ageless Linux build.py; https://github.com/agelesslinux/agelesslinux" \
    --iso-publisher "Ageless Linux; https://agelesslinux.org" \
    --iso-volume "Ageless ${AGELESS_VERSION} ${ARCH}" \
    --bootappend-live "boot=live components quiet splash" \
    --memtest none \
    --win32-loader false

# Static configuration shared by every arch, then the arch-specific delta.
cp -a "$HERE/config/." config/
if [[ -d "$HERE/arch/$ARCH" ]]; then
    cp -a "$HERE/arch/$ARCH/." config/
fi

# Our packages. Pick exactly one stance so the Conflicts never meet.
mkdir -p config/packages.chroot
case "$STANCE" in
    standard) skip='ageless-refusal_|ageless-flagrant_' ; meta=ageless-standard ;;
    flagrant) skip='ageless-compliance_|ageless-standard_'; meta=ageless-flagrant ;;
    *) echo "unknown stance: $STANCE" >&2; exit 2 ;;
esac
for deb in "$DEBS_DIR"/*.deb; do
    base="$(basename "$deb")"
    [[ "$base" =~ $skip ]] && continue
    [[ "$base" == ageless-maker_* ]] && continue   # maker toolkit: repo only, not the ISO
    cp "$deb" config/packages.chroot/
done
echo "$meta" > config/package-lists/stance.list.chroot

lb build 2>&1 | tee "$OUT_DIR/${IMAGE_NAME}.build.log"

iso="$(ls ./*.iso | head -n1)"
mv "$iso" "$OUT_DIR/${IMAGE_NAME}.iso"
for f in ./*.packages ./*.contents ./*.files; do
    [[ -e "$f" ]] && mv "$f" "$OUT_DIR/${IMAGE_NAME}.${f##*.}"
done
cd "$OUT_DIR"
sha256sum "${IMAGE_NAME}.iso" > "${IMAGE_NAME}.iso.sha256"
echo "I: built $OUT_DIR/${IMAGE_NAME}.iso ($(du -h "${IMAGE_NAME}.iso" | cut -f1))"
