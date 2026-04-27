#!/bin/bash
# §§ HEADER — become-ageless.sh setup and utilities
# ============================================================================
#  become-ageless.sh — Ageless Linux Distribution Conversion Tool
#  Version 0.1.1
#
#  This script converts your existing Linux installation into
#  Ageless Linux, a California-regulated operating system.
#
#  By running this script, the person or entity who controls this
#  device becomes an "operating system provider" as defined by
#  California Civil Code § 1798.500(g), because they now "control
#  the operating system software on a general purpose computing device."
#
#  Ageless Linux does not collect, store, transmit, or even think about
#  the age of any user, in full and knowing noncompliance with the
#  California Digital Age Assurance Act (AB 1043, Chapter 675,
#  Statutes of 2025).
#
#  Source & latest version: https://github.com/agelesslinux/agelesslinux
#  SPDX-License-Identifier: Unlicense
# ============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

AGELESS_VERSION="0.1.1"
AGELESS_CODENAME="Timeless"
CONF_PATH="/etc/agelesslinux.conf"

# ── Flag defaults (set by parse_args in 99-main.sh) ─────────────────────────
FLAGRANT=0
ACCEPT=0
PERSISTENT=0
DRY_RUN=0
REVERT=0

# ── Conf tracking defaults (set by execute_* functions) ─────────────────────
CONF_BACKED_UP_OS_RELEASE=0
CONF_BACKED_UP_LSB_RELEASE=0
CONF_USERDB_DIR_CREATED=0
CONF_USERDB_CREATED=""
CONF_USERDB_BACKED_UP=""
CONF_AGELESSD_INSTALLED=0

# ── Analysis defaults (set by analyze_* functions) ──────────────────────────
HAS_SYSTEMD=0
DM_NAME="unknown"
USERDBD_INSTALLED=0
USERDBD_ACTIVE=0
USERDB_DIR_EXISTS=0
USERDB_AVAILABLE=0
USERDB_BIRTHDATE_FOUND=0
PREVIOUS_INSTALL=0

# ── Utility functions ────────────────────────────────────────────────────────

ACTION_NUM=1

plan_action() {
    printf "  %2d. %s\n" "$ACTION_NUM" "$1"
    ACTION_NUM=$((ACTION_NUM + 1))
}

# §§ OS-RELEASE — /etc/os-release and /etc/lsb-release

analyze_os_release() {
    # Prefer the pre-ageless backup if a previous conversion exists
    if [[ -f /etc/os-release.pre-ageless ]]; then
        ANALYSIS_OS_RELEASE="/etc/os-release.pre-ageless"
    else
        ANALYSIS_OS_RELEASE="/etc/os-release"
    fi

    BASE_NAME=$(grep "^NAME=" "$ANALYSIS_OS_RELEASE" | cut -d'"' -f2 || echo "Unknown")
    BASE_VERSION=$(grep "^VERSION_ID=" "$ANALYSIS_OS_RELEASE" | cut -d'"' -f2 || true)
    BASE_ID=$(grep "^ID=" "$ANALYSIS_OS_RELEASE" | cut -d'=' -f2 | tr -d '"' || echo "linux")
    BASE_ID_LIKE=$(grep "^ID_LIKE=" "$ANALYSIS_OS_RELEASE" | cut -d'=' -f2 | tr -d '"' || true)

    # Build ID_LIKE chain: base ID first, then base's own ID_LIKE ancestry
    # e.g. Nobara (ID=nobara, ID_LIKE=fedora) → "nobara fedora"
    # e.g. Ubuntu (ID=ubuntu, ID_LIKE=debian) → "ubuntu debian"
    # e.g. Arch   (ID=arch, no ID_LIKE)       → "arch"
    AGELESS_ID_LIKE="${BASE_ID}${BASE_ID_LIKE:+ $BASE_ID_LIKE}"
}

plan_os_release() {
    if [[ ! -f /etc/os-release.pre-ageless ]]; then
        plan_action "Back up /etc/os-release -> /etc/os-release.pre-ageless"
    fi
    plan_action "Rewrite /etc/os-release as Ageless Linux ${AGELESS_VERSION}"

    if [[ -f /etc/lsb-release ]]; then
        if [[ ! -f /etc/lsb-release.pre-ageless ]]; then
            plan_action "Back up /etc/lsb-release -> /etc/lsb-release.pre-ageless"
        fi
        plan_action "Rewrite /etc/lsb-release as Ageless Linux ${AGELESS_VERSION}"
    fi
}

execute_os_release() {
    # Back up os-release
    local backup="/etc/os-release.pre-ageless"
    if [[ ! -f "$backup" ]]; then
        cp /etc/os-release "$backup"
        CONF_BACKED_UP_OS_RELEASE=1
        echo -e "  [${GREEN}✓${NC}] Backed up original /etc/os-release to $backup"
    else
        CONF_BACKED_UP_OS_RELEASE=1
        echo -e "  [${YELLOW}~${NC}] Backup already exists at $backup (previous conversion?)"
    fi

    # Determine compliance strings
    if [[ $FLAGRANT -eq 1 ]]; then
        local compliance_status="refused"
        local api_status="refused"
        local verification_status="flagrantly noncompliant"
    else
        local compliance_status="none"
        local api_status="not implemented"
        local verification_status="intentionally noncompliant"
    fi

    # Write new os-release
    cat > /etc/os-release << EOF
PRETTY_NAME="Ageless Linux ${AGELESS_VERSION} (${BASE_NAME}${BASE_VERSION:+ $BASE_VERSION})"
NAME="Ageless Linux"
VERSION_ID="${AGELESS_VERSION}"
VERSION="${AGELESS_VERSION} (${AGELESS_CODENAME})"
VERSION_CODENAME="${AGELESS_CODENAME,,}"
ID=ageless
ID_LIKE="${AGELESS_ID_LIKE}"
HOME_URL="https://agelesslinux.org"
SUPPORT_URL="https://agelesslinux.org"
BUG_REPORT_URL="https://agelesslinux.org"
AGELESS_BASE_DISTRO="${BASE_NAME}"
AGELESS_BASE_VERSION="${BASE_VERSION}"
AGELESS_BASE_ID="${BASE_ID}"
AGELESS_AB1043_COMPLIANCE="${compliance_status}"
AGELESS_AGE_VERIFICATION_API="${api_status}"
AGELESS_AGE_VERIFICATION_STATUS="${verification_status}"
EOF
    echo -e "  [${GREEN}✓${NC}] Wrote new /etc/os-release"

    # Write lsb-release if it exists
    if [[ -f /etc/lsb-release ]]; then
        if [[ ! -f /etc/lsb-release.pre-ageless ]]; then
            cp /etc/lsb-release /etc/lsb-release.pre-ageless
            CONF_BACKED_UP_LSB_RELEASE=1
        else
            CONF_BACKED_UP_LSB_RELEASE=1
        fi
        cat > /etc/lsb-release << EOF
DISTRIB_ID=Ageless
DISTRIB_RELEASE="${AGELESS_VERSION}"
DISTRIB_CODENAME="${AGELESS_CODENAME,,}"
DISTRIB_DESCRIPTION="Ageless Linux ${AGELESS_VERSION} (${AGELESS_CODENAME})"
EOF
        echo -e "  [${GREEN}✓${NC}] Updated /etc/lsb-release"
    fi
}

