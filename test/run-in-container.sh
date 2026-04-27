#!/bin/bash
# run-in-container.sh — test become-ageless.sh inside a container
#
# Expected to run as root inside a Docker container with the script
# copied to /tmp/become-ageless.sh
#
# Usage: docker run --rm -v $PWD:/src <image> bash /src/test/run-in-container.sh

set -euo pipefail

SCRIPT="/tmp/become-ageless.sh"
PASS=0
FAIL=0
SKIP=0

# Copy script so we don't modify mounted volume
cp /src/become-ageless.sh "$SCRIPT"
chmod +x "$SCRIPT"

# ── Helpers ──────────────────────────────────────────────────────────────────

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1 — $2"; }
skip() { SKIP=$((SKIP + 1)); echo "  SKIP: $1 — $2"; }

section() { echo ""; echo "── $1 ──"; }

# Portable file comparison (diff/cmp may not be in minimal containers)
files_identical() {
    if command -v cmp &>/dev/null; then
        cmp -s "$1" "$2"
    else
        [[ "$(md5sum < "$1")" == "$(md5sum < "$2")" ]]
    fi
}

# ── Distro identification ────────────────────────────────────────────────────

section "ENVIRONMENT"

if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    echo "  Distro: ${PRETTY_NAME:-$NAME $VERSION_ID}"
    echo "  ID: ${ID}"
else
    echo "  Distro: unknown (no /etc/os-release)"
fi

HAS_SYSTEMCTL=0
if command -v systemctl &>/dev/null; then
    HAS_SYSTEMCTL=1
    echo "  systemctl: available"
else
    echo "  systemctl: not available"
fi

HAS_USERDBD=0
if [[ $HAS_SYSTEMCTL -eq 1 ]] && systemctl list-unit-files systemd-userdbd.service &>/dev/null 2>&1; then
    HAS_USERDBD=1
    echo "  systemd-userdbd: installed"
else
    echo "  systemd-userdbd: not installed"
fi

# Create a test user if none exists (some minimal images have no uid >= 1000)
if ! awk -F: '$3 >= 1000 && $3 < 65534' /etc/passwd | grep -q .; then
    if command -v useradd &>/dev/null; then
        useradd -m -s /bin/bash testuser 2>/dev/null || true
        echo "  Created test user: testuser"
    elif command -v adduser &>/dev/null; then
        adduser -D -s /bin/bash testuser 2>/dev/null || true
        echo "  Created test user: testuser"
    else
        echo "  WARNING: No human users and cannot create one"
    fi
fi

HUMAN_USERS=$(awk -F: '$3 >= 1000 && $3 < 65534 { print $1 }' /etc/passwd | tr '\n' ' ')
echo "  Human users: ${HUMAN_USERS:-none}"

# ── Test: --version ──────────────────────────────────────────────────────────

section "--version"

version_out=$(bash "$SCRIPT" --version 2>&1)
if [[ "$version_out" == *"0.1.1"* ]]; then
    pass "--version prints 0.1.1"
else
    fail "--version" "got: $version_out"
fi

# ── Test: --bogus ────────────────────────────────────────────────────────────

section "unknown flag"

bogus_out=$(bash "$SCRIPT" --bogus 2>&1 || true)
if echo "$bogus_out" | grep -q "Unknown argument"; then
    pass "unknown flag prints error"
else
    fail "unknown flag" "no error message"
fi

# ── Test: --dry-run ──────────────────────────────────────────────────────────

section "--dry-run"

dry_out=$(bash "$SCRIPT" --dry-run 2>&1)

if echo "$dry_out" | grep -q "SYSTEM ANALYSIS"; then
    pass "--dry-run shows system analysis"
else
    fail "--dry-run" "no SYSTEM ANALYSIS section"
fi

if echo "$dry_out" | grep -q "PLANNED ACTIONS"; then
    pass "--dry-run shows planned actions"
else
    fail "--dry-run" "no PLANNED ACTIONS section"
fi

if echo "$dry_out" | grep -q "Dry run complete"; then
    pass "--dry-run exits cleanly"
else
    fail "--dry-run" "no dry run exit message"
fi

# Check that no files were modified
if [[ ! -f /etc/os-release.pre-ageless ]]; then
    pass "--dry-run did not modify os-release"
else
    fail "--dry-run" "/etc/os-release.pre-ageless exists"
