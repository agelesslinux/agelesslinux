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