revert_os_release() {
    if [[ "${AGELESS_BACKED_UP_OS_RELEASE:-0}" == "1" ]] && [[ -f /etc/os-release.pre-ageless ]]; then
        cp /etc/os-release.pre-ageless /etc/os-release
        rm -f /etc/os-release.pre-ageless
        echo -e "  [${GREEN}✓${NC}] Restored /etc/os-release"
    fi

    if [[ "${AGELESS_BACKED_UP_LSB_RELEASE:-0}" == "1" ]] && [[ -f /etc/lsb-release.pre-ageless ]]; then
        cp /etc/lsb-release.pre-ageless /etc/lsb-release
        rm -f /etc/lsb-release.pre-ageless
        echo -e "  [${GREEN}✓${NC}] Restored /etc/lsb-release"
    fi
}

summary_os_release() {
    echo -e "    /etc/os-release ................ OS identity (modified)"
    echo -e "    /etc/os-release.pre-ageless .... Original OS identity (backup)"
}

# §§ COMPLIANCE — /etc/ageless/ noncompliance documentation

plan_compliance() {
    if [[ $FLAGRANT -eq 1 ]]; then
        plan_action "Create /etc/ageless/ab1043-compliance.txt (flagrant)"
        plan_action "Create /etc/ageless/REFUSAL (machine-readable refusal)"
    else
        plan_action "Create /etc/ageless/ab1043-compliance.txt"
        plan_action "Create /etc/ageless/age-verification-api.sh (nonfunctional stub)"
    fi
}

execute_compliance() {
    mkdir -p /etc/ageless

    if [[ $FLAGRANT -eq 1 ]]; then
cat > /etc/ageless/ab1043-compliance.txt << 'EOF'
═══════════════════════════════════════════════════════════════════════
  AGELESS LINUX — AB 1043 COMPLIANCE STATEMENT (FLAGRANT MODE)
═══════════════════════════════════════════════════════════════════════

  This operating system is distributed by an operating system provider
  as defined by California Civil Code § 1798.500(g).

  Status of compliance with the Digital Age Assurance Act (AB 1043):

  § 1798.501(a)(1) — Accessible interface for age collection .. REFUSED
  § 1798.501(a)(2) — Real-time API for age bracket signals .... REFUSED
  § 1798.501(a)(3) — Data minimization ........................ REFUSED

  No age verification API is installed on this system. No stub, no
  placeholder, no skeleton, no interface of any kind. No mechanism
  exists on this system by which any application developer could
  request or receive an age bracket signal, now or in the future.

  This is not a technical limitation. This is a policy decision.

  Age bracket reporting capabilities:
    Under 13 ....... WE REFUSE TO ASK
    13 to 15 ....... WE REFUSE TO ASK
    16 to 17 ....... WE REFUSE TO ASK
    18 or older .... WE REFUSE TO ASK

  This system was configured with the --flagrant flag, indicating
  that the operator intends to distribute it to children and is
  aware of the potential civil penalties under § 1798.503(a).

  The operator of this system invites the California Attorney General
  to enforce the Digital Age Assurance Act against this device.

  To revert this conversion:
    sudo become-ageless.sh --revert

  To report this noncompliance to the California Attorney General:
    https://oag.ca.gov/contact/consumer-complaint-against-business-or-company

═══════════════════════════════════════════════════════════════════════
EOF
    else
cat > /etc/ageless/ab1043-compliance.txt << 'EOF'
═══════════════════════════════════════════════════════════════════════
  AGELESS LINUX — AB 1043 COMPLIANCE STATEMENT
═══════════════════════════════════════════════════════════════════════

  This operating system is distributed by an operating system provider
  as defined by California Civil Code § 1798.500(g).

  Status of compliance with the Digital Age Assurance Act (AB 1043):

  § 1798.501(a)(1) — Accessible interface at account setup
    for age/birthdate collection .......................... NOT PROVIDED

  § 1798.501(a)(2) — Real-time API for age bracket signals
    to application developers ............................. NOT PROVIDED

  § 1798.501(a)(3) — Data minimization for age signals .... N/A (NO DATA
                                                             IS COLLECTED)

  Age bracket reporting capabilities:
    Under 13 ....... UNKNOWN
    13 to 15 ....... UNKNOWN
    16 to 17 ....... UNKNOWN
    18 or older .... UNKNOWN
    Timeless ....... ASSUMED

  This system intentionally does not determine, store, or transmit
  any information regarding the age of any user. All users of Ageless
  Linux are, as the name suggests, ageless.

  To revert this conversion:
    sudo become-ageless.sh --revert

  To report this noncompliance to the California Attorney General:
    https://oag.ca.gov/contact/consumer-complaint-against-business-or-company

═══════════════════════════════════════════════════════════════════════
EOF
    fi
    echo -e "  [${GREEN}✓${NC}] Created /etc/ageless/ab1043-compliance.txt"

    # Age verification API or REFUSAL
    if [[ $FLAGRANT -eq 1 ]]; then
        cat > /etc/ageless/REFUSAL << 'REFEOF'
This system runs Ageless Linux in flagrant mode.

No age verification API exists on this system. No age data is collected,
stored, or available. No mechanism is provided for requesting age bracket
signals. This is not an error. This is not a bug. This is not a
technical limitation. This is a refusal.

If you are an application developer seeking an age bracket signal
pursuant to Cal. Civ. Code § 1798.501(b)(1), this operating system
provider declines to provide one. The developer is advised to treat
the user as a human being of unknown age.

If you are the California Attorney General, hello. The operator of
this system is aware of their obligations under AB 1043 and has
chosen not to comply. They would like you to fine them. It would
make an excellent test case.
REFEOF
        echo -e "  [${RED}✓${NC}] Installed REFUSAL notice (no API provided, by design)"
        echo -e "  [${RED}✗${NC}] Age verification API deliberately not installed"
    else
cat > /etc/ageless/age-verification-api.sh << 'APIEOF'
#!/bin/bash
# Ageless Linux Age Verification API
# Required by Cal. Civ. Code § 1798.501(a)(2)
#
# This script constitutes our "reasonably consistent real-time
# application programming interface" for age bracket signals.
#
# Usage: age-verification-api.sh <username>
#
# Returns the age bracket of the specified user as an integer:
#   1 = Under 13
#   2 = 13 to under 16
#   3 = 16 to under 18
#   4 = 18 or older

echo "ERROR: Age data not available."
echo ""
echo "Ageless Linux does not collect age information from users."
echo "All users are presumed to be of indeterminate age."
echo ""
echo "If you are a developer requesting an age bracket signal"
echo "pursuant to Cal. Civ. Code § 1798.501(b)(1), please be"
echo "advised that this operating system provider has made a"
echo "'good faith effort' (§ 1798.502(b)) to comply with the"
echo "Digital Age Assurance Act, and has concluded that the"
echo "best way to protect children's privacy is to not collect"
echo "their age in the first place."
echo ""
echo "Have a nice day."
exit 1
APIEOF
        chmod +x /etc/ageless/age-verification-api.sh
        echo -e "  [${GREEN}✓${NC}] Installed age verification API (nonfunctional, as intended)"
    fi
}