fi

if [[ ! -d /etc/ageless ]]; then
    pass "--dry-run did not create /etc/ageless"
else
    fail "--dry-run" "/etc/ageless/ exists"
fi

# Check userdb gating in dry-run output
if [[ $HAS_USERDBD -eq 0 ]]; then
    if echo "$dry_out" | grep -qi "skip.*userdb\|not present\|not installed"; then
        pass "--dry-run reports userdb skip (userdbd not present)"
    else
        # Check if it skipped in planned actions
        if echo "$dry_out" | grep -qi "Skipping userdb"; then
            pass "--dry-run reports userdb skip in planned actions"
        else
            fail "--dry-run userdb gating" "userdbd not installed but no skip message found"
        fi
    fi
fi

# ── Test: full install ───────────────────────────────────────────────────────

section "full install (--accept)"

# Save original os-release for comparison
cp /etc/os-release /tmp/os-release.original

install_out=$(bash "$SCRIPT" --accept 2>&1)

# Check os-release was modified
if grep -q "Ageless Linux" /etc/os-release; then
    pass "os-release says Ageless Linux"
else
    fail "os-release" "does not contain 'Ageless Linux'"
fi

if grep -q "ID=ageless" /etc/os-release; then
    pass "os-release has ID=ageless"
else
    fail "os-release ID" "ID is not 'ageless'"
fi

# Check backup was created
if [[ -f /etc/os-release.pre-ageless ]]; then
    pass "os-release backup created"
else
    fail "os-release backup" "/etc/os-release.pre-ageless not found"
fi

# Check backup matches original
if files_identical /etc/os-release.pre-ageless /tmp/os-release.original; then
    pass "os-release backup matches original"
else
    fail "os-release backup content" "backup differs from original"
fi

# Check ID_LIKE preserves base distro
if grep -q "ID_LIKE=" /etc/os-release; then
    id_like=$(grep "^ID_LIKE=" /etc/os-release | cut -d'=' -f2)
    original_id=$(grep "^ID=" /tmp/os-release.original | cut -d'=' -f2 | tr -d '"')
    if echo "$id_like" | grep -q "$original_id"; then
        pass "ID_LIKE contains base distro ($original_id)"
    else
        fail "ID_LIKE" "does not contain base distro: $id_like"
    fi
fi

# Check lsb-release if it existed
if [[ -f /etc/lsb-release ]]; then
    if grep -q "Ageless" /etc/lsb-release; then
        pass "lsb-release updated"
    else
        fail "lsb-release" "not updated"
    fi
    if [[ -f /etc/lsb-release.pre-ageless ]]; then
        pass "lsb-release backup created"
    else
        fail "lsb-release backup" "not found"
    fi
fi

# Check compliance files
if [[ -f /etc/ageless/ab1043-compliance.txt ]]; then
    pass "compliance notice created"
else
    fail "compliance notice" "not found"
fi

if [[ -f /etc/ageless/age-verification-api.sh ]]; then
    pass "age verification API stub created"
    if [[ -x /etc/ageless/age-verification-api.sh ]]; then
        pass "API stub is executable"
    else
        fail "API stub permissions" "not executable"
    fi
else
    fail "API stub" "not found"
fi

# Check userdb behavior
if [[ $HAS_USERDBD -eq 1 ]]; then
    # Should have created userdb records
    for user in $HUMAN_USERS; do
        if [[ -f "/etc/userdb/${user}.user" ]]; then
            pass "userdb record created for $user"
            if grep -q '"birthDate"' "/etc/userdb/${user}.user"; then
                pass "userdb record for $user has birthDate"
            else
                fail "userdb $user birthDate" "field not found"
            fi
        else
            fail "userdb record $user" "not created"
        fi
    done
