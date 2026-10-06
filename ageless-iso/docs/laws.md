# Laws & Flagrant mode

Ageless System Info (`ageless-system-info`) has a **Laws & Flagrant mode**
page. It lists laws that ask something of operating systems, app stores or
the software people may run. For each, a card shows what it asks, where it
stands (with a date), and its sources.

Where a law targets a kind of software, a **Flagrant mode** switch installs
the open-source tools it is about, from Debian main: a time capsule of what
a free computer can do. Using them is not doing anything wrong. The point
is awareness: this is what governments are asking of operating systems, and
this is the software that some would rather people didn't have.

![Laws & Flagrant mode](screenshots/sysinfo-laws.png)

The same catalog drives the `ageless-flagrant` command:

```console
$ ageless-flagrant
[off] age-signal Operating-system age signals  (California AB 1043 (2025) · Colorado SB26-051 (2026))
[off] vpn        VPN and circumvention restrictions  (Utah SB 73 (2026))
[off] emotion    Emotion recognition  (EU AI Act, Regulation (EU) 2024/1689, Art. 5(1)(f))
[off] scanning   Client-side message scanning  (EU CSAM Regulation proposal, COM(2022) 209 ("Chat Control"))
[ - ] app-store  App store age verification  (Utah SB 142 (2025) · Texas SB 2420 (2025) · Louisiana HB 570 (2025))
$ ageless-flagrant show vpn
$ sudo ageless-flagrant on vpn
```

## The catalog

`packages/ageless/sysinfo/laws.toml` (installed as
`/usr/share/ageless/laws.toml`) is the single source. Each switch maps to a
package:

| Law card | Switch installs | What's in it |
|---|---|---|
| Operating-system age signals (CA AB 1043, CO SB26-051) | `ageless-flagrant` (off: `ageless-standard`) | The existing flagrant stance: refusal notice, no age API, `birthDate` nulled by agelessd |
| VPN and circumvention restrictions (Utah SB 73) | `ageless-flagrant-vpn` | wireguard-tools, openvpn, openconnect and their NetworkManager plugins, tor, obfs4proxy, snowflake-client, sshuttle, proxychains4; recommends wireguard, strongswan, i2pd |
| Emotion recognition (EU AI Act Art. 5(1)(f)) | `ageless-flagrant-vision` | python3-opencv, opencv-data (face detection cascades), python3-onnxruntime, python3-sklearn, python3-skimage |
| Client-side message scanning (EU "Chat Control" proposal) | `ageless-flagrant-crypto` | gnupg, age, cryptsetup, openssl; recommends keepassxc |
| App store age verification (UT SB 142, TX SB 2420, LA HB 570) | — | Nothing to install: apt never asked. The Ageless Store won't either. |

The capsules install and configure nothing else: no services are enabled
and no camera is used. They live in the Ageless archive only, not on the
ISO, and `tests/package-test.sh` checks that each resolves on a clean
trixie. `ageless-flagrant-vision` is large: about 450 packages on a bare
system.

Debian has **no emotion-recognition package** (a search of trixie
descriptions for "emotion" and "facial" finds none). The vision capsule is
the general building blocks such systems are made from, and says so.

## Research notes (2026-10-06)

Gathered with web research on 2026-10-06. Fact sheets, **not legal
advice**. Three primary sources could not be fetched that day:

- leginfo.legislature.ca.gov (HTTP 403)
- le.utah.gov (HTTP 503)
- EUR-Lex (empty page)

Their entries rest on secondary sources (law-firm alerts, EFF, CalMatters,
artificialintelligenceact.eu) and should be re-checked against the primary
text.

- **California AB 1043** (Digital Age Assurance Act)
  - Status: signed 13 Oct 2025 (Ch. 675, Stats. 2025). Effective 1 Jan 2027; accounts that already exist must be covered by 1 Jul 2027.
  - OS duties: collect a birth date or age at account setup; give apps a real-time bracket signal (<13, 13–15, 16–17, 18+). No ID check.
  - Enforcement: Attorney General only, $2,500 / $7,500 per affected child.
- **Colorado SB26-051** (Age Attestation on Computing Devices)
  - Status: signed 3 Jun 2026. Effective 1 Jul 2028 per leg.colorado.gov. One secondary source says 1 Jan 2028; we use the legislature's date.
  - Duties: closely modelled on AB 1043.
- **Utah SB 73 (2026)**
  - Status: signed 19 Mar 2026. On 24 Sep 2026, D. Utah (Judge Barlow) preliminarily enjoined the actual-location (VPN) provision on dormant Commerce Clause grounds.
  - What stays in effect: the age-verification mandate and the ban on telling people how to bypass checks with a VPN.
  - Scope: it does not ban VPNs or regulate VPN providers.
  - Related bills:
    - Wisconsin AB 105: VPN clause removed, then vetoed on 3 Apr 2026.
    - Michigan HB 4938: would have had ISPs block VPNs; never voted on.
- **EU AI Act**, Regulation (EU) 2024/1689
  - Art. 5(1)(f) bans emotion inference in workplaces and education, except for medical or safety reasons. Applies since 2 Feb 2025; penalties since 2 Aug 2025 (up to €35M or 7% of turnover).
  - Art. 5(1)(g) bans biometric categorisation that infers sensitive traits.
  - Art. 50(3): deployers must tell people when emotion recognition is used on them, since 2 Aug 2026.
  - The 2026 Digital Omnibus reportedly left Art. 5 and 50(3) unchanged.
- **EU CSAM Regulation proposal** COM(2022) 209
  - Not adopted. Trilogues continue (latest 29 Sep 2026); the dispute is targeted versus broad detection orders.
- **App store acts**
  - Utah SB 142 (2025): duties moved to 6 May 2027 by HB 498 (2026), which also created a private right of action.
  - Texas SB 2420: enjoined 23 Dec 2025. The Fifth Circuit stayed the injunction in Jun 2026, and the Supreme Court declined to vacate the stay on 6 Jul 2026. Enforceable pending appeal.
  - Louisiana HB 570 (Act 481 of 2025): re-enacted by HB 977 (2026), effective 1 Jul 2027.
- **Not carded (no OS or software duty found):**
  - UK Online Safety Act age assurance (VPN limits debated but not enacted)
  - Australia's Social Media Minimum Age Act (platforms only)

## Keeping it current

- Re-verify each entry before a release and update `checked`. The unit
  tests require every entry to have a date, HTTPS sources and an existing
  package.
- Add a law by appending a `[[law]]` block. If it gets a switch, add an
  `ageless-flagrant-<topic>` package to `packages/ageless/debian/control`;
  `tests/test_build.py` fails if the two disagree.
- Keep the wording factual: say what the law asks, where it stands, and
  link the text. The app's framing ("a time capsule") carries the point.