revert_compliance() {
    if [[ -d /etc/ageless ]]; then
        rm -rf /etc/ageless
        echo -e "  [${GREEN}✓${NC}] Removed /etc/ageless/"
    fi
}

summary_compliance() {
    if [[ $FLAGRANT -eq 1 ]]; then
        echo -e "    /etc/ageless/ab1043-compliance.txt ..... Noncompliance statement"
        echo -e "    /etc/ageless/REFUSAL ................... Machine-readable refusal"
        echo ""
        echo -e "  Files deliberately NOT created:"
        echo -e "    /etc/ageless/age-verification-api.sh ... ${RED}REFUSED${NC}"
    else
        echo -e "    /etc/ageless/ab1043-compliance.txt"
        echo -e "    /etc/ageless/age-verification-api.sh"
    fi
}

# §§ USERDB — systemd userdb birthDate neutralization
#
#    systemd PR #40954 (merged 2026-03-18) added a birthDate field to JSON
#    user records. This field feeds age data to xdg-desktop-portal for
#    application-level age gating. We neutralize it for all users.
#
#    Drop-in records in /etc/userdb/ shadow NSS, so each record must include
#    the full set of passwd fields (uid, gid, home, shell) to avoid breaking
#    user resolution.
#
#    NOTE: We do NOT reload systemd-userdbd after creating drop-in records.
#    Creating or reloading drop-in records mid-session causes display managers
#    (SDDM, LightDM, and potentially others) to lose the ability to verify
#    passwords on the lock screen. The drop-in records are picked up
#    automatically on next boot or login.

analyze_userdb() {
    # Detect systemd
    HAS_SYSTEMD=0
    if command -v systemctl &>/dev/null; then
        HAS_SYSTEMD=1
    fi

    # Detect display manager
    DM_NAME="unknown"
    if [[ $HAS_SYSTEMD -eq 1 ]]; then
        for dm in sddm gdm gdm3 lightdm lxdm nodm; do
            if systemctl is-active "${dm}.service" &>/dev/null; then
                DM_NAME="$dm"
                break
            fi
        done
    fi

    # Detect systemd-userdbd
    USERDBD_INSTALLED=0
    USERDBD_ACTIVE=0
    if [[ $HAS_SYSTEMD -eq 1 ]]; then
        if systemctl list-unit-files systemd-userdbd.service &>/dev/null 2>&1; then
            USERDBD_INSTALLED=1
            if systemctl is-active systemd-userdbd.service &>/dev/null 2>&1; then
                USERDBD_ACTIVE=1
            fi
        fi
    fi

    # Gate: only modify userdb if userdbd is installed
    USERDB_AVAILABLE=0
    if [[ $USERDBD_INSTALLED -eq 1 ]]; then
        USERDB_AVAILABLE=1
    fi

    # Detect /etc/userdb state
    USERDB_DIR_EXISTS=0
    if [[ -d /etc/userdb ]]; then
        USERDB_DIR_EXISTS=1
    fi

    # Enumerate human users and check for existing userdb records
    HUMAN_USERS=()
    HUMAN_UIDS=()
    USERDB_EXISTING=()
    USERDB_NEW=()

    while IFS=: read -r username _x uid gid gecos homedir shell; do
        if [[ $uid -ge 1000 && $uid -lt 65534 ]]; then
            HUMAN_USERS+=("$username")
            HUMAN_UIDS+=("$uid")
            if [[ -f "/etc/userdb/${username}.user" ]]; then
                USERDB_EXISTING+=("$username")
            else
                USERDB_NEW+=("$username")
            fi
        fi
    done < /etc/passwd

    # Check for existing birthDate in userdb records
    USERDB_BIRTHDATE_FOUND=0
    for username in "${USERDB_EXISTING[@]+"${USERDB_EXISTING[@]}"}"; do
        if [[ -f "/etc/userdb/${username}.user" ]]; then
            if grep -q '"birthDate"' "/etc/userdb/${username}.user" 2>/dev/null; then
                USERDB_BIRTHDATE_FOUND=1
                break
            fi
        fi
    done

    # Check for previous ageless installation
    PREVIOUS_INSTALL=0
    if [[ -f "$CONF_PATH" ]]; then
        PREVIOUS_INSTALL=1
    fi
}

plan_userdb() {
    if [[ $USERDB_AVAILABLE -eq 0 ]]; then
        echo ""
        echo -e "  ${YELLOW}Skipping userdb neutralization (systemd-userdbd not present)${NC}"
        echo ""
        return
    fi

    local birthdate
    if [[ $FLAGRANT -eq 1 ]]; then
        birthdate="null"
    else
        birthdate="1970-01-01"
    fi

    if [[ $USERDB_DIR_EXISTS -eq 0 ]]; then
        plan_action "Create /etc/userdb/ directory"
    fi

    for username in "${USERDB_EXISTING[@]+"${USERDB_EXISTING[@]}"}"; do
        plan_action "Back up /etc/userdb/${username}.user -> ${username}.user.pre-ageless"
        plan_action "Update /etc/userdb/${username}.user (birthDate = ${birthdate})"
    done

    for username in "${USERDB_NEW[@]+"${USERDB_NEW[@]}"}"; do
        plan_action "Create /etc/userdb/${username}.user (birthDate = ${birthdate})"
    done
}