else
    # Should NOT have created userdb records
    if [[ -d /etc/userdb ]]; then
        # Check if any .user files were created
        user_files=$(ls /etc/userdb/*.user 2>/dev/null | wc -l)
        if [[ $user_files -gt 0 ]]; then
            fail "userdb gating" "created $user_files .user files despite userdbd not installed"
        else
            pass "userdb dir exists but no .user files (OK)"
        fi
    else
        pass "userdb skipped (no /etc/userdb/ created)"
    fi
fi

# Check conf file
if [[ -f /etc/agelesslinux.conf ]]; then
    pass "agelesslinux.conf created"
    # Verify it's sourceable
    if bash -c "source /etc/agelesslinux.conf" 2>/dev/null; then
        pass "agelesslinux.conf is sourceable"
    else
        fail "agelesslinux.conf" "not sourceable"
    fi
    # Verify key fields
    # shellcheck disable=SC1091
    source /etc/agelesslinux.conf
    if [[ "${AGELESS_VERSION:-}" == "0.1.1" ]]; then
        pass "conf records version 0.1.1"
    else
        fail "conf version" "got: ${AGELESS_VERSION:-unset}"
    fi
else
    fail "agelesslinux.conf" "not created"
fi

# ── Test: --revert ───────────────────────────────────────────────────────────

section "--revert"

revert_out=$(bash "$SCRIPT" --revert 2>&1)

if echo "$revert_out" | grep -q "Revert complete"; then
    pass "--revert completed"
else
    fail "--revert" "no completion message"
fi

# Check os-release was restored
if files_identical /etc/os-release /tmp/os-release.original; then
    pass "os-release restored to original"
else
    fail "os-release restore" "does not match original"
fi

# Check backup was removed
if [[ ! -f /etc/os-release.pre-ageless ]]; then
    pass "os-release backup removed"
else
    fail "os-release backup cleanup" "backup still exists"
fi

# Check /etc/ageless was removed
if [[ ! -d /etc/ageless ]]; then
    pass "/etc/ageless removed"
else
    fail "/etc/ageless cleanup" "directory still exists"
fi

# Check conf was removed
if [[ ! -f /etc/agelesslinux.conf ]]; then
    pass "agelesslinux.conf removed"
else
    fail "agelesslinux.conf cleanup" "still exists"
fi

# Check userdb was cleaned up
if [[ $HAS_USERDBD -eq 1 ]]; then
    for user in $HUMAN_USERS; do
        if [[ ! -f "/etc/userdb/${user}.user" ]]; then
            pass "userdb record removed for $user"
        else
            fail "userdb cleanup $user" "record still exists"
        fi
    done
fi

# ── Test: flagrant mode ─────────────────────────────────────────────────────

section "flagrant mode (--accept --flagrant)"

bash "$SCRIPT" --accept --flagrant >/dev/null 2>&1

if grep -q "flagrantly noncompliant" /etc/os-release; then
    pass "flagrant mode: os-release shows flagrantly noncompliant"
else
    fail "flagrant os-release" "verification status not flagrant"
fi

if [[ -f /etc/ageless/REFUSAL ]]; then
    pass "flagrant mode: REFUSAL file created"
else
    fail "flagrant REFUSAL" "not found"
fi

if [[ ! -f /etc/ageless/age-verification-api.sh ]]; then
    pass "flagrant mode: API stub NOT created (correct)"
else
    fail "flagrant API stub" "should not exist in flagrant mode"
fi

# Check flagrant conf
if [[ -f /etc/agelesslinux.conf ]]; then
    # shellcheck disable=SC1091
    source /etc/agelesslinux.conf
    if [[ "${AGELESS_FLAGRANT:-}" == "1" ]]; then
        pass "conf records flagrant mode"
    else
        fail "conf flagrant" "AGELESS_FLAGRANT not 1"
    fi
fi

# Revert flagrant
bash "$SCRIPT" --revert >/dev/null 2>&1

if [[ ! -f /etc/ageless/REFUSAL ]]; then
    pass "flagrant revert: REFUSAL removed"
else
    fail "flagrant revert" "REFUSAL still exists"
fi

# ── Test: --persistent without systemd ───────────────────────────────────────

section "--persistent gating"

if [[ $HAS_SYSTEMCTL -eq 0 ]]; then
    persistent_out=$(bash "$SCRIPT" --accept --persistent 2>&1 || true)
    if echo "$persistent_out" | grep -qi "requires systemd"; then
        pass "--persistent errors without systemd"
    else
        fail "--persistent gating" "should error without systemd"
    fi
else
    skip "--persistent error test" "systemctl is available"
fi

# ── Test: revert skips userdbd reload when DM is active ──────────────────────
#
# Regression test for issue #1: reloading systemd-userdbd mid-session breaks
# the SDDM (and LightDM) lock screen. The fix in revert_userdb must detect
# an active display manager and skip the reload, warning the user instead.

section "revert: DM lock-screen safety (issue #1 fix)"

bash "$SCRIPT" --accept >/dev/null 2>&1

mkdir -p /tmp/mock-bin
RELOAD_FLAG=/tmp/mock-bin/userdbd-reload-called
rm -f "$RELOAD_FLAG"

cat > /tmp/mock-bin/systemctl << 'MOCK_EOF'
#!/bin/bash
# Mock: sddm is active, userdbd is installed. Reloading userdbd must not happen.
case "${1:-} ${2:-}" in
    "is-active sddm.service")                         exit 0 ;;
    "is-active "*.service)                             exit 1 ;;
    "list-unit-files systemd-userdbd.service")         exit 0 ;;
    "try-reload-or-restart systemd-userdbd.service")
        touch /tmp/mock-bin/userdbd-reload-called ; exit 0 ;;
    *) exit 0 ;;
esac
MOCK_EOF
chmod +x /tmp/mock-bin/systemctl

dm_revert_out=$(PATH="/tmp/mock-bin:$PATH" bash "$SCRIPT" --revert 2>&1)

if echo "$dm_revert_out" | grep -q "Skipped userdbd reload"; then
    pass "revert: skips userdbd reload when SDDM is active"
else
    fail "revert DM reload check" "expected 'Skipped userdbd reload'; got: $(echo "$dm_revert_out" | grep -i 'userdbd\|reload\|sddm' | head -3)"
fi

if echo "$dm_revert_out" | grep -qi "log out\|lock"; then
    pass "revert: warns about lock screen when DM active"
else
    fail "revert DM warning" "no lock-screen warning in output"
fi

if [[ ! -f "$RELOAD_FLAG" ]]; then
    pass "revert: userdbd was NOT reloaded (lock screen protected)"
else
    fail "revert DM safety" "userdbd try-reload-or-restart was called despite active SDDM"
fi

rm -rf /tmp/mock-bin

# ── Test: revert_no_conf prints per-file userdb instructions ─────────────────
#
# Regression test for issue #1 (legacy path): the old revert_no_conf printed
# "rm -rf /etc/userdb" which destroyed any pre-existing userdb records that
# ageless had backed up before modifying. The fix prints per-file instructions:
#   - "mv backup → original" when a .pre-ageless backup exists
#   - "rm -f file"           when no backup exists (ageless created it fresh)

section "revert_no_conf: per-file userdb instructions (not rm -rf)"

cp /etc/os-release /etc/os-release.pre-ageless
mkdir -p /etc/userdb
printf '{"userName":"testuser","uid":1000,"birthDate":"1970-01-01"}\n' \
    > /etc/userdb/testuser.user
printf '{"userName":"testuser","uid":1000,"birthDate":null}\n' \
    > /etc/userdb/testuser.user.pre-ageless
printf '{"userName":"orphan","uid":1001,"birthDate":"1970-01-01"}\n' \
    > /etc/userdb/orphan.user

no_conf_out=$(bash "$SCRIPT" --revert 2>&1 || true)

if echo "$no_conf_out" | grep -q "mv.*testuser\.user\.pre-ageless.*testuser\.user"; then
    pass "revert_no_conf: prints 'mv backup → original' for backed-up user"
else
    fail "revert_no_conf mv" "no mv instruction for testuser.user.pre-ageless"
fi

if echo "$no_conf_out" | grep -q "rm -f.*orphan\.user"; then
    pass "revert_no_conf: prints 'rm -f' for un-backed-up user"
else
    fail "revert_no_conf rm" "no rm -f instruction for orphan.user"
fi

if echo "$no_conf_out" | grep -q "rm -rf /etc/userdb"; then
    fail "revert_no_conf safety" "still prints 'rm -rf /etc/userdb' (too broad)"
else
    pass "revert_no_conf: does NOT print 'rm -rf /etc/userdb'"
fi

rm -f /etc/os-release.pre-ageless
rm -rf /etc/userdb

# ── Results ──────────────────────────────────────────────────────────────────

section "RESULTS"
echo ""
echo "  PASS: $PASS"
echo "  FAIL: $FAIL"
echo "  SKIP: $SKIP"
echo ""

if [[ $FAIL -gt 0 ]]; then
    echo "  STATUS: FAILURES DETECTED"
    exit 1
else
    echo "  STATUS: ALL TESTS PASSED"
    exit 0
fi
