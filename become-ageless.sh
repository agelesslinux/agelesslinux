#!/bin/bash

# become-ageless.sh — Ageless Linux Distribution Conversion Tool
# Version 0.1.0
# Source & latest: https://github.com/agelesslinux/agelesslinux
# SPDX-License-Identifier: Unlicense
# ============================================================================
# [EN-US]
#
# This script converts your existing Linux installation into Ageless Linux,
# an operating system regulated by digital surveillance laws sanctioned from,
# by and for states, counties and countries like California and Brazil.
#
# By running this script, the person or entity who controls this device becomes:
#
# * An "operating system provider" as defined by California Civil Code
#   § 1798.500(g), part of the California Digital Age Assurance Act (AB 1043,
#   Chapter 675, Statues of 2025), because they now "control the operating
#   system software on a general purpose computing device"
# * Susceptible to the application of Brazilian Law nº 15.211/2025
#   (known as "Lei Felca"), in force since March 17th 2026, because their
#   operating system is now bound to item VII of Article 2nd of said law -
#   this includes any adjacent laws referenced by it, e.g. Statute of the
#   Child and Adolescent (L8069/1990), Civil Rights Framework for the Internet
#   (L12692/2014), and the General Data Protection Law (L13709/2018, aka "LGPD",
#   aka "Brazilian GDPR")
#
# Ageless Linux does not collect, store, transmit, or even think about
# the age of any user, in full and knowing noncompliance with all of the
# laws/acts/etc. stated above.
#
# ============================================================================
# [PT-BR]
#
# Este script converte sua instalação Linux existente no Ageless Linux,
# um sistema operacional regulado por leis de vigilância digital sancionadas
# de, por e para estados, condados e países como Califórnia e Brasil.
#
# Ao rodar este script, a pessoa ou entidade que controla este dispositivo
# se torna:
#
# * Um "provedor de sistema operacional", como definido pelo Código Civil
#   da Califórnia § 1798.500(g), parte da Lei de Garantia da Idade Digital
#   da Califórnia (AB 1043, Capítulo 675, Estatutos de 2025), porque ela agora
#   agora "controla o software do sistema operacional em um dispositivo de
#   computação de uso geral"
# * Suscetível à aplicação da Lei Braslieira nº 15.211/2025 (vulgo "Lei Felca"),
#   em vigor desde 17 de Março de 2026, porque seu sistema operacional agora
#   se enquadra no inciso VII do Art. 2º de tal lei - isto inclui quaisquer
#   outras leis adjacentes referenciadas pela mesma, tais como o Estatuto da
#   Criança e do Adolescente (L8069/1990), o Marco Civil da Internet
#   (L12692/2014), e a Lei Geral de Proteção de Dados (L13709/2018, vulgo
#   "LGPD", vulgo "GDPR Tupiniquim")
#
# Ageless Linux não coleta, armazena, transmite ou sequer pensa sobre
# a idade de qualquer usuário, em completa e proposital não-conformidade
# com todas as leis/atos/etc. descritos acima.
# ============================================================================


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

# §§ I18N — Translated echo strings used throughout the script

# ── Supported languages ─────────────────────────────────────────────────────
VALID_LANGS=("en-US", "pt-BR")

