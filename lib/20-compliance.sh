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