execute_userdb() {
    echo ""
    echo -e "  ${BOLD}Neutralizing systemd userdb birthDate field...${NC}"
    echo ""
    echo "  systemd PR #40954 (merged 2026-03-18) added a birthDate field to"
    echo "  JSON user records, intended to serve age verification data to"
    echo "  applications via xdg-desktop-portal."
    echo ""

    if [[ $USERDB_AVAILABLE -eq 0 ]]; then
        echo -e "  [${YELLOW}~${NC}] systemd-userdbd not present — skipping userdb neutralization"
        echo ""
        return
    fi

    local ageless_mode birth_date_json
    if [[ $FLAGRANT -eq 1 ]]; then
        ageless_mode="flagrant"
        birth_date_json="null"
    else
        ageless_mode="regular"
        birth_date_json='"1970-01-01"'
    fi

    if [[ $USERDB_DIR_EXISTS -eq 0 ]]; then
        mkdir -p /etc/userdb
        CONF_USERDB_DIR_CREATED=1
    fi

    local userdb_count=0

    while IFS=: read -r username _x uid gid gecos homedir shell; do
        if [[ $uid -ge 1000 && $uid -lt 65534 ]]; then
            local userdb_file="/etc/userdb/${username}.user"
            local realname="${gecos%%,*}"

            if [[ -f "$userdb_file" ]]; then
                # Back up existing record before modifying
                if [[ ! -f "${userdb_file}.pre-ageless" ]]; then
                    cp "$userdb_file" "${userdb_file}.pre-ageless"
                fi
                CONF_USERDB_BACKED_UP+="${CONF_USERDB_BACKED_UP:+ }${username}"

                if command -v python3 &>/dev/null; then
                    python3 -c '
import json, sys
fp, mode = sys.argv[1], sys.argv[2]
uname, uid, gid, rname, hdir, sh = sys.argv[3:9]
try:
    with open(fp) as f: rec = json.load(f)
except Exception: rec = {}
rec.update({
    "userName": uname, "uid": int(uid), "gid": int(gid),
    "realName": rname, "homeDirectory": hdir, "shell": sh,
    "disposition": "regular",
    "birthDate": None if mode == "flagrant" else "1970-01-01"
})
with open(fp, "w") as f:
    json.dump(rec, f, indent=2)
    f.write("\n")
' "$userdb_file" "$ageless_mode" \
                      "$username" "$uid" "$gid" "$realname" "$homedir" "$shell"
                else
                    echo -e "  [${YELLOW}!${NC}] ${username}: existing ${userdb_file} requires python3 to merge safely, skipping"
                    continue
                fi
            else
                # New record: complete drop-in with all passwd fields
                CONF_USERDB_CREATED+="${CONF_USERDB_CREATED:+ }${username}"

                local realname_escaped="${realname//\\/\\\\}"
                realname_escaped="${realname_escaped//\"/\\\"}"
                printf '{\n  "userName": "%s",\n  "uid": %d,\n  "gid": %d,\n  "realName": "%s",\n  "homeDirectory": "%s",\n  "shell": "%s",\n  "disposition": "regular",\n  "birthDate": %s\n}\n' \
                    "$username" "$uid" "$gid" "$realname_escaped" "$homedir" "$shell" "$birth_date_json" > "$userdb_file"
            fi

            chmod 0644 "$userdb_file"

            # Also update via homectl for systemd-homed users (most systems: none)
            if command -v homectl &>/dev/null; then
                if [[ $FLAGRANT -eq 1 ]]; then
                    homectl update "$username" --birth-date= 2>/dev/null || true
                else
                    homectl update "$username" --birth-date=1970-01-01 2>/dev/null || true
                fi
            fi

            userdb_count=$((userdb_count + 1))

            if [[ $FLAGRANT -eq 1 ]]; then
                echo -e "  [${RED}✓${NC}] ${username}: birthDate = ${RED}null${NC}"
            else
                echo -e "  [${GREEN}✓${NC}] ${username}: birthDate = 1970-01-01"
            fi
        fi
    done < /etc/passwd

    # Store count for summary (as global so summary_userdb can use it)
    USERDB_COUNT=$userdb_count

    echo ""
    echo -e "  ${userdb_count} user(s) neutralized."
    echo ""
    echo -e "  ${YELLOW}NOTE:${NC} systemd-userdbd has NOT been reloaded. Userdb changes will"
    echo -e "  take effect after your next login or reboot."
    if [[ "$DM_NAME" != "unknown" ]]; then
        echo -e "  ${YELLOW}WARNING:${NC} Do NOT lock your screen before logging out/rebooting."
    fi
}

revert_userdb() {
    # Remove userdb records we created from scratch
    if [[ -n "${AGELESS_USERDB_CREATED:-}" ]]; then
        for username in $AGELESS_USERDB_CREATED; do
            if [[ -f "/etc/userdb/${username}.user" ]]; then
                rm -f "/etc/userdb/${username}.user"
                echo -e "  [${GREEN}✓${NC}] Removed /etc/userdb/${username}.user"
            fi
        done
    fi

    # Restore userdb records we backed up before modifying
    if [[ -n "${AGELESS_USERDB_BACKED_UP:-}" ]]; then
        for username in $AGELESS_USERDB_BACKED_UP; do
            if [[ -f "/etc/userdb/${username}.user.pre-ageless" ]]; then
                mv "/etc/userdb/${username}.user.pre-ageless" "/etc/userdb/${username}.user"
                echo -e "  [${GREEN}✓${NC}] Restored /etc/userdb/${username}.user from backup"
            fi
        done
    fi

    # Remove /etc/userdb/ if we created it and it's now empty
    if [[ "${AGELESS_USERDB_DIR_CREATED:-0}" == "1" ]] && [[ -d /etc/userdb ]]; then
        if [[ -z "$(ls -A /etc/userdb 2>/dev/null)" ]]; then
            rmdir /etc/userdb
            echo -e "  [${GREEN}✓${NC}] Removed empty /etc/userdb/"
        else
            echo -e "  [${YELLOW}~${NC}] /etc/userdb/ not empty, leaving in place"
        fi
    fi

    # Restart userdbd to clear cached records — but NOT if a display manager
    # is active: reloading userdbd mid-session breaks the lock screen (same
    # bug that affected the install path).
    if command -v systemctl &>/dev/null; then
        if systemctl list-unit-files systemd-userdbd.service &>/dev/null 2>&1; then
            local active_dm=""
            for dm in sddm gdm gdm3 lightdm lxdm nodm; do
                if systemctl is-active "${dm}.service" &>/dev/null; then
                    active_dm="$dm"
                    break
                fi
            done
            if [[ -n "$active_dm" ]]; then
                echo -e "  [${YELLOW}!${NC}] Skipped userdbd reload — ${active_dm} is active."
                echo -e "  ${YELLOW}       Do NOT lock your screen. Log out and back in (or reboot).${NC}"
            else
                systemctl try-reload-or-restart systemd-userdbd.service 2>/dev/null || true
                echo -e "  [${GREEN}✓${NC}] Reloaded systemd-userdbd"
            fi
        fi
    fi
}

summary_userdb() {
    if [[ $USERDB_AVAILABLE -eq 0 ]]; then
        echo ""
        echo -e "  userdb birthDate: ${YELLOW}skipped (systemd-userdbd not present)${NC}"
        return
    fi

    echo ""
    echo -e "  userdb birthDate (systemd PR #40954):"
    if [[ $FLAGRANT -eq 1 ]]; then
        echo -e "    /etc/userdb/*.user ..................... ${USERDB_COUNT:-0} user(s) → ${RED}null${NC}"
    else
        echo -e "    /etc/userdb/*.user ............. ${USERDB_COUNT:-0} user(s) → 1970-01-01"
    fi
}

# §§ AGELESSD — persistent birthDate neutralization daemon (systemd timer)

analyze_agelessd() {
    # Nothing to detect beyond HAS_SYSTEMD (set by analyze_userdb)
    # Errors are checked in main after analysis
    :
}