set_lang() {
  # ── English (en-US) ─────────────────────────────────────────────────────────
  if [ "$1" == "en-US" ]; then
    I18N_10_BACKUP_OSRELEASE="Back up /etc/os-release -> /etc/os-release.pre-ageless"
    I18N_10_REWRITE_OSRELEASE="Rewrite /etc/os-release as Ageless Linux ${AGELESS_VERSION}"
    I18N_10_BACKUP_LSBRELEASE="Back up /etc/lsb-release -> /etc/lsb-release.pre-ageless"
    I18N_10_REWRITE_LSBRELEASE="Rewrite /etc/lsb-release as Ageless Linux ${AGELESS_VERSION}"
    I18N_10_BACKEDUP_OSRELEASE="Backed up original /etc/os-release to"
    I18N_10_BACKUPEXISTS_OSRELEASE="Backup already exists at"
    I18N_10_BACKUPEXISTS2_OSRELEASE="(previous conversion?)"
    I18N_10_WROTENEW_OSRELEASE="Wrote new /etc/os-release"
    I18N_10_UPDATED_LSBRELEASE="Updated /etc/lsb-release"
    I18N_10_RESTORED_OSRELEASE="Restored /etc/os-release"
    I18N_10_RESTORED_LSBRELEASE="Restored /etc/lsb-release"
    I18N_10_SUMMARY_OSRELEASE="OS identity (modified)"
    I18N_10_SUMMARY_OSRELEASE_PREAGELESS="Original OS identity (backup)"

    I18N_20_CREATE_COMPLIANCE_FLAGRANT="Create /etc/ageless/ab1043-compliance.txt (flagrant)"
    I18N_20_CREATE_COMPLIANCE_FLAGRANT_PTBR="Create /etc/ageless/l15211-compliance.txt (flagrant)"
    I18N_20_CREATE_REFUSAL="Create /etc/ageless/REFUSAL (machine-readable refusal)"
    I18N_20_CREATE_REFUSAL_PTBR="Create /etc/ageless/REFUSAL-PTBR (machine-readable refusal)"
    I18N_20_CREATE_COMPLIANCE_STANDARD="Create /etc/ageless/ab1043-compliance.txt"
    I18N_20_CREATE_COMPLIANCE_STANDARD_PTBR="Create /etc/ageless/l15211-compliance.txt"
    I18N_20_CREATE_API_STUB="Create /etc/ageless/age-verification-api.sh (nonfunctional stub)"
    I18N_20_CREATED_COMPLIANCE="Created /etc/ageless/ab1043-compliance.txt"
    I18N_20_CREATED_COMPLIANCE_PTBR="Created /etc/ageless/l15211-compliance.txt"
    I18N_20_INSTALLED_REFUSAL="Installed REFUSAL notices (no API provided, by design)"
    I18N_20_SKIPPED_API_STUB="Age verification API deliberately not installed"
    I18N_20_INSTALLED_API_STUB="Installed age verification API (nonfunctional, as intended)"
    I18N_20_REMOVED_AGELESS="Removed /etc/ageless"
    I18N_20_SUMMARY_COMPLIANCE="Noncompliance statement"
    I18N_20_SUMMARY_REFUSAL="Machine-readable refusal"
    I18N_20_SUMMARY_FILES_NOTCREATED="Files deliberately NOT created"
    I18N_20_SUMMARY_REFUSED="REFUSED"

    I18N_30_SKIPPED_USERDB="Skipping userdb neutralization (systemd-userdbd not present)"
    I18N_30_CREATE_USERDB="Create /etc/userdb/ directory"
    I18N_30_BACKUP="Back up"
    I18N_30_UPDATE="Update"
    I18N_30_CREATE="Create"
    I18N_30_USERDB_BLURB1="Neutralizing systemd userdb birthDate field..."
    I18N_30_USERDB_BLURB2="systemd PR #40954 (merged 2026-03-18) added a birthDate field to"
    I18N_30_USERDB_BLURB3="JSON user records, intended to serve age verification data to"
    I18N_30_USERDB_BLURB4="applications via xdg-desktop-portal."
    I18N_30_USERDB_SKIPPED="systemd-userdbd not present — skipping userdb neutralization"
    I18N_30_USERDB_EXISTING="existing file"
    I18N_30_USERDB_REQUIRE_PYTHON3="requires python3 to merge safely, skipping"
    I18N_30_USERDB_ENDBLURB1="user(s) neutralized."
    I18N_30_USERDB_ENDBLURB2="${YELLOW}NOTE:${NC} systemd-userdbd has NOT been reloaded."
    I18N_30_USERDB_ENDBLURB3="Userdb changes will take effect after your next login or reboot."
    I18N_30_USERDB_LOCKBLURB="${YELLOW}WARNING:${NC} Do NOT lock your screen before logging out/rebooting."
    I18N_30_REMOVED="Removed"
    I18N_30_RESTORED="Restored"
    I18N_30_FROMBACKUP="from backup"
    I18N_30_REMOVEDEMPTY="Removed empty directory"
    I18N_30_NOTEMPTY="not empty, leaving in place"
    I18N_30_RELOADED="Reloaded"
    I18N_30_SUMMARY_USERDB_SKIPPED="skipped (systemd-userdbd not present)"
    I18N_30_SUMMARY_USERS="user(s)"

    I18N_40_SYSTEMD_NOT_AVAILABLE="ERROR: --persistent requires systemd (not available on this system)"
    I18N_40_INSTALL_AGELESSD="Install /etc/ageless/agelessd (neutralization script)"
    I18N_40_INSTALL_AGELESSD_SERVICE="Install agelessd.service and agelessd.timer (24h enforcement)"
    I18N_40_INSTALLING_AGELESSD="Installing agelessd persistent daemon..."
    I18N_40_INSTALLED_AGELESSD="Installed /etc/ageless/agelessd"
    I18N_40_INSTALLED_AGELESSD_SERVICE="Installed agelessd.service"
    I18N_40_INSTALLED_AGELESSD_TIMER="Installed and started agelessd.timer (24h interval)"
    I18N_40_REMOVED_AGELESSD_SERVICE="Removed agelessd service and timer"
    I18N_40_SUMMARY_BLURB="Persistent daemon (agelessd)"
    I18N_40_SUMMARY_FILEDESC1="Neutralization script"
    I18N_40_SUMMARY_FILEDESC2="systemd oneshot service"
    I18N_40_SUMMARY_FILEDESC3="24-hour enforcement cycle"

    I18N_50_WRITE="Write"
    I18N_50_INSTALLATION_RECORD="(installation record)"
    I18N_50_WROTE="Wrote"

    I18N_99_ARGBLURB_LANG="Set the script's language (defaults to en-US)"
    I18N_99_ARGBLURB_WRONGLANG="${RED}ERROR:${NC} Unknown language. Valid languages are:"
    I18N_99_ARGBLURB_UNKNOWN="${RED}ERROR:${NC} Unknown argument"
    I18N_99_ARGBLURB_USAGE="Usage"
    I18N_99_ARGBLURB_FLAGRANT="Remove all compliance fig leaves"
    I18N_99_ARGBLURB_ACCEPT="Accept the legal terms non-interactively"
    I18N_99_ARGBLURB_PERSISTENT="Install agelessd daemon (24h birthDate enforcement)"
    I18N_99_ARGBLURB_DRYRUN="Analyze system and show planned actions without modifying"
    I18N_99_ARGBLURB_REVERT="Undo a previous Ageless Linux conversion"
    I18N_99_ARGBLURB_VERSION="Show version and exit"
    I18N_99_MOTTO="Software for humans of indeterminate age"
    I18N_99_TITLE="Ageless Linux Distribution Conversion Tool"
    I18N_99_CODENAME="Codename"
    I18N_99_MODE_FLAGRANT_TITLE="FLAGRANT MODE ENABLED"
    I18N_99_MODE_FLAGRANT_P1L1="In standard mode, Ageless Linux ships a stub age verification"
    I18N_99_MODE_FLAGRANT_P1L2="API that returns no data. This preserves the fig leaf of a"
    I18N_99_MODE_FLAGRANT_P1L3="'good faith effort' under § 1798.502(b)."
    I18N_99_MODE_FLAGRANT_P2L1="Flagrant mode removes the fig leaf."
    I18N_99_MODE_FLAGRANT_P3L1="No API will be installed. No interface of any kind will exist"
    I18N_99_MODE_FLAGRANT_P3L2="for age collection. No mechanism will be provided by which"
    I18N_99_MODE_FLAGRANT_P3L3="any developer could request or receive an age bracket signal."
    I18N_99_MODE_FLAGRANT_P3L4="The system will actively declare, in machine-readable form,"
    I18N_99_MODE_FLAGRANT_P3L5="that it refuses to comply."
    I18N_99_MODE_FLAGRANT_P4L1="This mode is intended for devices that will be"
    I18N_99_MODE_FLAGRANT_P4L2="physically handed to children."
    I18N_99_MODE_PERSISTENT_TITLE="PERSISTENT MODE ENABLED"
    I18N_99_MODE_PERSISTENT_P1L1="In addition to the one-time conversion, agelessd will be installed."
    I18N_99_MODE_PERSISTENT_P1L2="agelessd is a daemon, systemd service and timer that runs every 24 hours"
    I18N_99_MODE_PERSISTENT_P1L3="to ensure that systemd userdb birthDate fields remain neutralized."
    I18N_99_MODE_PERSISTENT_P2L1="This guards against package updates, user creation and/or desktop tools"
    I18N_99_MODE_PERSISTENT_P2L2="that may attempt to populate age data in the future."
    I18N_99_MODE_DRYRUN_TITLE="DRY RUN MODE"
    I18N_99_MODE_DRYRUN_P1L1="No changes will be made. This run will analyze your system"
    I18N_99_MODE_DRYRUN_P1L2="and show exactly what would happen during a real conversion."
    I18N_99_ROOTBLURB_TITLE="${RED}ERROR:${NC} This script must be run as root."
    I18N_99_ROOTBLURB_="California Civil Code § 1798.500(g) defines an operating system"
    I18N_99_ROOTBLURB_="provider as a person who 'controls the operating system software'."
    I18N_99_ROOTBLURB_="You cannot control the operating system software without root access."
    I18N_99_ROOTBLURB_PLEASERUN="Please run"
    I18N_99_SYSTEMANALYSIS="SYSTEM ANALYSIS"
    I18N_99_BASESYSTEM="Base system"
    I18N_99_DISPLAYMANAGER="Display manager"
    I18N_99_SEEWARNINGBELOW="see warning below"
    I18N_99_NOTDETECTED="not detected"
    I18N_99_NOTAVAILABLE="not available"
    I18N_99_INSTALLED="installed"
    I18N_99_ACTIVE="active"
    I18N_99_INACTIVE="inactive"
    I18N_99_NOTINSTALLED="not installed"
    I18N_99_EXISTS="exists"
    I18N_99_RECORDS="record(s)"
    I18N_99_DOESNOTEXIST="does not exist"
    I18N_99_HUMANUSERS="Human users"
    I18N_99_EXISTING_USERDB_RECORDS="Existing userdb records"
    I18N_99_BIRTHDATE_FIELD_DETECTED="birthDate field detected"
    I18N_99_NONE="none"
    I18N_99_PREVIOUS_AGELESS1="Previous Ageless Linux installation detected."
    I18N_99_PREVIOUS_AGELESS2="Run ${BOLD}sudo $0 --revert${NC} first, or this will overwrite it."
    I18N_99_DM_DETECTED="WARNING: display manager detected"
    I18N_99_DM_P1L1="Creating userdb drop-in records mid-session can interfere"
    I18N_99_DM_P1L2="with lock screen password verification (confirmed on SDDM"
    I18N_99_DM_P1L3="and LightDM). To avoid this:"
    I18N_99_DM_P2L1="1. After conversion, do NOT lock your screen."
    I18N_99_DM_P2L2="2. Instead, fully logout and log back in (or reboot)."
    I18N_99_DM_P2L3="3. After a fresh login, screen locking will work normally."
    I18N_99_PLANNED_TITLE="PLANNED ACTIONS"
    I18N_99_PLANNED_BRIEF="The following changes will be made to this system:"
    I18N_99_PLANNED_USERDB1="NOTE: systemd-userdbd will NOT be reloaded during this session."
    I18N_99_PLANNED_USERDB2="Userdb changes take effect after your next login or reboot."
    I18N_99_PLANNED_REVERT="To revert all changes later:"
    I18N_99_DRYRUN_BLURB1="Dry run complete. No changes were made."
    I18N_99_DRYRUN_BLURB2="To perform the conversion, run without --dry-run:"
    I18N_99_LEGALNOTICE_TITLE="LEGAL NOTICE"
    I18N_99_LEGALNOTICE_BRIEF="By converting this system to Ageless Linux, you acknowledge that:"
    I18N_99_LEGALNOTICE_P1L1="1. You are becoming an operating system provider as defined by"
    I18N_99_LEGALNOTICE_P1L2="California Civil Code § 1798.500(g)."
    I18N_99_LEGALNOTICE_P2L1="2. As of January 1 2027, you are required by § 1798.501(a)(1)"
    I18N_99_LEGALNOTICE_P2L2="to 'provide an accessible interface at account setup that"
    I18N_99_LEGALNOTICE_P2L3="requires an account holder to indicate the birth date, age,"
    I18N_99_LEGALNOTICE_P2L4="or both, of the user of that device'."
    I18N_99_LEGALNOTICE_P3L1="3. Ageless Linux provides no such interface."
    I18N_99_LEGALNOTICE_P4L1="4. Ageless Linux provides no 'reasonably consistent real-time"
    I18N_99_LEGALNOTICE_P4L2="application programming interface' for age bracket signals"
    I18N_99_LEGALNOTICE_P4L3="as required by § 1798.501(a)(2)."
    I18N_99_LEGALNOTICE_P5L1="5. You may be subject to civil penalties of up to \$2,500 per"
    I18N_99_LEGALNOTICE_P5L2="affected child per negligent violation, or \$7,500 per"
    I18N_99_LEGALNOTICE_P5L3="affected child per intentional violation."
    I18N_99_LEGALNOTICE_P6L1="6. This is intentional."
    I18N_99_LEGALTERMS_ACCEPTED_NONINT="legal terms accepted non-interactively"
    I18N_99_LEGALTERMS_PROMPT="Do you accept these terms and wish to become an OS provider? [y/N]"
    I18N_99_LEGALTERMS_NAY1="Installation cancelled. You remain a mere user."
    I18N_99_LEGALTERMS_NAY2="The California Attorney General has no business with you today."
    I18N_99_LEGALTERMS_NOTTY="${RED}ERROR:${NC} No TTY available for interactive confirmation."
    I18N_99_LEGALTERMS_NOTTY_BLURB1="This script requires you to accept legal terms acknowledging that"
    I18N_99_LEGALTERMS_NOTTY_BLURB2="you are becoming an operating system provider under Cal. Civ. Code"
    I18N_99_LEGALTERMS_NOTTY_BLURB3="§ 1798.500(g). In a non-interactive environment (e.g. piped from"
    I18N_99_LEGALTERMS_NOTTY_BLURB4="curl), pass --accept to confirm:"
    I18N_99_EXECUTE_ALL="Converting system to Ageless Linux..."
    I18N_99_SUMMARY_COMPLETE="Conversion complete."
    I18N_99_SUMMARY_FLAGRANT="FLAGRANT MODE."
    I18N_99_SUMMARY_BLURB1="You are now running"
    I18N_99_SUMMARY_BLURB2="Based on"
    I18N_99_SUMMARY_BLURB3="You are now an ${BOLD}operating system provider${NC} as defined by"
    I18N_99_SUMMARY_BLURB4="California Civil Code § 1798.500(g)."
    I18N_99_SUMMARY_STATUS_BLURB="Compliance status"
    I18N_99_SUMMARY_STATUS_FLAGRANT="FLAGRANTLY NONCOMPLIANT"
    I18N_99_SUMMARY_STATUS_STANDARD="INTENTIONALLY NONCOMPLIANT"
    I18N_99_SUMMARY_FLAGRANT_BLURB1="No age verification API has been installed."
    I18N_99_SUMMARY_FLAGRANT_BLURB2="No age collection interface has been created."
    I18N_99_SUMMARY_FLAGRANT_BLURB3="No mechanism exists for any developer to request"
    I18N_99_SUMMARY_FLAGRANT_BLURB4="or receive an age bracket signal from this device."
    I18N_99_SUMMARY_FLAGRANT_BLURB5="This system is ready to be handed to a child."
    I18N_99_SUMMARY_FILESCREATED="Files created"
    I18N_99_SUMMARY_INSTALLATIONRECORD="Installation record"
    I18N_99_SUMMARY_TOREVERT="To revert"
    I18N_99_SUMMARY_LOCKBLURB1="IMPORTANT: Do NOT lock your screen."
    I18N_99_SUMMARY_LOCKBLURB2="Log out and back in (or reboot) first."
    I18N_99_SUMMARY_LOCKBLURB3="Your lock screen may reject your password until you do."
    I18N_99_SUMMARY_LOGOUTBLURB="Log out and back in (or reboot) for userdb changes to take effect."
    I18N_99_SUMMARY_GREETING="Welcome to Ageless Linux."
    I18N_99_SUMMARY_GREETING_FLAGRANT="We refused to ask how old you are."
    I18N_99_SUMMARY_GREETING_STANDARD="You have no idea how old we are."
    I18N_99_REVERT_NOCONF_TITLE="${YELLOW}WARNING:${NC} No /etc/agelesslinux.conf found."
    I18N_99_REVERT_NOCONF_BRIEF1="It appears this system was converted by an older version of"
    I18N_99_REVERT_NOCONF_BRIEF2="become-ageless.sh (v0.0.4 or earlier) that did not write a"
    I18N_99_REVERT_NOCONF_BRIEF3="configuration file. Automatic revert is not possible."
    I18N_99_REVERT_NOCONF_TOREVERT="To manually revert, run:"
    I18N_99_REVERT_NOCONF_LOGOUT="Then fully log out and log back in (or reboot)."
    I18N_99_REVERT_NOCONF_NOTFOUND1="No Ageless Linux installation found on this system."
    I18N_99_REVERT_NOCONF_NOTFOUND2="(No /etc/agelesslinux.conf and no /etc/os-release.pre-ageless)"
    I18N_99_REVERT_TITLE="Ageless Linux Revert Tool"
    I18N_99_FOUNDINSTALL="Found installation record"
    I18N_99_INSTALLED="Installed"
    I18N_99_MODE="Mode"
    I18N_99_FLAGRANT="flagrant"
    I18N_99_STANDARD="standard"
    I18N_99_REVERTING="Reverting Ageless Linux conversion..."
    I18N_99_REMOVED="Removed"
    I18N_99_REVERT_COMPLETE="Revert complete."
    I18N_99_REVERT_RESTORED="Your system has been restored to"
    I18N_99_REVERT_BLURB1="You are no longer an operating system provider."
    I18N_99_REVERT_BLURB2="The California Attorney General has no business with you today."
    I18N_99_REVERT_LOGOUTBLURB1="Please fully log out and log back in (or reboot)"
    I18N_99_REVERT_LOGOUTBLURB2="for all changes to take effect."
    I18N_99_PERSISTENT_BLURB1="${RED}ERROR:${NC} --persistent requires systemd, which is not available on this system."
    I18N_99_PERSISTENT_BLURB2="Remove --persistent to proceed without the agelessd daemon."

  # ── Brazilian Portuguese (pt-BR) ──────────────────────────────────────────
  elif [ "$1" == "pt-BR" ]; then
    I18N_10_BACKUP_OSRELEASE="Copiar /etc/os-release -> /etc/os-release.pre-ageless"
    I18N_10_REWRITE_OSRELEASE="Reescrever /etc/os-release como Ageless Linux ${AGELESS_VERSION}"
    I18N_10_BACKUP_LSBRELEASE="Copiar /etc/lsb-release -> /etc/lsb-release.pre-ageless"
    I18N_10_REWRITE_LSBRELEASE="Reescrever /etc/lsb-release como Ageless Linux ${AGELESS_VERSION}"
    I18N_10_BACKEDUP_OSRELEASE="Copiado o /etc/os-release original para"
    I18N_10_BACKUPEXISTS_OSRELEASE="Backup já existe em"
    I18N_10_BACKUPEXISTS2_OSRELEASE="(conversão anterior?)"
    I18N_10_WROTENEW_OSRELEASE="Escrito novo /etc/os-release"
    I18N_10_UPDATED_LSBRELEASE="Atualizado /etc/lsb-release"
    I18N_10_RESTORED_OSRELEASE="Restaurado /etc/os-release"
    I18N_10_RESTORED_LSBRELEASE="Restaurado /etc/lsb-release"
    I18N_10_SUMMARY_OSRELEASE="Identidade do sistema (modificado)"
    I18N_10_SUMMARY_OSRELEASE_PREAGELESS="Identidade original do sistema (backup)"

    I18N_20_CREATE_COMPLIANCE_FLAGRANT="Criar /etc/ageless/ab1043-compliance.txt (flagrante)"
    I18N_20_CREATE_COMPLIANCE_FLAGRANT_PTBR="Criar /etc/ageless/l15211-compliance.txt (flagrante)"
    I18N_20_CREATE_REFUSAL="Criar /etc/ageless/REFUSAL (recusa legível por máquina)"
    I18N_20_CREATE_REFUSAL_PTBR="Criar /etc/ageless/REFUSAL-PTBR (recusa legível por máquina)"
    I18N_20_CREATE_COMPLIANCE_STANDARD="Criar /etc/ageless/ab1043-compliance.txt"
    I18N_20_CREATE_COMPLIANCE_STANDARD_PTBR="Criar /etc/ageless/l15211-compliance.txt"
    I18N_20_CREATE_API_STUB="Criar /etc/ageless/age-verification-api.sh (stub não-funcional)"
    I18N_20_CREATED_COMPLIANCE="Criado /etc/ageless/ab1043-compliance.txt"
    I18N_20_CREATED_COMPLIANCE_PTBR="Criado /etc/ageless/l15211-compliance.txt"
    I18N_20_INSTALLED_REFUSAL="Instalados os avisos de RECUSA (nenhuma API providenciada, por design)"
    I18N_20_SKIPPED_API_STUB="API de verificação de idade deliberadamente não instalada"
    I18N_20_INSTALLED_API_STUB="API de verificação de idade instalada (não-funcional, como deveria ser)"
    I18N_20_REMOVED_AGELESS="Removido /etc/ageless"
    I18N_20_SUMMARY_COMPLIANCE="Declaração de não-conformidade"
    I18N_20_SUMMARY_REFUSAL="Recusa legível por máquina"
    I18N_20_SUMMARY_FILES_NOTCREATED="Arquivos deliberatamente NÃO criados"
    I18N_20_SUMMARY_REFUSED="RECUSA"

    I18N_30_SKIPPED_USERDB="Pulando neutralização do userdb (systemd-userdbd não existe)"
    I18N_30_CREATE_USERDB="Criar diretório /etc/userdb/"
    I18N_30_BACKUP="Copiar"
    I18N_30_UPDATE="Atualizar"
    I18N_30_CREATE="Criar"
    I18N_30_USERDB_BLURB1="Neutralizando campo birthDate do userdb do systemd..."
    I18N_30_USERDB_BLURB2="O PR #40954 do systemd (merjado em 18/03/2026) adicionou um campo birthDate"
    I18N_30_USERDB_BLURB3="nos registros JSON do usuário, com a intenção de servir dados de verificação"
    I18N_30_USERDB_BLURB4="de idade para aplicativos via xdg-desktop-portal."
    I18N_30_USERDB_SKIPPED="systemd-userdbd não existe — pulando neutralização do userdb"
    I18N_30_USERDB_EXISTING="arquivo existente"
    I18N_30_USERDB_REQUIRE_PYTHON3="requer python3 para merjar de forma segura, pulando"
    I18N_30_USERDB_ENDBLURB1="usuário(s) neutralizado(s)."
    I18N_30_USERDB_ENDBLURB2="${YELLOW}NOTA:${NC} systemd-userdbd NÃO foi recarregado."
    I18N_30_USERDB_ENDBLURB3="Mudanças no userdb tomam efeito depois do próximo login ou reboot."
    I18N_30_USERDB_LOCKBLURB="${YELLOW}AVISO:${NC} NÃO bloqueie sua tela antes de deslogar/rebootar."
    I18N_30_REMOVED="Removido"
    I18N_30_RESTORED="Restaurado"
    I18N_30_FROMBACKUP="do backup"
    I18N_30_REMOVEDEMPTY="Removido diretório vazio"
    I18N_30_NOTEMPTY="não está vazio, deixando quieto"
    I18N_30_RELOADED="Recarregado"
    I18N_30_SUMMARY_USERDB_SKIPPED="pulado (systemd-userdbd não existe)"
    I18N_30_SUMMARY_USERS="usuário(s)"

    I18N_40_SYSTEMD_NOT_AVAILABLE="ERRO: --persistent requer systemd (não disponível neste sistema)"
    I18N_40_INSTALL_AGELESSD="Instalar /etc/ageless/agelessd (script de neutralização)"
    I18N_40_INSTALL_AGELESSD_SERVICE="Instalar agelessd.service e agelessd.timer (ativa a cada 24h)"
    I18N_40_INSTALLING_AGELESSD="Instalando daemon persistente agelessd..."
    I18N_40_INSTALLED_AGELESSD="Instalado /etc/ageless/agelessd"
    I18N_40_INSTALLED_AGELESSD_SERVICE="Instalado agelessd.service"
    I18N_40_INSTALLED_AGELESSD_TIMER="Instalado agelessd.timer e iniciado (intervalo de 24h)"
    I18N_40_REMOVED_AGELESSD_SERVICE="Removido serviço e timer do agelessd"
    I18N_40_SUMMARY_BLURB="Daemon persistente (agelessd)"
    I18N_40_SUMMARY_FILEDESC1="Script de neutralização"
    I18N_40_SUMMARY_FILEDESC2="Serviço oneshot do systemd"
    I18N_40_SUMMARY_FILEDESC3="Ciclo de ativação de 24 horas"

    I18N_50_WRITE="Escrever"
    I18N_50_INSTALLATION_RECORD="(registro de instalação)"
    I18N_50_WROTE="Escrito"

    I18N_99_ARGBLURB_LANG="Setar a língua do script (en-US por padrão)"
    I18N_99_ARGBLURB_WRONGLANG="${RED}ERRO:${NC} Língua desconhecida. Línguas válidas são:"
    I18N_99_ARGBLURB_UNKNOWN="${RED}ERRO:${NC} parâmetro desconhecido"
    I18N_99_ARGBLURB_USAGE="Uso"
    I18N_99_ARGBLURB_FLAGRANT="Remover todas as tarjas pretas de conformidade"
    I18N_99_ARGBLURB_ACCEPT="Aceitar os termos legais automaticamente (não-interativo)"
    I18N_99_ARGBLURB_PERSISTENT="Instalar o daemon agelessd (limpa o birthDate a cada 24h)"
    I18N_99_ARGBLURB_DRYRUN="Analisar o sistema e mostrar as mudanças planejadas sem alterar nada"
    I18N_99_ARGBLURB_REVERT="Reverter uma conversão anterior do Ageless Linux"
    I18N_99_ARGBLURB_VERSION="Mostrar versão e sair"
    I18N_99_MOTTO="Software para humanos de idade indeterminada"
    I18N_99_TITLE="Ferramenta de Conversão de Distribuição Ageless Linux"
    I18N_99_CODENAME="Codinome"
    I18N_99_MODE_FLAGRANT_TITLE="MODO FLAGRANTE ATIVADO"
    I18N_99_MODE_FLAGRANT_P1L1="No modo padrão, Ageless Linux instala uma API \"stub\" de verificação"
    I18N_99_MODE_FLAGRANT_P1L2="de idade que não retorna nada. Isso preserva a tarja preta proverbial"
    I18N_99_MODE_FLAGRANT_P1L3="do 'benefício da dúvida' sob a interpretação da Lei Brasileira."
    I18N_99_MODE_FLAGRANT_P2L1="O modo flagrante arranca essa tarja."
    I18N_99_MODE_FLAGRANT_P3L1="Nenhuma API é instalada. Nenhuma interface de qualquer tipo existe"
    I18N_99_MODE_FLAGRANT_P3L2="para coletar idade. Nenhum mecanismo é providenciado pelo qual qualquer"
    I18N_99_MODE_FLAGRANT_P3L3="desenvolvedor possa pedir ou receber um sinal de faixa etária."
    I18N_99_MODE_FLAGRANT_P3L4="O sistema vai declarar ativamente, de forma legível por uma máquina,"
    I18N_99_MODE_FLAGRANT_P3L5="que ele se recusa a cumprir a lei."
    I18N_99_MODE_FLAGRANT_P4L1="Este modo é feito para dispositivos que serão entregues"
    I18N_99_MODE_FLAGRANT_P4L2="fisicamente para uma criança."
    I18N_99_MODE_PERSISTENT_TITLE="MODO PERSISTENTE ATIVADO"
    I18N_99_MODE_PERSISTENT_P1L1="Além da conversão, também será instalado no sistema o agelessd."
    I18N_99_MODE_PERSISTENT_P1L2="agelessd é um daemon, serviço do systemd e timer que roda a cada 24 horas"
    I18N_99_MODE_PERSISTENT_P1L3="para garantir que o campo birthDate do userdb do systemd permaneça neutralizado."
    I18N_99_MODE_PERSISTENT_P2L1="Isso protege contra atualizações de pacotes, criação de usuários e/ou ferramentas"
    I18N_99_MODE_PERSISTENT_P2L2="de desktop que tentarem popular esse campo com alguma idade no futuro."
    I18N_99_MODE_DRYRUN_TITLE="MODO DE ENSAIO"
    I18N_99_MODE_DRYRUN_P1L1="Nenhuma mudança será feita. Este modo vai analisar seu sistema e"
    I18N_99_MODE_DRYRUN_P1L2="mostrar o que exatamente acontecerá durante uma conversão real."
    I18N_99_ROOTBLURB_TITLE="${RED}ERRO:${NC} Esse script deve rodar como root."
    I18N_99_ROOTBLURB_="O inciso VII da Lei 15.211/2025 diz que um sistema operacional"
    I18N_99_ROOTBLURB_="'controla as funções básicas de um hardware ou software'."
    I18N_99_ROOTBLURB_="Acesso ao superusuário (\"root\") é uma função básica de um sistema UNIX."
    I18N_99_ROOTBLURB_PLEASERUN="Por favor rode"
    I18N_99_SYSTEMANALYSIS="ANÁLISE DO SISTEMA"
    I18N_99_BASESYSTEM="Sistema base"
    I18N_99_DISPLAYMANAGER="Display manager"
    I18N_99_SEEWARNINGBELOW="veja o aviso abaixo"
    I18N_99_NOTDETECTED="não detectado"
    I18N_99_NOTAVAILABLE="não disponível"
    I18N_99_INSTALLED="instalado"
    I18N_99_ACTIVE="ativo"
    I18N_99_INACTIVE="inativo"
    I18N_99_NOTINSTALLED="não instalado"
    I18N_99_EXISTS="existe"
    I18N_99_RECORDS="registro(s)"
    I18N_99_DOESNOTEXIST="não existe"
    I18N_99_HUMANUSERS="Usuários humanos"
    I18N_99_EXISTING_USERDB_RECORDS="Registros existentes do userdb"
    I18N_99_BIRTHDATE_FIELD_DETECTED="Campo birthDate detectado"
    I18N_99_NONE="nenhum"
    I18N_99_PREVIOUS_AGELESS1="Instalação anterior do Ageless Linux detectada."
    I18N_99_PREVIOUS_AGELESS2="Rode ${BOLD}sudo $0 --revert${NC} primeiro, ou os dados serão sobrescritos."
    I18N_99_DM_DETECTED="AVISO: display manager detectado"
    I18N_99_DM_P1L1="Criar um registro no userdb durante uma sessão pode interferir"
    I18N_99_DM_P1L2="na verificação de senha da tela de bloqueio (confirmado no SDDM"
    I18N_99_DM_P1L3="e LightDM). Para evitar isto:"
    I18N_99_DM_P2L1="1. Após a conversão, NÃO bloqueie sua tela."
    I18N_99_DM_P2L2="2. Ao invés disso, faça logout e login de novo (ou reinicie)."
    I18N_99_DM_P2L3="3. Depois de um login novo, a tela de bloqueio deve voltar a funcionar."
    I18N_99_PLANNED_TITLE="MUDANÇAS PLANEJADAS"
    I18N_99_PLANNED_BRIEF="As seguintes mudanças serão feitas nesse sistema:"
    I18N_99_PLANNED_USERDB1="NOTA: systemd-userdbd NÃO vai ser recarregado durante esta sessão."
    I18N_99_PLANNED_USERDB2="Mudanças no userdb são efetivas depois do próximo login ou reboot."
    I18N_99_PLANNED_REVERT="Para reverter todas as mudanças:"
    I18N_99_DRYRUN_BLURB1="Ensaio completo. Nenhuma mudança foi feita."
    I18N_99_DRYRUN_BLURB2="Para fazer a conversão, rode sem --dry-run:"
    I18N_99_LEGALNOTICE_TITLE="AVISO JURÍDICO"
    I18N_99_LEGALNOTICE_BRIEF="Ao converter este sistema para o Ageless Linux, você aceita que:"
    I18N_99_LEGALNOTICE_P1L1="1. Seu sistema se enquadra no inciso VII do Art. 2 da Lei Brasileira"
    I18N_99_LEGALNOTICE_P1L2="15.211/2025 (vulgo \"Lei Felca\")."
    I18N_99_LEGALNOTICE_P2L1="2. A partir de 17 de Março de 2026, você é obrigado pelo Art. 9 §1º"
    I18N_99_LEGALNOTICE_P2L2="a 'adotar mecanismos confiáveis de verificação de idade a cada acesso"
    I18N_99_LEGALNOTICE_P2L3="do usuário ao conteúdo, produto ou serviço de que trata o caput"
    I18N_99_LEGALNOTICE_P2L4="desse artigo, vedada a autodeclaração'."
    I18N_99_LEGALNOTICE_P3L1="3. Ageless Linux não providencia nenhum mecanismo desse tipo."
    I18N_99_LEGALNOTICE_P4L1="4. Ageless Linux não providencia nenhuma 'API segura e pautada pela"
    I18N_99_LEGALNOTICE_P4L2="proteção da privacidade desde o padrão' e 'o fornecimento de sinal de idade"
    I18N_99_LEGALNOTICE_P4L3="aos provedores de aplicações de internet' como diz no inciso III do Art. 12."
    I18N_99_LEGALNOTICE_P5L1="5. Você está sujeito a uma multa de até R\$1.000,00 por usuário cadastrado"
    I18N_99_LEGALNOTICE_P5L2="pelo provedor sancionado, limitado no total a R\$50.000.000,00 por infração,"
    I18N_99_LEGALNOTICE_P5L3="como consta no inciso II do Art. 35."
    I18N_99_LEGALNOTICE_P6L1="6. Isto é proposital."
    I18N_99_LEGALTERMS_ACCEPTED_NONINT="termos legais aceitos automaticamente (não-interativo)"
    I18N_99_LEGALTERMS_PROMPT="Você aceita esses termos e deseja sorrir na cara do perigo? [s/N]"
    I18N_99_LEGALTERMS_NAY1="Instalação cancelada. Você continua sendo uma criança sob os olhos da lei."
    I18N_99_LEGALTERMS_NAY2="A Agência Nacional de Proteção de Dados lhe faz um cafuné (e o Felquinha aperta sua buchecha)."
    I18N_99_LEGALTERMS_NOTTY="${RED}ERRO:${NC} Nenhum TTY disponível para confirmação interativa."
    I18N_99_LEGALTERMS_NOTTY_BLURB1="Este script requer que você aceite os termos jurídicos e reconheça que"
    I18N_99_LEGALTERMS_NOTTY_BLURB2="seu sistema está se enquadrando no inciso VII do Art. 2 da Lei"
    I18N_99_LEGALTERMS_NOTTY_BLURB3="Brasileira 15.211/2025. Num ambiente não-interativo (ex: redirecionado"
    I18N_99_LEGALTERMS_NOTTY_BLURB4="via piping para o curl), use --accept para confirmar:"
    I18N_99_EXECUTE_ALL="Convertendo sistema para Ageless Linux..."
    I18N_99_SUMMARY_COMPLETE="Conversão completa."
    I18N_99_SUMMARY_FLAGRANT="MODO FLAGRANTE."
    I18N_99_SUMMARY_BLURB1="Você agora está rodando"
    I18N_99_SUMMARY_BLURB2="Baseado em"
    I18N_99_SUMMARY_BLURB3="Seu sistema agora se enquadra no ${BOLD}Art. 2º inciso VII${NC} da"
    I18N_99_SUMMARY_BLURB4="Lei Brasileira 15.211/2025 (vulgo \"Lei Felca\")."
    I18N_99_SUMMARY_STATUS_BLURB="Status de conformidade"
    I18N_99_SUMMARY_STATUS_FLAGRANT="FLAGRANTEMENTE NÃO-CONFORME"
    I18N_99_SUMMARY_STATUS_STANDARD="INTENCIONALMENTE NÃO-CONFORME"
    I18N_99_SUMMARY_FLAGRANT_BLURB1="Nenhuma API de verificação de idade foi instalada."
    I18N_99_SUMMARY_FLAGRANT_BLURB2="Nenhuma interface de coleta de dados de idade foi criada."
    I18N_99_SUMMARY_FLAGRANT_BLURB3="Não existe nenhum mecanismo pelo qual qualquer desenvolvedor possa"
    I18N_99_SUMMARY_FLAGRANT_BLURB4="requisitar ou receber sinais de faixa etária neste dispositivo."
    I18N_99_SUMMARY_FLAGRANT_BLURB5="Este sistema está pronto pra ser entregue a uma criança."
    I18N_99_SUMMARY_FILESCREATED="Arquivos criados"
    I18N_99_SUMMARY_INSTALLATIONRECORD="Registro de instalação"
    I18N_99_SUMMARY_TOREVERT="Para reverter"
    I18N_99_SUMMARY_LOCKBLURB1="IMPORTANTE: NÃO bloqueie sua tela."
    I18N_99_SUMMARY_LOCKBLURB2="Faça logout e login de novo (ou reinicie)."
    I18N_99_SUMMARY_LOCKBLURB3="Sua tela de bloqueio pode rejeitar sua senha até você fazer isso."
    I18N_99_SUMMARY_LOGOUTBLURB="Faça logout e login de novo (ou reinicie) para aplicar as mudanças do userdb."
    I18N_99_SUMMARY_GREETING="Bem vindo ao Ageless Linux."
    I18N_99_SUMMARY_GREETING_FLAGRANT="Nos recusamos a perguntar sua idade."
    I18N_99_SUMMARY_GREETING_STANDARD="Você não sabe a nossa idade."
    I18N_99_REVERT_NOCONF_TITLE="${YELLOW}AVISO:${NC} /etc/agelesslinux.conf não encontrado."
    I18N_99_REVERT_NOCONF_BRIEF1="Parece que esse sistema foi convertido por uma versão antiga do"
    I18N_99_REVERT_NOCONF_BRIEF2="become-ageless.sh (v0.0.4 ou anterior) que não possuia um"
    I18N_99_REVERT_NOCONF_BRIEF3="arquivo de configuração. Reversão automática não vai ser possível."
    I18N_99_REVERT_NOCONF_TOREVERT="Para reverter manualmente, rode:"
    I18N_99_REVERT_NOCONF_LOGOUT="Depois, faça logout e login de novo (ou reinicie)."
    I18N_99_REVERT_NOCONF_NOTFOUND1="Nenhuma instalção do Ageless Linux foi encontrada neste sistema."
    I18N_99_REVERT_NOCONF_NOTFOUND2="(Sem /etc/agelesslinux.conf e sem /etc/os-release.pre-ageless)"
    I18N_99_REVERT_TITLE="Ferramenta de reversão do Ageless Linux"
    I18N_99_FOUNDINSTALL="Registro de instalação encontrado"
    I18N_99_INSTALLED="Instalado"
    I18N_99_MODE="Modo"
    I18N_99_FLAGRANT="flagrante"
    I18N_99_STANDARD="padrão"
    I18N_99_REVERTING="Revertendo conversão do Ageless Linux..."
    I18N_99_REMOVED="Removido"
    I18N_99_REVERT_COMPLETE="Reversão concluída."
    I18N_99_REVERT_RESTORED="Seu sistema voltou a ser"
    I18N_99_REVERT_BLURB1="Seu sistema não é mais um 'sistema operacional' aos olhos da lei."
    I18N_99_REVERT_BLURB2="A Agência Nacional de Proteção de Dados não tá nem aí pra você."
    I18N_99_REVERT_LOGOUTBLURB1="Por favor faça logout e login de novo (ou reinicie)"
    I18N_99_REVERT_LOGOUTBLURB2="para aplicar todas as mudanças."
    I18N_99_PERSISTENT_BLURB1="${RED}ERRO:${NC} --persistent requer systemd, que não está disponível neste sistema."
    I18N_99_PERSISTENT_BLURB2="Remova a flag --persistent para proceder sem o daemon agelessd."
  fi
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

# §§ COMPLIANCE — /etc/ageless/ noncompliance documentation

plan_compliance() {
    if [[ $FLAGRANT -eq 1 ]]; then
        plan_action "${I18N_20_CREATE_COMPLIANCE_FLAGRANT}"
        plan_action "${I18N_20_CREATE_COMPLIANCE_FLAGRANT_PTBR}"
        plan_action "${I18N_20_CREATE_REFUSAL}"
        plan_action "${I18N_20_CREATE_REFUSAL_PTBR}"
    else
        plan_action "${I18N_20_CREATE_COMPLIANCE_STANDARD}"
        plan_action "${I18N_20_CREATE_COMPLIANCE_STANDARD_PTBR}"
        plan_action "${I18N_20_CREATE_API_STUB}"
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
cat > /etc/ageless/l15211-compliance.txt << 'BREOF'
══════════════════════════════════════════════════════════════════════════════════
  AGELESS LINUX — DECLARAÇÃO DE CONFORMIDADE DA LEI 15.211/2025 (MODO FLAGRANTE)
══════════════════════════════════════════════════════════════════════════════════

  Este sistema operacional é definido como tal pelo inciso VII do Art. 2º
  da Lei Brasileira nº 15.211/2025.

  Status de conformidade com a Lei Felca (L15211/2025):

  Art. 9 §1º         — Mecanismo de verificação de idade ...... RECUSA
  Art. 10            — Mecanismo de perfilamento .............. RECUSA
  Art. 12 Inciso I   — Mecanismo de aferição de idade ......... RECUSA
  Art. 12 Inciso III — API para sinais de faixa etária ........ RECUSA
  Art. 12 §1º        — Minimização de dados ................... RECUSA

  Nenhuma API de verificação de idade está instalada neste sistema.
  Não há nenhum dublê ("stub"), provisório ("placeholder"),
  esqueleto ("skeleton") ou interface de qualquer tipo para tal.
  Não existe nenhum mecanismo neste sistema pelo qual qualquer
  desenvolvedor de aplicações possa requisitar ou receber um sinal
  de faixa etária, agora ou no futuro.

  Isto não é uma limitação técnica. Isto é uma decisão política.

  Capacidades de relatório de faixa etária:
    Menor que 13 ... RECUSA A PERGUNTAR
    13 a 15 ........ RECUSA A PERGUNTAR
    16 a 17 ........ RECUSA A PERGUNTAR
    18 ou maior .... RECUSA A PERGUNTAR

  Este sistema foi configurado com a flag --flagrant, que indica que o
  operador pretende distribuí-lo para crianças e está ciente das
  potenciais penalidades cíveis descritas no Art. 35 da Lei 15.211/2025.

  O operador deste sistema convida a Agência Nacional de Proteção de Dados
  (ANPD) a aplicar a Lei 15.211/2025 contra este dispositivo.

  Para reverter esta conversão:
    sudo become-ageless.sh --revert

  Para reportar esta não-conformidade à Agência Nacional de Proteção de Dados:
    https://www.gov.br/anpd/pt-br/canais_atendimento/cidadao-titular-de-dados/denuncia-peticao-de-titular

══════════════════════════════════════════════════════════════════════════════════
BREOF
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
cat > /etc/ageless/l15211-compliance.txt << 'BREOF'
══════════════════════════════════════════════════════════════════════════════════
  AGELESS LINUX — DECLARAÇÃO DE CONFORMIDADE DA LEI 15.211/2025
══════════════════════════════════════════════════════════════════════════════════

  Este sistema operacional é definido como tal pelo inciso VII do Art. 2º
  da Lei Brasileira nº 15.211/2025.

  Status de conformidade com a Lei Felca (L15211/2025):

  Art. 9 §1º         — Mecanismo de verificação de idade ...... NÃO PROVIDENCIADO
  Art. 10            — Mecanismo de perfilamento .............. NÃO PROVIDENCIADO
  Art. 12 Inciso I   — Mecanismo de aferição de idade ......... NÃO PROVIDENCIADO
  Art. 12 Inciso III — API para sinais de faixa etária ........ NÃO PROVIDENCIADO
  Art. 12 §1º        — Minimização de dados ................... N/A (NENHUM DADO
                                                                É COLETADO)
  Capacidades de relatório de faixa etária:
    Menor que 13 ... DESCONHECIDO
    13 a 15 ........ DESCONHECIDO
    16 a 17 ........ DESCONHECIDO
    18 ou maior .... DESCONHECIDO
    Atemporal ...... ASSUMIDO

  Este sistema intencionalmente não determina, armazena, ou transmite qualquer
  informação referente à idade de qualquer usuário. Todos os usuários do
  Ageless Linux são, como o nome sugere, "sem idade".

  Para reverter esta conversão:
    sudo become-ageless.sh --revert

  Para reportar esta não-conformidade à Agência Nacional de Proteção de Dados:
    https://www.gov.br/anpd/pt-br/canais_atendimento/cidadao-titular-de-dados/denuncia-peticao-de-titular

══════════════════════════════════════════════════════════════════════════════════
BREOF
    fi
    echo -e "  [${GREEN}✓${NC}] ${I18N_20_CREATED_COMPLIANCE}"
    echo -e "  [${GREEN}✓${NC}] ${I18N_20_CREATED_COMPLIANCE_PTBR}"

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
cat > /etc/ageless/REFUSAL-PTBR << 'REFBREOF'
Este sistema roda Ageless Linux em modo flagrante.

Nenhuma API de verificação de idade existe nesse sistema. Nenhum dado de
idade é coletado, armazenado, ou disponível. Nenhum mecanismo de requisição
de sinais de faixa etária é providenciado. Isto não é um erro. Isto não é
um bug. Isto não é uma limitação técnica. Isto é uma recusa.

Se você for um desenvolvedor de aplicações procurando uma faixa de
sinal etário conforme a Lei Brasileira nº 15.211/2025, este provedor de
sistema operacional se recusa a fornecê-la. O desenvolvedor é informado
a tratar o usuário como um ser humano com idade indefinida.

Se você for um membro da Agência Nacional de Proteção de Dados (ANPD),
bom dia/tarde/noite/madrugada. O operador deste sistema está ciente de suas
obrigações sob a Lei Brasileira nº 15.211/2025 e escolheu não cumprí-la.
Ele(a) gostaria que você o(a) multasse. Seria um excelente caso de teste.
REFBREOF
        echo -e "  [${RED}✓${NC}] ${I18N_20_INSTALLED_REFUSAL}"
        echo -e "  [${RED}✗${NC}] ${I18N_20_SKIPPED_API_STUB}"
    else
cat > /etc/ageless/age-verification-api.sh << 'APIEOF'
#!/bin/bash
# Ageless Linux Age Verification API
# Required by Cal. Civ. Code § 1798.501(a)(2) and Brazilian Law nº 15.211/2025
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

echo "[EN-US]"
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
echo "============================================================"
echo "[PT-BR]"
echo "ERRO: Dados de idade não disponíveis"
echo ""
echo "Ageless Linux não coleta informações sobre a idade de seus usuários."
echo "Todos os usuários são assumidos como tendo idade indeterminada."
echo ""
echo "Se você é um desenvolvedor de aplicativos requisitando um"
echo "sinal de faixa etária conforme o Art. 12 inciso III da Lei 15.211/2025,"
echo "por favor saiba que o provedor deste sistema operacional está sob o"
echo "'benefício da dúvida' para cumprir a Lei Felca, e concluiu que"
echo "o melhor jeito de proteger a privacidade de uma criança é simplesmente"
echo "não coletar a idade dela pra início de conversa."
echo ""
echo "Tenha um bom dia."
exit 1
APIEOF
        chmod +x /etc/ageless/age-verification-api.sh
        echo -e "  [${GREEN}✓${NC}] ${I18N_20_INSTALLED_API_STUB}"
    fi
}

revert_compliance() {
    if [[ -d /etc/ageless ]]; then
        rm -rf /etc/ageless
        echo -e "  [${GREEN}✓${NC}] ${I18N_20_REMOVED_AGELESS}"
    fi
}

summary_compliance() {
    if [[ $FLAGRANT -eq 1 ]]; then
        echo -e "    /etc/ageless/ab1043-compliance.txt ..... ${I18N_20_SUMMARY_COMPLIANCE}"
        echo -e "    /etc/ageless/l15211-compliance.txt ..... ${I18N_20_SUMMARY_COMPLIANCE}"
        echo -e "    /etc/ageless/REFUSAL ................... ${I18N_20_SUMMARY_REFUSAL}"
        echo -e "    /etc/ageless/REFUSAL-PTBR .............. ${I18N_20_SUMMARY_REFUSAL}"
        echo ""
        echo -e "  ${I18N_20_SUMMARY_FILES_NOTCREATED}:"
        echo -e "    /etc/ageless/age-verification-api.sh ... ${RED}${I18N_20_SUMMARY_REFUSED}${NC}"
    else
        echo -e "    /etc/ageless/ab1043-compliance.txt"
        echo -e "    /etc/ageless/l15211-compliance.txt"
        echo -e "    /etc/ageless/age-verification-api.sh"
    fi
}

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

# §§ CONF — /etc/agelesslinux.conf installation record

plan_conf() {
    plan_action "${I18N_50_WRITE} ${CONF_PATH} ${I18N_50_INSTALLATION_RECORD}"
}

write_conf() {
    local install_date
    install_date=$(date -Iseconds 2>/dev/null || date "+%Y-%m-%dT%H:%M:%S%z")

    cat > "$CONF_PATH" << EOF
# [EN-US]
# /etc/agelesslinux.conf — Ageless Linux installation record
# Do not edit this file manually. Used by: become-ageless.sh --revert
# Written by become-ageless.sh ${AGELESS_VERSION} on ${install_date}
#
# [PT-BR]
# /etc/agelesslinux.conf — Registro de instalação do Ageless Linux
# Não edite este arquivo manualmente. Usado por: become-ageless.sh --revert
# Escrito por become-ageless.sh ${AGELESS_VERSION} em ${install_date}

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
    echo -e "  [${GREEN}✓${NC}] ${I18N_50_WROTE} ${CONF_PATH}"
}

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


main "$@"
