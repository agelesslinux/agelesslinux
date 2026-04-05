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
        plan_action "${I18N_10_BACKUP_OSRELEASE}"
    fi
    plan_action "${I18N_10_REWRITE_OSRELEASE}"

    if [[ -f /etc/lsb-release ]]; then
        if [[ ! -f /etc/lsb-release.pre-ageless ]]; then
            plan_action "${I18N_10_BACKUP_LSBRELEASE}"
        fi
        plan_action "${I18N_10_REWRITE_LSBRELEASE}"
    fi
}

execute_os_release() {
    # Back up os-release
    local backup="/etc/os-release.pre-ageless"
    if [[ ! -f "$backup" ]]; then
        cp /etc/os-release "$backup"
        CONF_BACKED_UP_OS_RELEASE=1
        echo -e "  [${GREEN}✓${NC}] ${I18N_10_BACKEDUP_OSRELEASE} $backup"
    else
        CONF_BACKED_UP_OS_RELEASE=1
        echo -e "  [${YELLOW}~${NC}] ${I18N_10_BACKUPEXISTS_OSRELEASE} $backup ${I18N_10_BACKUPEXISTS2_OSRELEASE}"
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
VERSION_CODENAME=${AGELESS_CODENAME,,}
ID=ageless
ID_LIKE=${AGELESS_ID_LIKE}
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
echo -e "  [${GREEN}✓${NC}] ${I18N_10_WROTENEW_OSRELEASE}"

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
DISTRIB_RELEASE=${AGELESS_VERSION}
DISTRIB_CODENAME=${AGELESS_CODENAME,,}
DISTRIB_DESCRIPTION="Ageless Linux ${AGELESS_VERSION} (${AGELESS_CODENAME})"
EOF
        echo -e "  [${GREEN}✓${NC}] ${I18N_10_UPDATED_LSBRELEASE}"
    fi
}

revert_os_release() {
    if [[ "${AGELESS_BACKED_UP_OS_RELEASE:-0}" == "1" ]] && [[ -f /etc/os-release.pre-ageless ]]; then
        cp /etc/os-release.pre-ageless /etc/os-release
        rm -f /etc/os-release.pre-ageless
        echo -e "  [${GREEN}✓${NC}] ${I18N_10_RESTORED_OSRELEASE}"
    fi

    if [[ "${AGELESS_BACKED_UP_LSB_RELEASE:-0}" == "1" ]] && [[ -f /etc/lsb-release.pre-ageless ]]; then
        cp /etc/lsb-release.pre-ageless /etc/lsb-release
        rm -f /etc/lsb-release.pre-ageless
        echo -e "  [${GREEN}✓${NC}] ${I18N_10_RESTORED_LSBRELEASE}"
    fi
}

summary_os_release() {
    echo -e "    /etc/os-release ................ ${I18N_10_SUMMARY_OSRELEASE}"
    echo -e "    /etc/os-release.pre-ageless .... ${I18N_10_SUMMARY_OSRELEASE_PREAGELESS}"
}