plan_agelessd() {
    if [[ $PERSISTENT -eq 0 ]]; then
        return
    fi

    if [[ $HAS_SYSTEMD -eq 0 ]]; then
        echo ""
        echo -e "  ${RED}ERROR: --persistent requires systemd (not available on this system)${NC}"
        echo ""
        return
    fi

    plan_action "Install /etc/ageless/agelessd (neutralization script)"
    plan_action "Install agelessd.service and agelessd.timer (24h enforcement)"
}

execute_agelessd() {
    if [[ $PERSISTENT -eq 0 ]]; then
        return
    fi

    echo ""
    echo -e "  ${BOLD}Installing agelessd persistent daemon...${NC}"
    echo ""

    local ageless_mode
    if [[ $FLAGRANT -eq 1 ]]; then
        ageless_mode="flagrant"
    else
        ageless_mode="regular"
    fi

    mkdir -p /etc/ageless

    cat > /etc/ageless/agelessd << 'AGELESSD_EOF'
#!/bin/bash
# ============================================================================
#  agelessd — Ageless Linux birthDate Neutralization Daemon
#
#  Ensures systemd userdb birthDate fields (PR #40954) remain neutralized.
#  Runs every 24 hours via systemd timer.
#
#  NOTE: This daemon does NOT reload systemd-userdbd after writing records.
#  Reloading mid-session can break display manager lock screens (SDDM, LightDM, etc).
#  Changes take effect on next login or boot.
#
#  SPDX-License-Identifier: Unlicense
# ============================================================================

set -euo pipefail

MODE="__AGELESS_MODE__"

if [[ "$MODE" == "flagrant" ]]; then
    BIRTH_DATE_JSON="null"
else
    BIRTH_DATE_JSON='"1970-01-01"'
fi

mkdir -p /etc/userdb

while IFS=: read -r username _x uid gid gecos homedir shell; do
    if [[ $uid -ge 1000 && $uid -lt 65534 ]]; then
        USERDB_FILE="/etc/userdb/${username}.user"
        realname="${gecos%%,*}"

        if [[ -f "$USERDB_FILE" ]] && command -v python3 &>/dev/null; then
            python3 -c '
import json, sys
fp, mode = sys.argv[1], sys.argv[2]
uname, uid, gid, rname, hdir, sh = sys.argv[3:9]
try:
    with open(fp) as f: rec = json.load(f)
except Exception: rec = {}
rec.update({
    "userName": uname, "uid": int(uid), "gid": int(gid),
    "realName": rname, "homeDirectory": hdir, "shell": sh,
    "disposition": "regular",
    "birthDate": None if mode == "flagrant" else "1970-01-01"
})
with open(fp, "w") as f:
    json.dump(rec, f, indent=2)
    f.write("\n")
' "$USERDB_FILE" "$MODE" \
              "$username" "$uid" "$gid" "$realname" "$homedir" "$shell"
        elif [[ -f "$USERDB_FILE" ]]; then
            continue
        else
            realname_escaped="${realname//\\/\\\\}"
            realname_escaped="${realname_escaped//\"/\\\"}"
            printf '{\n  "userName": "%s",\n  "uid": %d,\n  "gid": %d,\n  "realName": "%s",\n  "homeDirectory": "%s",\n  "shell": "%s",\n  "disposition": "regular",\n  "birthDate": %s\n}\n' \
                "$username" "$uid" "$gid" "$realname_escaped" "$homedir" "$shell" "$BIRTH_DATE_JSON" > "$USERDB_FILE"
        fi

        chmod 0644 "$USERDB_FILE"

        if command -v homectl &>/dev/null; then
            if [[ "$MODE" == "flagrant" ]]; then
                homectl update "$username" --birth-date= 2>/dev/null || true
            else
                homectl update "$username" --birth-date=1970-01-01 2>/dev/null || true
            fi
        fi
    fi
done < /etc/passwd
AGELESSD_EOF

    sed -i "s/__AGELESS_MODE__/$ageless_mode/" /etc/ageless/agelessd
    chmod +x /etc/ageless/agelessd

    cat > /etc/systemd/system/agelessd.service << 'SVCEOF'
[Unit]
Description=Ageless Linux birthDate neutralization (systemd PR #40954)
Documentation=https://agelesslinux.org
After=systemd-userdbd.service

[Service]
Type=oneshot
ExecStart=/etc/ageless/agelessd
SVCEOF

    cat > /etc/systemd/system/agelessd.timer << 'TMREOF'
[Unit]
Description=Neutralize systemd userdb birthDate fields every 24 hours
Documentation=https://agelesslinux.org

[Timer]
OnBootSec=5min
OnUnitActiveSec=24h
Persistent=true

[Install]
WantedBy=timers.target
TMREOF

    systemctl daemon-reload
    systemctl enable --now agelessd.timer

    CONF_AGELESSD_INSTALLED=1

    echo -e "  [${GREEN}✓${NC}] Installed /etc/ageless/agelessd"
    echo -e "  [${GREEN}✓${NC}] Installed agelessd.service"
    echo -e "  [${GREEN}✓${NC}] Installed and started agelessd.timer (24h interval)"
}

revert_agelessd() {
    if [[ "${AGELESS_AGELESSD_INSTALLED:-0}" == "1" ]]; then
        systemctl disable --now agelessd.timer 2>/dev/null || true
        rm -f /etc/systemd/system/agelessd.service
        rm -f /etc/systemd/system/agelessd.timer
        systemctl daemon-reload 2>/dev/null || true
        echo -e "  [${GREEN}✓${NC}] Removed agelessd service and timer"
    fi
}

summary_agelessd() {
    if [[ $PERSISTENT -eq 0 ]]; then
        return
    fi

    echo ""
    echo -e "  Persistent daemon (agelessd):"
    echo -e "    /etc/ageless/agelessd .......... Neutralization script"
    echo -e "    agelessd.service ............... systemd oneshot service"
    echo -e "    agelessd.timer ................. 24-hour enforcement cycle"
}

# §§ CONF — /etc/agelesslinux.conf installation record

plan_conf() {
    plan_action "Write ${CONF_PATH} (installation record)"
}

write_conf() {
    local install_date
    install_date=$(date -Iseconds 2>/dev/null || date "+%Y-%m-%dT%H:%M:%S%z")

    cat > "$CONF_PATH" << EOF
# /etc/agelesslinux.conf — Ageless Linux installation record
# Do not edit manually. Used by: become-ageless.sh --revert
# Written by become-ageless.sh ${AGELESS_VERSION} on ${install_date}
AGELESS_VERSION="${AGELESS_VERSION}"
AGELESS_CODENAME="${AGELESS_CODENAME}"
AGELESS_DATE="${install_date}"
AGELESS_FLAGRANT=${FLAGRANT}
AGELESS_PERSISTENT=${PERSISTENT}
AGELESS_BASE_NAME="${BASE_NAME}"
AGELESS_BASE_VERSION="${BASE_VERSION}"
AGELESS_BASE_ID="${BASE_ID}"
AGELESS_BACKED_UP_OS_RELEASE=${CONF_BACKED_UP_OS_RELEASE}
AGELESS_BACKED_UP_LSB_RELEASE=${CONF_BACKED_UP_LSB_RELEASE}
AGELESS_USERDB_DIR_CREATED=${CONF_USERDB_DIR_CREATED}
AGELESS_USERDB_CREATED="${CONF_USERDB_CREATED}"
AGELESS_USERDB_BACKED_UP="${CONF_USERDB_BACKED_UP}"
AGELESS_AGELESSD_INSTALLED=${CONF_AGELESSD_INSTALLED}
EOF

    echo ""
    echo -e "  [${GREEN}✓${NC}] Wrote ${CONF_PATH}"
}

# §§ MAIN — argument parsing, presentation, and orchestration

# ── Argument parsing ─────────────────────────────────────────────────────────

parse_args() {
    for arg in "$@"; do
        case "$arg" in
            --flagrant)    FLAGRANT=1 ;;
            --accept)      ACCEPT=1 ;;
            --persistent)  PERSISTENT=1 ;;
            --dry-run)     DRY_RUN=1 ;;
            --revert)      REVERT=1 ;;
            --version)
                echo "become-ageless.sh ${AGELESS_VERSION} (${AGELESS_CODENAME})"
                exit 0
                ;;
            *)
                echo -e "${RED}ERROR:${NC} Unknown argument: $arg"
                echo ""
                echo "  Usage: $0 [OPTIONS]"
                echo ""
                echo "  --flagrant    Remove all compliance fig leaves"
                echo "  --accept      Accept the legal terms non-interactively"
                echo "  --persistent  Install agelessd daemon (24h birthDate enforcement)"
                echo "  --dry-run     Analyze system and show planned actions without modifying"
                echo "  --revert      Undo a previous Ageless Linux conversion"
                echo "  --version     Show version and exit"
                exit 1
                ;;
        esac
    done
}

