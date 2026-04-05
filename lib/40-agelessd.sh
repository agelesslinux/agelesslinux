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
        echo -e "  ${RED}${I18N_40_SYSTEMD_NOT_AVAILABLE}${NC}"
        echo ""
        return
    fi

    plan_action "${I18N_40_INSTALL_AGELESSD}"
    plan_action "${I18N_40_INSTALL_AGELESSD_SERVICE}"
}

execute_agelessd() {
    if [[ $PERSISTENT -eq 0 ]]; then
        return
    fi

    echo ""
    echo -e "  ${BOLD}${I18N_INSTALLING_AGELESSD}${NC}"
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
# [EN-US]
# agelessd — Ageless Linux birthDate Neutralization Daemon
#
# Ensures systemd userdb birthDate fields (PR #40954) remain neutralized.
# Runs every 24 hours via systemd timer.
#
# NOTE: This daemon does NOT reload systemd-userdbd after writing records.
# Reloading mid-session can break display manager lock screens (SDDM, LightDM, etc).
# Changes take effect on next login or boot.
# ============================================================================
# [PT-BR]
# agelessd — Daemon de Neutralização de birthdate do Ageless Linux
#
# Garante que os campos de birthDate do userdb do systemd (PR #40954)
# permaneçam neutralizados. Roda a cada 24 horas via timer do systemd.
#
# NOTA: Este daemon NÃO recarrega o systemd-userdbd depois de escrever
# os registros. Recarregar durante uma sessão pode quebrar as telas de
# bloqueio do display manager (SDDM, LightDM, etc.).
# As mudanças são aplicadas no próximo login ou boot.
# ============================================================================
# SPDX-License-Identifier: Unlicense
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

    echo -e "  [${GREEN}✓${NC}] ${I18N_40_INSTALLED_AGELESSD}"
    echo -e "  [${GREEN}✓${NC}] ${I18N_40_INSTALLED_AGELESSD_SERVICE}"
    echo -e "  [${GREEN}✓${NC}] ${I18N_40_INSTALLED_AGELESSD_TIMER}"
}

revert_agelessd() {
    if [[ "${AGELESS_AGELESSD_INSTALLED:-0}" == "1" ]]; then
        systemctl disable --now agelessd.timer 2>/dev/null || true
        rm -f /etc/systemd/system/agelessd.service
        rm -f /etc/systemd/system/agelessd.timer
        systemctl daemon-reload 2>/dev/null || true
        echo -e "  [${GREEN}✓${NC}] ${I18N_40_REMOVED_AGELESSD_SERVICE}"
    fi
}

summary_agelessd() {
    if [[ $PERSISTENT -eq 0 ]]; then
        return
    fi

    echo ""
    echo -e "  ${I18N_40_SUMMARY_BLURB}:"
    echo -e "    /etc/ageless/agelessd .......... ${I18N_40_SUMMARY_FILEDESC1}"
    echo -e "    agelessd.service ............... ${I18N_40_SUMMARY_FILEDESC2}"
    echo -e "    agelessd.timer ................. ${I18N_40_SUMMARY_FILEDESC3}"
}
