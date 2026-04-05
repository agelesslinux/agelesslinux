# §§ USERDB — systemd userdb birthDate neutralization
# ===========================================================================
# [EN-US]
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
# ===========================================================================
# [PT-BR]
#
#    O PR #40954 do systemd (merjado em 18/03/2026) adicionou um campo
#    birthDate nos registros JSON. Este campo fomenta dados de idade ao
#    xdg-desktop-portal para tornar possível restrições de idade a nível
#    de aplicativo. Nós neutralizamos isso para todos os usuários.
#
#    Insere registros substitutos no NSS fantasma /etc/userdb/, de forma que
#    cada registro inclua o set completo de campos do passwd
#    (uid, gid, home, shell) para evitar quebra do parseamento do usuário.
#
#    NOTA: Nós NÃO recarregamos o systemd-userdbd depois de criar os registros.
#    Criar ou recarregar os registros durante uma sessão de login faz os
#    display managers (SDDM, LightDM, e potencialmente outros) perderem a
#    habilidade de verificar senhas na tela de bloqueio. Os registros são
#    lidos automaticamente no próximo boot ou login.
# ===========================================================================

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
        echo -e "  ${YELLOW}${I18N_30_SKIPPED_USERDB}${NC}"
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
        plan_action "${I18N_30_CREATE_USERDB}"
    fi

    for username in "${USERDB_EXISTING[@]+"${USERDB_EXISTING[@]}"}"; do
        plan_action "${I18N_30_BACKUP} /etc/userdb/${username}.user -> ${username}.user.pre-ageless"
        plan_action "${I18N_30_UPDATE} /etc/userdb/${username}.user (birthDate = ${birthdate})"
    done

    for username in "${USERDB_NEW[@]+"${USERDB_NEW[@]}"}"; do
        plan_action "${I18N_30_CREATE} /etc/userdb/${username}.user (birthDate = ${birthdate})"
    done
}

execute_userdb() {
    echo ""
    echo -e "  ${BOLD}${I18N_30_USERDB_BLURB1}${NC}"
    echo ""
    echo "  ${I18N_30_USERDB_BLURB2}"
    echo "  ${I18N_30_USERDB_BLURB3}"
    echo "  ${I18N_30_USERDB_BLURB4}"
    echo ""

    if [[ $USERDB_AVAILABLE -eq 0 ]]; then
        echo -e "  [${YELLOW}~${NC}] ${I18N_30_USERDB_SKIPPED}"
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
                    echo -e "  [${YELLOW}!${NC}] ${username}: ${I18N_30_USERDB_EXISTING} ${userdb_file} ${I18N_30_USERDB_REQUIRE_PYTHON3}"
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
    echo -e "  ${userdb_count} ${I18N_30_USERDB_ENDBLURB1}"
    echo ""
    echo -e "  ${I18N_30_USERDB_ENDBLURB2}"
    echo -e "  ${I18N_30_USERDB_ENDBLURB3}"
    if [[ "$DM_NAME" != "unknown" ]]; then
        echo -e "  ${I18N_30_USERDB_LOCKBLURB}"
    fi
}

revert_userdb() {
    # Remove userdb records we created from scratch
    if [[ -n "${AGELESS_USERDB_CREATED:-}" ]]; then
        for username in $AGELESS_USERDB_CREATED; do
            if [[ -f "/etc/userdb/${username}.user" ]]; then
                rm -f "/etc/userdb/${username}.user"
                echo -e "  [${GREEN}✓${NC}] ${I18N_30_REMOVED} /etc/userdb/${username}.user"
            fi
        done
    fi

    # Restore userdb records we backed up before modifying
    if [[ -n "${AGELESS_USERDB_BACKED_UP:-}" ]]; then
        for username in $AGELESS_USERDB_BACKED_UP; do
            if [[ -f "/etc/userdb/${username}.user.pre-ageless" ]]; then
                mv "/etc/userdb/${username}.user.pre-ageless" "/etc/userdb/${username}.user"
                echo -e "  [${GREEN}✓${NC}] ${I18N_30_RESTORED} /etc/userdb/${username}.user ${I18N_30_FROMBACKUP}"
            fi
        done
    fi

    # Remove /etc/userdb/ if we created it and it's now empty
    if [[ "${AGELESS_USERDB_DIR_CREATED:-0}" == "1" ]] && [[ -d /etc/userdb ]]; then
        if [[ -z "$(ls -A /etc/userdb 2>/dev/null)" ]]; then
            rmdir /etc/userdb
            echo -e "  [${GREEN}✓${NC}] ${I18N_30_REMOVEDEMPTY} /etc/userdb/"
        else
            echo -e "  [${YELLOW}~${NC}] /etc/userdb/ ${I18N_30_NOTEMPTY}"
        fi
    fi

    # Restart userdbd to clear any cached records (safe during revert)
    if command -v systemctl &>/dev/null; then
        if systemctl list-unit-files systemd-userdbd.service &>/dev/null 2>&1; then
            systemctl try-reload-or-restart systemd-userdbd.service 2>/dev/null || true
            echo -e "  [${GREEN}✓${NC}] ${I18N_30_RELOADED} systemd-userdbd"
        fi
    fi
}

summary_userdb() {
    if [[ $USERDB_AVAILABLE -eq 0 ]]; then
        echo ""
        echo -e "  userdb birthDate: ${YELLOW}${I18N_30_SUMMARY_USERDB_SKIPPED}${NC}"
        return
    fi

    echo ""
    echo -e "  userdb birthDate (systemd PR #40954):"
    if [[ $FLAGRANT -eq 1 ]]; then
        echo -e "    /etc/userdb/*.user ..................... ${USERDB_COUNT:-0} ${I18N_30_SUMMARY_USERS} → ${RED}null${NC}"
    else
        echo -e "    /etc/userdb/*.user ............. ${USERDB_COUNT:-0} ${I18N_30_SUMMARY_USERS} → 1970-01-01"
    fi
}