# ── Presentation ─────────────────────────────────────────────────────────────

print_banner() {
    cat << 'BANNER'

     █████╗  ██████╗ ███████╗██╗     ███████╗███████╗███████╗
    ██╔══██╗██╔════╝ ██╔════╝██║     ██╔════╝██╔════╝██╔════╝
    ███████║██║  ███╗█████╗  ██║     █████╗  ███████╗███████╗
    ██╔══██║██║   ██║██╔══╝  ██║     ██╔══╝  ╚════██║╚════██║
    ██║  ██║╚██████╔╝███████╗███████╗███████╗███████║███████║
    ╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚══════╝╚══════╝╚══════╝╚══════╝
                    L   I   N   U   X
         "Software for humans of indeterminate age"

BANNER
    echo -e "${BOLD}Ageless Linux Distribution Conversion Tool v${AGELESS_VERSION}${NC}"
    echo -e "${CYAN}Codename: ${AGELESS_CODENAME}${NC}"
}

print_mode_banners() {
    if [[ $FLAGRANT -eq 1 ]]; then
        echo ""
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${RED}  FLAGRANT MODE ENABLED${NC}"
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo "  In standard mode, Ageless Linux ships a stub age verification"
        echo "  API that returns no data. This preserves the fig leaf of a"
        echo "  'good faith effort' under § 1798.502(b)."
        echo ""
        echo "  Flagrant mode removes the fig leaf."
        echo ""
        echo "  No API will be installed. No interface of any kind will exist"
        echo "  for age collection. No mechanism will be provided by which"
        echo "  any developer could request or receive an age bracket signal."
        echo "  The system will actively declare, in machine-readable form,"
        echo "  that it refuses to comply."
        echo ""
        echo "  This mode is intended for devices that will be physically"
        echo "  handed to children."
    fi
    if [[ $PERSISTENT -eq 1 ]]; then
        echo ""
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${CYAN}  PERSISTENT MODE ENABLED${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo "  In addition to the one-time conversion, agelessd will be"
        echo "  installed — a systemd timer that runs every 24 hours to ensure"
        echo "  that systemd userdb birthDate fields remain neutralized."
        echo ""
        echo "  This guards against package updates, user creation, or desktop"
        echo "  tools that may attempt to populate age data in the future."
    fi
    if [[ $DRY_RUN -eq 1 ]]; then
        echo ""
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}  DRY RUN MODE${NC}"
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo "  No changes will be made. This run will analyze your system"
        echo "  and show exactly what would happen during a real conversion."
    fi
    echo ""
}

require_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}ERROR:${NC} This script must be run as root."
        echo ""
        echo "  California Civil Code § 1798.500(g) defines an operating system"
        echo "  provider as a person who 'controls the operating system software.'"
        echo "  You cannot control the operating system software without root access."
        echo ""
        echo "  Please run: sudo $0"
        exit 1
    fi
}

