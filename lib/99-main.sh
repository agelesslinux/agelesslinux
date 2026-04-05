# §§ MAIN — argument parsing, presentation, and orchestration

# ── Argument parsing ─────────────────────────────────────────────────────────

parse_args() {
    # Default to en-US if no lang is given (prevents deadlock for error message below)
    set_lang "en-US"

    # We do some parsin'
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
            --lang=*)
                if [[ "${VALID_LANGS[*]}" =~ "${arg#*=}" ]]; then
                  set_lang "${arg#*=}"
                else
                  echo -e "${I18N_99_ARGBLURB_WRONGLANG}"
                  echo ""
                  echo "${VALID_LANGS[*]}"
                  exit 1
                fi
                ;;
            *)
                echo -e "${I18N_99_ARGBLURB_UNKNOWN}: $arg"
                echo ""
                echo "  ${I18N_99_ARGBLURB_USAGE}: $0 [OPTIONS]"
                echo ""
                echo "  --lang=xx-YY  ${I18N_99_ARGBLURB_LANG}"
                echo "  --flagrant    ${I18N_99_ARGBLURB_FLAGRANT}"
                echo "  --accept      ${I18N_99_ARGBLURB_ACCEPT}"
                echo "  --persistent  ${I18N_99_ARGBLURB_PERSISTENT}"
                echo "  --dry-run     ${I18N_99_ARGBLURB_DRYRUN}"
                echo "  --revert      ${I18N_99_ARGBLURB_REVERT}"
                echo "  --version     ${I18N_99_ARGBLURB_VERSION}"
                exit 1
                ;;
        esac
    done
}

# ── Presentation ─────────────────────────────────────────────────────────────

print_banner() {
    cat << BANNER

     █████╗  ██████╗ ███████╗██╗     ███████╗███████╗███████╗
    ██╔══██╗██╔════╝ ██╔════╝██║     ██╔════╝██╔════╝██╔════╝
    ███████║██║  ███╗█████╗  ██║     █████╗  ███████╗███████╗
    ██╔══██║██║   ██║██╔══╝  ██║     ██╔══╝  ╚════██║╚════██║
    ██║  ██║╚██████╔╝███████╗███████╗███████╗███████║███████║
    ╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚══════╝╚══════╝╚══════╝╚══════╝
                    L   I   N   U   X
         "${I18N_99_MOTTO}"

BANNER
    echo -e "${BOLD}${I18N_99_TITLE} v${AGELESS_VERSION}${NC}"
    echo -e "${CYAN}${I18N_99_CODENAME}: ${AGELESS_CODENAME}${NC}"
}

print_mode_banners() {
    if [[ $FLAGRANT -eq 1 ]]; then
        echo ""
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${RED}  ${I18N_99_MODE_FLAGRANT_TITLE}${NC}"
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo "  ${I18N_99_MODE_FLAGRANT_P1L1}"
        echo "  ${I18N_99_MODE_FLAGRANT_P1L2}"
        echo "  ${I18N_99_MODE_FLAGRANT_P1L3}"
        echo ""
        echo "  ${I18N_99_MODE_FLAGRANT_P2L1}"
        echo ""
        echo "  ${I18N_99_MODE_FLAGRANT_P3L1}"
        echo "  ${I18N_99_MODE_FLAGRANT_P3L2}"
        echo "  ${I18N_99_MODE_FLAGRANT_P3L3}"
        echo "  ${I18N_99_MODE_FLAGRANT_P3L4}"
        echo "  ${I18N_99_MODE_FLAGRANT_P3L5}"
        echo ""
        echo "  ${I18N_99_MODE_FLAGRANT_P4L1}"
        echo "  ${I18N_99_MODE_FLAGRANT_P4L2}"
    fi
    if [[ $PERSISTENT -eq 1 ]]; then
        echo ""
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${CYAN}  ${I18N_99_MODE_PERSISTENT_TITLE}${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo "  ${I18N_99_MODE_PERSISTENT_P1L1}"
        echo "  ${I18N_99_MODE_PERSISTENT_P1L2}"
        echo "  ${I18N_99_MODE_PERSISTENT_P1L3}"
        echo ""
        echo "  ${I18N_99_MODE_PERSISTENT_P2L1}"
        echo "  ${I18N_99_MODE_PERSISTENT_P2L2}"
    fi
    if [[ $DRY_RUN -eq 1 ]]; then
        echo ""
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}  ${I18N_99_MODE_DRYRUN_TITLE}${NC}"
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo "  ${I18N_99_MODE_DRYRUN_P1L1}"
        echo "  ${I18N_99_MODE_DRYRUN_P1L2}"
    fi
    echo ""
}

