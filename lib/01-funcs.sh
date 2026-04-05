# §§ FUNCS — become-ageless.sh setup and utilities

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

AGELESS_VERSION="0.1.0"
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