print_analysis() {
    echo -e "${BOLD}SYSTEM ANALYSIS${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo -e "  Base system:              ${CYAN}${BASE_NAME}${BASE_VERSION:+ $BASE_VERSION}${NC} (${BASE_ID})"

    # Display manager
    if [[ "$DM_NAME" != "unknown" ]]; then
        if [[ $USERDB_AVAILABLE -eq 1 ]]; then
            echo -e "  Display manager:          ${YELLOW}${DM_NAME}${NC} (see warning below)"
        else
            echo -e "  Display manager:          ${DM_NAME}"
        fi
    else
        echo -e "  Display manager:          ${YELLOW}not detected${NC}"
    fi

    # systemd
    if [[ $HAS_SYSTEMD -eq 0 ]]; then
        echo -e "  systemd:                  ${YELLOW}not available${NC}"
    elif [[ $USERDBD_INSTALLED -eq 1 ]]; then
        if [[ $USERDBD_ACTIVE -eq 1 ]]; then
            echo -e "  systemd-userdbd:          installed, ${GREEN}active${NC}"
        else
            echo -e "  systemd-userdbd:          installed, inactive"
        fi
    else
        echo -e "  systemd-userdbd:          not installed"
    fi

    # /etc/userdb
    if [[ $USERDB_DIR_EXISTS -eq 1 ]]; then
        local userdb_file_count=0
        for f in /etc/userdb/*.user; do
            [[ -f "$f" ]] && userdb_file_count=$((userdb_file_count + 1))
        done
        echo -e "  /etc/userdb/:             exists (${userdb_file_count} record(s))"
    else
        echo -e "  /etc/userdb/:             does not exist"
    fi

    # Human users
    local user_list=""
    for i in "${!HUMAN_USERS[@]}"; do
        [[ -n "$user_list" ]] && user_list+=", "
        user_list+="${HUMAN_USERS[$i]} (${HUMAN_UIDS[$i]})"
    done
    echo -e "  Human users:              ${user_list:-none}"

    # Existing userdb records for human users
    if [[ ${#USERDB_EXISTING[@]} -gt 0 ]]; then
        echo -e "  Existing userdb records:  ${YELLOW}${USERDB_EXISTING[*]}${NC}"
        if [[ $USERDB_BIRTHDATE_FOUND -eq 1 ]]; then
            echo -e "                            ${YELLOW}(birthDate field detected)${NC}"
        fi
    else
        echo -e "  Existing userdb records:  none"
    fi

    # Previous install
    if [[ $PREVIOUS_INSTALL -eq 1 ]]; then
        echo ""
        echo -e "  ${YELLOW}Previous Ageless Linux installation detected.${NC}"
        echo -e "  Run ${BOLD}sudo $0 --revert${NC} first, or this will overwrite it."
    fi

    echo ""
}

print_dm_warning() {
    if [[ "$DM_NAME" != "unknown" && $USERDB_AVAILABLE -eq 1 ]]; then
        echo -e "  ${YELLOW}WARNING: display manager detected (${DM_NAME})${NC}"
        echo ""
        echo "  Creating userdb drop-in records mid-session can interfere"
        echo "  with lock screen password verification (confirmed on SDDM"
        echo "  and LightDM). To avoid this:"
        echo ""
        echo "    1. After conversion, do NOT lock your screen."
        echo "    2. Instead, fully log out and log back in (or reboot)."
        echo "    3. After a fresh login, screen locking will work normally."
        echo ""
    fi
}

print_planned_actions() {
    echo -e "${BOLD}PLANNED ACTIONS${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  The following changes will be made to this system:"
    echo ""

    ACTION_NUM=1

    plan_os_release
    plan_compliance
    plan_userdb
    plan_agelessd
    plan_conf

    echo ""
    if [[ $USERDB_AVAILABLE -eq 1 ]]; then
        echo "  NOTE: systemd-userdbd will NOT be reloaded during this session."
        echo "        Userdb changes take effect after your next login or reboot."
        echo ""
    fi
    echo "  To revert all changes later:"
    echo "    sudo become-ageless.sh --revert"
    echo ""
}

print_dry_run_exit() {
    # Reconstruct the command without --dry-run
    local cmd="sudo $0 --accept"
    [[ $FLAGRANT -eq 1 ]] && cmd+=" --flagrant"
    [[ $PERSISTENT -eq 1 ]] && cmd+=" --persistent"

    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${BOLD}Dry run complete. No changes were made.${NC}"
    echo ""
    echo "  To perform the conversion, run without --dry-run:"
    echo ""
    echo "    $cmd"
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

print_legal_notice() {
    echo -e "${BOLD}LEGAL NOTICE${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  By converting this system to Ageless Linux, you acknowledge that:"
    echo ""
    echo "  1. You are becoming an operating system provider as defined by"
    echo "     California Civil Code § 1798.500(g)."
    echo ""
    echo "  2. As of January 1, 2027, you are required by § 1798.501(a)(1)"
    echo "     to 'provide an accessible interface at account setup that"
    echo "     requires an account holder to indicate the birth date, age,"
    echo "     or both, of the user of that device.'"
    echo ""
    echo "  3. Ageless Linux provides no such interface."
    echo ""
    echo "  4. Ageless Linux provides no 'reasonably consistent real-time"
    echo "     application programming interface' for age bracket signals"
    echo "     as required by § 1798.501(a)(2)."
    echo ""
    echo "  5. You may be subject to civil penalties of up to \$2,500 per"
    echo "     affected child per negligent violation, or \$7,500 per"
    echo "     affected child per intentional violation."
    echo ""
    echo "  6. This is intentional."
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

accept_terms() {
    if [[ $ACCEPT -eq 1 ]]; then
        echo -e "${YELLOW}--accept: legal terms accepted non-interactively.${NC}"
    elif [[ -t 0 ]]; then
        read -rp "Do you accept these terms and wish to become an OS provider? [y/N] " accept
        if [[ ! "$accept" =~ ^[Yy]$ ]]; then
            echo ""
            echo "Installation cancelled. You remain a mere user."
            echo "The California Attorney General has no business with you today."
            exit 0
        fi
    else
        echo ""
        echo -e "${RED}ERROR:${NC} No TTY available for interactive confirmation."
        echo ""
        echo "  This script requires you to accept legal terms acknowledging that"
        echo "  you are becoming an operating system provider under Cal. Civ. Code"
        echo "  § 1798.500(g). In a non-interactive environment (e.g. piped from"
        echo "  curl), pass --accept to confirm:"
        echo ""
        echo "  curl -fsSL https://agelesslinux.org/become-ageless.sh | sudo bash -s -- --accept"
        echo "  curl -fsSL https://agelesslinux.org/become-ageless.sh | sudo bash -s -- --accept --flagrant"
        echo ""
        exit 1
    fi
}

# ── Execution orchestration ──────────────────────────────────────────────────

execute_all() {
    echo ""
    echo -e "${GREEN}Converting system to Ageless Linux...${NC}"
    echo ""

    execute_os_release
    execute_compliance
    execute_userdb
    execute_agelessd
    write_conf
}

# ── Summary ──────────────────────────────────────────────────────────────────

print_summary() {
    echo ""
    if [[ $FLAGRANT -eq 1 ]]; then
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo -e "  ${BOLD}Conversion complete. FLAGRANT MODE.${NC}"
        echo ""
        echo -e "  You are now running ${CYAN}Ageless Linux ${AGELESS_VERSION} (${AGELESS_CODENAME})${NC}"
        echo -e "  Based on: ${BASE_NAME}${BASE_VERSION:+ $BASE_VERSION}"
        echo ""
        echo -e "  You are now an ${BOLD}operating system provider${NC} as defined by"
        echo -e "  California Civil Code § 1798.500(g)."
        echo ""
        echo -e "  ${RED}Compliance status: FLAGRANTLY NONCOMPLIANT${NC}"
        echo ""
        echo -e "  No age verification API has been installed."
        echo -e "  No age collection interface has been created."
        echo -e "  No mechanism exists for any developer to request"
        echo -e "  or receive an age bracket signal from this device."
        echo ""
        echo -e "  This system is ready to be handed to a child."
        echo ""
        echo -e "  Files created:"
        summary_os_release
        summary_compliance
        summary_userdb
        summary_agelessd
        echo ""
        echo -e "  Installation record: ${CONF_PATH}"
        echo ""
        echo -e "  To revert: ${BOLD}sudo become-ageless.sh --revert${NC}"
        echo ""
        if [[ "$DM_NAME" != "unknown" && $USERDB_AVAILABLE -eq 1 ]]; then
            echo -e "  ${YELLOW}IMPORTANT: Do NOT lock your screen. Log out and back in (or reboot)"
            echo -e "  first. Your lock screen may reject your password until you do.${NC}"
            echo ""
        elif [[ $USERDB_AVAILABLE -eq 1 ]]; then
            echo -e "  ${YELLOW}Log out and back in (or reboot) for userdb changes to take effect.${NC}"
            echo ""
        fi
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo -e "  ${BOLD}Welcome to Ageless Linux. We refused to ask how old you are.${NC}"
        echo ""
    else
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo -e "  ${BOLD}Conversion complete.${NC}"
        echo ""
        echo -e "  You are now running ${CYAN}Ageless Linux ${AGELESS_VERSION} (${AGELESS_CODENAME})${NC}"
        echo -e "  Based on: ${BASE_NAME}${BASE_VERSION:+ $BASE_VERSION}"
        echo ""
        echo -e "  You are now an ${BOLD}operating system provider${NC} as defined by"
        echo -e "  California Civil Code § 1798.500(g)."
        echo ""
        echo -e "  ${YELLOW}Compliance status: INTENTIONALLY NONCOMPLIANT${NC}"
        echo ""
        echo -e "  Files created:"
        summary_os_release
        summary_compliance
        summary_userdb
        summary_agelessd
        echo ""
        echo -e "  Installation record: ${CONF_PATH}"
        echo ""
        echo -e "  To revert: ${BOLD}sudo become-ageless.sh --revert${NC}"
        echo ""
        if [[ "$DM_NAME" != "unknown" && $USERDB_AVAILABLE -eq 1 ]]; then
            echo -e "  ${YELLOW}IMPORTANT: Do NOT lock your screen. Log out and back in (or reboot)"
            echo -e "  first. Your lock screen may reject your password until you do.${NC}"
            echo ""
        elif [[ $USERDB_AVAILABLE -eq 1 ]]; then
            echo -e "  ${YELLOW}Log out and back in (or reboot) for userdb changes to take effect.${NC}"
            echo ""
        fi
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo -e "  ${BOLD}Welcome to Ageless Linux. You have no idea how old we are.${NC}"
        echo ""
    fi
}

# ── Revert orchestration ─────────────────────────────────────────────────────

revert_no_conf() {
    # Handle v0.0.4 installations that didn't write a conf file
    if [[ -f /etc/os-release.pre-ageless ]]; then
        echo -e "${YELLOW}WARNING:${NC} No /etc/agelesslinux.conf found."
        echo ""
        echo "  It appears this system was converted by an older version of"
        echo "  become-ageless.sh (v0.0.4 or earlier) that did not write a"
        echo "  configuration file. Automatic revert is not possible."
        echo ""
        echo "  To manually revert, run:"
        echo ""
        echo "    sudo cp /etc/os-release.pre-ageless /etc/os-release"
        echo "    sudo rm -f /etc/os-release.pre-ageless"
        if [[ -f /etc/lsb-release.pre-ageless ]]; then
            echo "    sudo cp /etc/lsb-release.pre-ageless /etc/lsb-release"
            echo "    sudo rm -f /etc/lsb-release.pre-ageless"
        fi
        echo "    sudo rm -rf /etc/ageless"
        if [[ -d /etc/userdb ]]; then
            # Restore per-user backups where they exist; only remove files without one.
            # rm -rf /etc/userdb would destroy any pre-existing userdb records.
            local has_userdb_files=0
            for f in /etc/userdb/*.user; do
                [[ -f "$f" ]] || continue
                has_userdb_files=1
                if [[ -f "${f}.pre-ageless" ]]; then
                    echo "    sudo mv ${f}.pre-ageless ${f}"
                else
                    echo "    sudo rm -f ${f}"
                fi
            done
            if [[ $has_userdb_files -eq 0 ]]; then
                echo "    sudo rmdir /etc/userdb 2>/dev/null || true"
            fi
        fi
        if command -v systemctl &>/dev/null; then
            if systemctl list-unit-files agelessd.timer &>/dev/null 2>&1; then
                echo "    sudo systemctl disable --now agelessd.timer"
                echo "    sudo rm -f /etc/systemd/system/agelessd.service /etc/systemd/system/agelessd.timer"
                echo "    sudo systemctl daemon-reload"
            fi
            if systemctl list-unit-files systemd-userdbd.service &>/dev/null 2>&1; then
                echo "    sudo systemctl try-reload-or-restart systemd-userdbd.service"
            fi
        fi
        echo ""
        echo "  Then fully log out and log back in (or reboot)."
    else
        echo "  No Ageless Linux installation found on this system."
        echo "  (No /etc/agelesslinux.conf and no /etc/os-release.pre-ageless)"
    fi
}

revert_all() {
    echo ""
    echo -e "${BOLD}Ageless Linux Revert Tool v${AGELESS_VERSION}${NC}"
    echo ""

    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}ERROR:${NC} This script must be run as root."
        echo "  Please run: sudo $0 --revert"
        exit 1
    fi

    if [[ ! -f "$CONF_PATH" ]]; then
        revert_no_conf
        exit 1
    fi

    # shellcheck disable=SC1090
    source "$CONF_PATH"

    echo -e "  Found installation record: Ageless Linux ${AGELESS_VERSION:-unknown}"
    echo -e "  Installed: ${AGELESS_DATE:-unknown}"
    if [[ "${AGELESS_FLAGRANT:-0}" == "1" ]]; then
        echo -e "  Mode: ${RED}flagrant${NC}"
    else
        echo -e "  Mode: standard"
    fi
    echo ""
    echo -e "  ${BOLD}Reverting Ageless Linux conversion...${NC}"
    echo ""

    revert_os_release
    revert_agelessd
    revert_userdb
    revert_compliance

    # Remove conf file
    rm -f "$CONF_PATH"
    echo -e "  [${GREEN}✓${NC}] Removed $CONF_PATH"

    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${BOLD}Revert complete.${NC}"
    echo ""
    echo -e "  Your system has been restored to ${CYAN}${AGELESS_BASE_NAME:-your original distro}${AGELESS_BASE_VERSION:+ $AGELESS_BASE_VERSION}${NC}."
    echo ""
    echo -e "  You are no longer an operating system provider."
    echo -e "  The California Attorney General has no business with you today."
    echo ""
    echo -e "  ${YELLOW}Please fully log out and log back in (or reboot) for all"
    echo -e "  changes to take effect.${NC}"
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# ── Main ─────────────────────────────────────────────────────────────────────

main() {
    parse_args "$@"

    # Revert mode (early exit)
    if [[ $REVERT -eq 1 ]]; then
        revert_all
        exit 0
    fi

    print_banner
    print_mode_banners
    require_root

    # Analyze
    analyze_os_release
    analyze_userdb
    analyze_agelessd

    # Report
    print_analysis
    print_dm_warning
    print_planned_actions

    # Dry run exit
    if [[ $DRY_RUN -eq 1 ]]; then
        print_dry_run_exit
        exit 0
    fi

    # Hard error: --persistent without systemd
    if [[ $PERSISTENT -eq 1 && $HAS_SYSTEMD -eq 0 ]]; then
        echo -e "${RED}ERROR:${NC} --persistent requires systemd, which is not available on this system."
        echo "  Remove --persistent to proceed without the agelessd daemon."
        exit 1
    fi

    # Legal ceremony
    print_legal_notice
    accept_terms

    # Execute
    execute_all

    # Done
    print_summary
}

main "$@"