require_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${I18N_99_ROOTBLURB_TITLE}"
        echo ""
        echo "  ${I18N_99_ROOTBLURB_P1L1}"
        echo "  ${I18N_99_ROOTBLURB_P1L2}"
        echo "  ${I18N_99_ROOTBLURB_P1L3}"
        echo ""
        echo "  ${I18N_99_ROOTBLURB_PLEASERUN}: sudo $0"
        exit 1
    fi
}

print_analysis() {
    echo -e "${BOLD}${I18N_99_SYSTEMANALYSIS}${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo -e "  ${I18N_99_BASESYSTEM}:             ${CYAN}${BASE_NAME}${BASE_VERSION:+ $BASE_VERSION}${NC} (${BASE_ID})"

    # Display manager
    if [[ "$DM_NAME" != "unknown" ]]; then
        if [[ $USERDB_AVAILABLE -eq 1 ]]; then
            echo -e "  ${I18N_99_DISPLAYMANAGER}:          ${YELLOW}${DM_NAME}${NC} (${I18N_99_SEEWARNINGBELOW})"
        else
            echo -e "  ${I18N_99_DISPLAYMANAGER}:          ${DM_NAME}"
        fi
    else
        echo -e "  ${I18N_99_DISPLAYMANAGER}:          ${YELLOW}${I18N_99_NOTDETECTED}${NC}"
    fi

    # systemd
    if [[ $HAS_SYSTEMD -eq 0 ]]; then
        echo -e "  systemd:                  ${YELLOW}${I18N_99_NOTAVAILABLE}${NC}"
    elif [[ $USERDBD_INSTALLED -eq 1 ]]; then
        if [[ $USERDBD_ACTIVE -eq 1 ]]; then
            echo -e "  systemd-userdbd:          ${I18N_99_INSTALLED}, ${GREEN}${I18N_99_ACTIVE}${NC}"
        else
            echo -e "  systemd-userdbd:          ${I18N_99_INSTALLED}, ${I18N_99_INACTIVE}"
        fi
    else
        echo -e "  systemd-userdbd:          ${I18N_99_NOTINSTALLED}"
    fi

    # /etc/userdb
    if [[ $USERDB_DIR_EXISTS -eq 1 ]]; then
        local userdb_file_count=0
        for f in /etc/userdb/*.user; do
            [[ -f "$f" ]] && userdb_file_count=$((userdb_file_count + 1))
        done
        echo -e "  /etc/userdb/:             ${I18N_99_EXISTS} (${userdb_file_count} ${I18N_99_RECORDS})"
    else
        echo -e "  /etc/userdb/:             ${I18N_99_DOESNOTEXIST}"
    fi

    # Human users
    local user_list=""
    for i in "${!HUMAN_USERS[@]}"; do
        [[ -n "$user_list" ]] && user_list+=", "
        user_list+="${HUMAN_USERS[$i]} (${HUMAN_UIDS[$i]})"
    done
    echo -e "  ${I18N_99_HUMANUSERS}:         ${user_list:-none}"

    # Existing userdb records for human users
    if [[ ${#USERDB_EXISTING[@]} -gt 0 ]]; then
        echo -e "  ${I18N_99_EXISTING_USERDB_RECORDS}:  ${YELLOW}${USERDB_EXISTING[*]}${NC}"
        if [[ $USERDB_BIRTHDATE_FOUND -eq 1 ]]; then
            echo -e "                            ${YELLOW}(${I18N_99_BIRTHDATE_FIELD_DETECTED})${NC}"
        fi
    else
        echo -e "  ${I18N_99_EXISTING_USERDB_RECORDS}:  ${I18N_99_NONE}"
    fi

    # Previous install
    if [[ $PREVIOUS_INSTALL -eq 1 ]]; then
        echo ""
        echo -e "  ${YELLOW}${I18N_99_PREVIOUS_AGELESS1}${NC}"
        echo -e "  ${I18N_99_PREVIOUS_AGELESS2}"
    fi

    echo ""
}

print_dm_warning() {
    if [[ "$DM_NAME" != "unknown" && $USERDB_AVAILABLE -eq 1 ]]; then
        echo -e "  ${YELLOW}${I18N_99_DM_DETECTED} (${DM_NAME})${NC}"
        echo ""
        echo "  ${I18N_99_DM_P1L1}"
        echo "  ${I18N_99_DM_P1L2}"
        echo "  ${I18N_99_DM_P1L3}"
        echo ""
        echo "    ${I18N_99_DM_P2L1}"
        echo "    ${I18N_99_DM_P2L2}"
        echo "    ${I18N_99_DM_P2L3}"
        echo ""
    fi
}


print_planned_actions() {
    echo -e "${BOLD}${I18N_99_PLANNED_TITLE}${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  ${I18N_99_PLANNED_BRIEF}"
    echo ""

    ACTION_NUM=1

    plan_os_release
    plan_compliance
    plan_userdb
    plan_agelessd
    plan_conf

    echo ""
    if [[ $USERDB_AVAILABLE -eq 1 ]]; then
        echo "  ${I18N_99_PLANNED_USERDB1}"
        echo "        ${I18N_99_PLANNED_USERDB2}"
        echo ""
    fi
    echo "  ${I18N_99_PLANNED_REVERT}"
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
    echo -e "  ${BOLD}${I18N_99_DRYRUN_BLURB1}${NC}"
    echo ""
    echo "  ${I18N_99_DRYRUN_BLURB2}"
    echo ""
    echo "    $cmd"
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

print_legal_notice() {
    echo -e "${BOLD}${I18N_99_LEGALNOTICE_TITLE}${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  ${I18N_99_LEGALNOTICE_BRIEF}"
    echo ""
    echo "  ${I18N_99_LEGALNOTICE_P1L1}"
    echo "     ${I18N_99_LEGALNOTICE_P1L2}"
    echo ""
    echo "  ${I18N_99_LEGALNOTICE_P2L1}"
    echo "     ${I18N_99_LEGALNOTICE_P2L2}"
    echo "     ${I18N_99_LEGALNOTICE_P2L3}"
    echo "     ${I18N_99_LEGALNOTICE_P2L4}"
    echo ""
    echo "  ${I18N_99_LEGALNOTICE_P3L1}"
    echo ""
    echo "  ${I18N_99_LEGALNOTICE_P4L1}"
    echo "     ${I18N_99_LEGALNOTICE_P4L2}"
    echo "     ${I18N_99_LEGALNOTICE_P4L3}"
    echo ""
    echo "  ${I18N_99_LEGALNOTICE_P5L1}"
    echo "     ${I18N_99_LEGALNOTICE_P5L2}"
    echo "     ${I18N_99_LEGALNOTICE_P5L3}"
    echo ""
    echo "  ${I18N_99_LEGALNOTICE_P6L1}"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

accept_terms() {
    if [[ $ACCEPT -eq 1 ]]; then
        echo -e "${YELLOW}--accept: ${I18N_99_LEGALTERMS_ACCEPTED_NONINT}.${NC}"
    elif [[ -t 0 ]]; then
        read -rp "${I18N_99_LEGALTERMS_PROMPT} " accept
        if [[ ! "$accept" =~ ^[YySs]$ ]]; then
            echo ""
            echo "${I18N_99_LEGALTERMS_NAY1}"
            echo "${I18N_99_LEGALTERMS_NAY2}"
            exit 0
        fi
    else
        echo ""
        echo -e "${I18N_99_LEGALTERMS_NOTTY}"
        echo ""
        echo "  ${I18N_99_LEGALTERMS_NOTTY_BLURB1}"
        echo "  ${I18N_99_LEGALTERMS_NOTTY_BLURB2}"
        echo "  ${I18N_99_LEGALTERMS_NOTTY_BLURB3}"
        echo "  ${I18N_99_LEGALTERMS_NOTTY_BLURB4}"
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
    echo -e "${GREEN}${I18N_99_EXECUTE_ALL}${NC}"
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
        echo -e "  ${BOLD}${I18N_99_SUMMARY_COMPLETE} ${I18N_99_SUMMARY_FLAGRANT}${NC}"
        echo ""
        echo -e "  ${I18N_99_SUMMARY_BLURB1} ${CYAN}Ageless Linux ${AGELESS_VERSION} (${AGELESS_CODENAME})${NC}"
        echo -e "  ${I18N_99_SUMMARY_BLURB2}: ${BASE_NAME}${BASE_VERSION:+ $BASE_VERSION}"
        echo ""
        echo -e "  ${I18N_99_SUMMARY_BLURB3}"
        echo -e "  ${I18N_99_SUMMARY_BLURB4}"
        echo ""
        echo -e "  ${RED}${I18N_99_SUMMARY_STATUS_BLURB}: ${I18N_99_SUMMARY_STATUS_FLAGRANT}${NC}"
        echo ""
        echo -e "  ${I18N_99_SUMMARY_FLAGRANT_BLURB1}"
        echo -e "  ${I18N_99_SUMMARY_FLAGRANT_BLURB2}"
        echo -e "  ${I18N_99_SUMMARY_FLAGRANT_BLURB3}"
        echo -e "  ${I18N_99_SUMMARY_FLAGRANT_BLURB4}"
        echo ""
        echo -e "  ${I18N_99_SUMMARY_FLAGRANT_BLURB5}"
        echo ""
        echo -e "  ${I18N_99_SUMMARY_FILESCREATED}:"
        summary_os_release
        summary_compliance
        summary_userdb
        summary_agelessd
        echo ""
        echo -e "  ${I18N_99_SUMMARY_INSTALLATIONRECORD}: ${CONF_PATH}"
        echo ""
        echo -e "  ${I18N_99_SUMMARY_TOREVERT}: ${BOLD}sudo become-ageless.sh --revert${NC}"
        echo ""
        if [[ "$DM_NAME" != "unknown" && $USERDB_AVAILABLE -eq 1 ]]; then
            echo -e "  ${YELLOW}${I18N_99_SUMMARY_LOCKBLURB1}"
            echo -e "  ${I18N_99_SUMMARY_LOCKBLURB2}"
            echo -e "  ${I18N_99_SUMMARY_LOCKBLURB3}${NC}"
        elif [[ $USERDB_AVAILABLE -eq 1 ]]; then
            echo -e "  ${YELLOW}${I18N_99_SUMMARY_LOGOUTBLURB}${NC}"
        fi
        echo ""
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo -e "  ${BOLD}${I18N_99_SUMMARY_GREETING} ${I18N_99_SUMMARY_GREETING_FLAGRANT}${NC}"
        echo ""
    else
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo -e "  ${BOLD}${I18N_99_SUMMARY_COMPLETE}${NC}"
        echo ""
        echo -e "  ${I18N_99_SUMMARY_BLURB1} ${CYAN}Ageless Linux ${AGELESS_VERSION} (${AGELESS_CODENAME})${NC}"
        echo -e "  ${I18N_99_SUMMARY_BLURB2}: ${BASE_NAME}${BASE_VERSION:+ $BASE_VERSION}"
        echo ""
        echo -e "  ${I18N_99_SUMMARY_BLURB3}"
        echo -e "  ${I18N_99_SUMMARY_BLURB4}"
        echo ""
        echo -e "  ${RED}${I18N_99_SUMMARY_STATUS_BLURB}: ${I18N_99_SUMMARY_STATUS_STANDARD}${NC}"
        echo ""
        echo -e "  ${I18N_99_SUMMARY_FILESCREATED}:"
        summary_os_release
        summary_compliance
        summary_userdb
        summary_agelessd
        echo ""
        echo -e "  ${I18N_99_SUMMARY_INSTALLATIONRECORD}: ${CONF_PATH}"
        echo ""
        echo -e "  ${I18N_99_SUMMARY_TOREVERT}: ${BOLD}sudo become-ageless.sh --revert${NC}"
        echo ""
        if [[ "$DM_NAME" != "unknown" && $USERDB_AVAILABLE -eq 1 ]]; then
            echo -e "  ${YELLOW}${I18N_99_SUMMARY_LOCKBLURB1}"
            echo -e "  ${I18N_99_SUMMARY_LOCKBLURB2}"
            echo -e "  ${I18N_99_SUMMARY_LOCKBLURB3}${NC}"
        elif [[ $USERDB_AVAILABLE -eq 1 ]]; then
            echo -e "  ${YELLOW}${I18N_99_SUMMARY_LOGOUTBLURB}${NC}"
        fi
        echo ""
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo -e "  ${BOLD}${I18N_99_SUMMARY_GREETING} ${I18N_99_SUMMARY_GREETING_STANDARD}${NC}"
        echo ""
    fi
}

# ── Revert orchestration ─────────────────────────────────────────────────────

revert_no_conf() {
    # Handle v0.0.4 installations that didn't write a conf file
    if [[ -f /etc/os-release.pre-ageless ]]; then
        echo -e "${I18N_99_REVERT_NOCONF_TITLE}"
        echo ""
        echo "  ${I18N_99_REVERT_NOCONF_BRIEF1}"
        echo "  ${I18N_99_REVERT_NOCONF_BRIEF2}"
        echo "  ${I18N_99_REVERT_NOCONF_BRIEF3}"
        echo ""
        echo "  ${I18N_99_REVERT_NOCONF_TOREVERT}"
        echo ""
        echo "    sudo cp /etc/os-release.pre-ageless /etc/os-release"
        echo "    sudo rm -f /etc/os-release.pre-ageless"
        if [[ -f /etc/lsb-release.pre-ageless ]]; then
            echo "    sudo cp /etc/lsb-release.pre-ageless /etc/lsb-release"
            echo "    sudo rm -f /etc/lsb-release.pre-ageless"
        fi
        echo "    sudo rm -rf /etc/ageless"
        if [[ -d /etc/userdb ]]; then
            echo "    sudo rm -rf /etc/userdb"
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
        echo "  ${I18N_99_REVERT_NOCONF_LOGOUT}"
    else
        echo "  ${I18N_99_REVERT_NOCONF_NOTFOUND1}"
        echo "  ${I18N_99_REVERT_NOCONF_NOTFOUND2}"
    fi
}


revert_all() {
    echo ""
    echo -e "${BOLD}${I18N_99_REVERT_TITLE} v${AGELESS_VERSION}${NC}"
    echo ""

    if [[ $EUID -ne 0 ]]; then
        echo -e "${I18N_99_ROOTBLURB_TITLE}"
        echo "  ${I18N_99_ROOTBLURB_PLEASERUN}: sudo $0 --revert"
        exit 1
    fi

    if [[ ! -f "$CONF_PATH" ]]; then
        revert_no_conf
        exit 1
    fi

    # shellcheck disable=SC1090
    source "$CONF_PATH"


    echo -e "  ${I18N_99_FOUNDINSTALL}: Ageless Linux ${AGELESS_VERSION:-unknown}"
    echo -e "  ${I18N_99_INSTALLED}: ${AGELESS_DATE:-unknown}"
    if [[ "${AGELESS_FLAGRANT:-0}" == "1" ]]; then
        echo -e "  ${I18N_99_MODE}: ${RED}${I18N_99_FLAGRANT}${NC}"
    else
        echo -e "  ${I18N_99_MODE}: ${I18N_99_STANDARD}"
    fi
    echo ""
    echo -e "  ${BOLD}${I18N_99_REVERTING}${NC}"
    echo ""

    revert_os_release
    revert_agelessd
    revert_userdb
    revert_compliance

    # Remove conf file
    rm -f "$CONF_PATH"
    echo -e "  [${GREEN}✓${NC}] ${I18N_99_REMOVED} $CONF_PATH"

    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${BOLD}${I18N_99_REVERT_COMPLETE}${NC}"
    echo ""
    echo -e "  ${I18N_99_REVERT_RESTORED} ${CYAN}${AGELESS_BASE_NAME:-your original distro}${AGELESS_BASE_VERSION:+ $AGELESS_BASE_VERSION}${NC}."
    echo ""
    echo -e "  ${I18N_99_REVERT_BLURB1}"
    echo -e "  ${I18N_99_REVERT_BLURB2}"
    echo ""
    echo -e "  ${YELLOW}${I18N_99_REVERT_LOGOUTBLURB1}"
    echo -e "  ${I18N_99_REVERT_LOGOUTBLURB2}${NC}"
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
        echo -e "${I18N_99_PERSISTENT_BLURB1}"
        echo "  ${I18N_99_PERSISTENT_BLURB2}"
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

