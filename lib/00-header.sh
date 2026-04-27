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
