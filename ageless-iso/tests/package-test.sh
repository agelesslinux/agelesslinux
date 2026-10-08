#!/bin/bash
# tests/package-test.sh — install Ageless packages from a built archive on a
# clean Debian trixie and exercise them. Runs inside debian:trixie:
#
#   docker run --rm -v $PWD:/src:ro -v $PWD/out/repo:/repo:ro debian:trixie \
#       bash /src/tests/package-test.sh [/old-debs]
#
# With an old-debs directory (e.g. the .debs from a previous release), those
# are installed first, so the run tests the upgrade path instead of a fresh
# install. The archive is signed with a throwaway key, as CI signs the real
# one, so apt's signature checking is exercised too.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
OLD="${1:-}"
step() { printf '\n== %s\n' "$*"; }
quiet() { "$@" >/tmp/cmd.log 2>&1 || { tail -40 /tmp/cmd.log; exit 1; }; }

apt-get update -qq
quiet apt-get install -y -qq --no-install-recommends gnupg python3 ca-certificates

if [[ -n "$OLD" ]]; then
    step "install previous release from $OLD"
    old_debs=()
    for pkg in ageless-os-release ageless-compliance ageless-agelessd ageless-standard \
               ageless-system-info ageless-desktop-mate mintmenu mint-themes mint-x-icons \
               xapp-symbolic-icons; do
        compgen -G "$OLD/${pkg}_*.deb" >/dev/null && old_debs+=("$OLD/${pkg}"_*.deb)
    done
    quiet apt-get install -y -qq --no-install-recommends "${old_debs[@]}"
    dpkg-query -W 'ageless-*' mintmenu | awk 'NF == 2'
fi

step "sign the archive with a throwaway key"
GNUPGHOME="$(mktemp -d)"; export GNUPGHOME
gpg --batch --pinentry-mode loopback --passphrase '' \
    --quick-generate-key "Ageless test <test@invalid>" ed25519 sign 1d 2>/dev/null
cp -a /repo /srv/repo
python3 /src/tools/make-repo.py sign /srv/repo --key test@invalid
gpg --export test@invalid > /usr/share/keyrings/ageless-test.gpg
cat > /etc/apt/sources.list.d/ageless.sources <<'EOF'
Types: deb
URIs: file:/srv/repo
Suites: timeless
Components: main
Signed-By: /usr/share/keyrings/ageless-test.gpg
EOF
apt-get update -qq

if [[ -n "$OLD" ]]; then
    step "apt full-upgrade"
    quiet apt-get full-upgrade -y -qq
else
    step "install the desktop packages"
    quiet apt-get install -y -qq --no-install-recommends ageless-standard ageless-desktop-mate
fi
dpkg-query -W 'ageless-*' mintmenu | awk 'NF == 2'

step "identity"
. /etc/os-release
echo "$PRETTY_NAME (ID=$ID, DEBIAN_CODENAME=$DEBIAN_CODENAME)"
[[ "$ID" == ageless && "$DEBIAN_CODENAME" == trixie ]]
dpkg-query -W -f '${Version}\n' mintmenu | grep -q '+ageless'
test -x /usr/lib/linuxmint/mintMenu/apt-helper.py

step "flagrant mode: age-signal on, then off"
ageless-flagrant
ageless-flagrant on age-signal >/dev/null
grep -q 'AGELESS_AB1043_COMPLIANCE="refused"' /etc/os-release
test -L /etc/ageless/REFUSAL
ageless-flagrant off age-signal >/dev/null
grep -q 'AGELESS_AB1043_COMPLIANCE="none"' /etc/os-release
test ! -e /etc/ageless/REFUSAL
echo "ok: stance switches both ways, /etc/os-release follows"

step "every flagrant time capsule is installable (simulated)"
for pkg in $(apt-cache pkgnames ageless-flagrant- | sort); do
    apt-get install -s -q "$pkg" >/tmp/sim.log 2>&1 || { cat /tmp/sim.log; echo "FAIL: $pkg"; exit 1; }
    echo "ok: $pkg ($(grep -c '^Inst ' /tmp/sim.log) packages)"
done
for pkg in ageless-maker ageless-device ageless-flagrant ageless-keyring; do
    candidate="$(apt-cache policy "$pkg" | awk '/Candidate:/ {print $2}')"
    if [[ -n "$candidate" && "$candidate" != "(none)" ]]; then
        apt-get install -s -qq "$pkg" >/dev/null || { echo "FAIL: $pkg not installable"; exit 1; }
        echo "ok: $pkg"
    fi
done

step "ageless-device"
quiet apt-get install -y -qq --no-install-recommends ageless-device
ageless-device list || true
test -f /usr/lib/udev/rules.d/70-ageless-device.rules

printf '\nPASS\n'
