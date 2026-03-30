# Fax Your Rep — Data Coverage Report

**Date:** 2026-03-30
**Purpose:** Assess legislator fax number coverage and age verification legislation landscape to determine launch viability for a "Fax Your Rep" campaign tool.

---

## 1. Target States

States identified from agelesslinux.org content and project priorities:

| State | Why Targeted |
|-------|-------------|
| **California** | AB 1043 — the primary statute this project exists to oppose |
| **Colorado** | SB 26-051 — explicit copy of AB 1043, advancing through legislature |
| **Illinois** | SB 3977 — mirrors AB 1043, in committee |
| **Louisiana** | HB 570 — enacted, effective Jul 1 2026 |
| **New York** | S8102A — stricter than CA (no self-declaration), in committee |
| **Texas** | SB 2420 — enacted but enjoined, appeal pending |
| **Utah** | SB 142 — enacted, CCIA lawsuit, enforcement stayed |

Additional states referenced on the site (CT, MD, MN, VT, GA, VA, MI) appear in advocacy/model-bill context only — no active OS-level age assurance bills.

---

## 2. Federal Legislator Fax Coverage

**Source:** [unitedstates/congress-legislators](https://github.com/unitedstates/congress-legislators) (public domain, cloned to `data/congress-legislators/`)

### Overall

| Metric | Count | Percentage |
|--------|-------|-----------|
| Total current members | 538 | — |
| Senators | 100 | — |
| Representatives | 438 | — |
| **DC office fax** | **10** | **1.9%** |
| District office fax (any) | 229 | 42.6% |
| **Any fax (DC or district)** | **236** | **43.9%** |

DC fax coverage is effectively zero. Only 10 members have a DC fax number in the dataset:

| Name | Chamber | State | DC Fax |
|------|---------|-------|--------|
| Edward J. Markey | Senate | MA | 202-228-0769 |
| Adam B. Schiff | Senate | CA | 202-228-0026 |
| Christopher H. Smith | House | NJ | 202-225-7768 |
| Richard Hudson | House | NC | 202-225-4036 |
| Thom Tillis | Senate | NC | 202-228-2563 |
| Rick Scott | Senate | FL | 202-228-4535 |
| Tommy Tuberville | Senate | AL | 202-225-0562 |
| John W. Hickenlooper | Senate | CO | 202-224-3115 |
| Cliff Bentz | House | OR | 202-225-5774 |
| Raphael G. Warnock | Senate | GA | 202-228-0724 |

### Per Target State (Federal Delegation)

| State | Total | DC Fax | District Fax | Any Fax | Coverage |
|-------|-------|--------|-------------|---------|----------|
| CA | 53 | 1 | 23 | 24 | 45% |
| CO | 10 | 1 | 2 | 3 | 30% |
| IL | 19 | 0 | 10 | 10 | 53% |
| LA | 8 | 0 | 1 | 1 | 12% |
| NY | 28 | 0 | 9 | 9 | 32% |
| TX | 40 | 0 | 16 | 16 | 40% |
| UT | 6 | 0 | 2 | 2 | 33% |

### Data Schema

File: `legislators-current.yaml` — fax is in the current term record as `fax` (DC office only).
File: `legislators-district-offices.yaml` — fax is per-office as `fax`.

---

## 3. State Legislator Fax Coverage

**Source:** [Open States / Plural Policy](https://open.pluralpolicy.com/data/) bulk CSVs (downloaded to `data/openstates/`)

### Open States Data (as downloaded)

| State | Total Legislators | Capitol Fax | District Fax | Any Fax | Coverage |
|-------|------------------|-------------|-------------|---------|----------|
| CA | 120 | 0 | 0 | 0 | **0%** |
| CO | 100 | 0 | 0 | 0 | **0%** |
| IL | 177 | 0 | 1 | 1 | **1%** |
| LA | 141 | 0 | 1 | 1 | **1%** |
| NY | 213 | 0 | 39 | 39 | **18%** |
| TX | 180 | 0 | 0 | 0 | **0%** |
| UT | 104 | 0 | 0 | 0 | **0%** |

Open States fax data is catastrophically incomplete. Zero capitol fax numbers for any state. Only New York has meaningful district fax coverage.

### Official Legislature Websites (Manual Research)

| State | Capitol Fax Available? | District Fax Available? | Algorithmic Pattern? |
|-------|----------------------|------------------------|---------------------|
| **CA** | **YES — 100% computable** | Some (~50% on caucus sites) | **YES** |
| CO | No | No | N/A |
| IL | No | Some (sporadic) | No |
| LA | No | Many House, few Senate | No |
| NY | Some Assembly (~25%) | Some (~25%) | No |
| TX | Some | Some | No |
| UT | No | No | N/A |

### California: Algorithmic Fax Numbers (Key Finding)

Both chambers of the California Legislature use predictable, sequential Capitol fax numbers:

- **Assembly:** `(916) 319-21XX` where XX = zero-padded district number (01–80)
- **Senate:** `(916) 651-49XX` where XX = zero-padded district number (01–40)

This gives **120 out of 120 (100%)** California state legislators with a computable Capitol fax number, despite Open States showing 0%.

Verified against published numbers on individual Assembly caucus sites and Senate member sites. Every published fax number matched the pattern exactly.

**No other target state has an algorithmic fax pattern.** Texas Senate has patterned *phone* numbers ((512) 463-01XX) but fax numbers are non-patterned.

---

## 4. Age Verification Legislation Landscape

### State Bills

| State | Bill | Status | Effective Date | Next Milestone |
|-------|------|--------|---------------|----------------|
| **CA** | AB 1043 | **Enacted** | Jan 1, 2027 | No challenge filed; one expected |
| **CO** | SB 26-051 | Passed Senate 28-7 | TBD (default ~Aug 2026) | House committee assignment |
| **IL** | SB 3977 | In committee | Jan 1, 2028 if enacted | Committee deadline Apr 24 |
| **LA** | HB 570 | **Enacted** | Jul 1, 2026 | No challenge filed |
| **NY** | S8102A | In committee | 1 yr after enactment | Hearing TBD |
| **TX** | SB 2420 | **Enacted, enjoined** | Blocked | Fifth Circuit ruling pending |
| **UT** | SB 142 | **Enacted, stayed** | May 6, 2026 | PI hearing Apr/May 2026 |

**Key sponsors:**
- CA: Asm. Buffy Wicks (D)
- CO: Sen. Matt Ball (D), Sen. Larry Liston (R), Rep. Amy Paschal (D), Rep. Naquetta Ricks (D)
- IL: Sen. Laura Ellman (D)
- LA: Rep. Kim Carver
- NY: Sen. Andrew Gounardes (D)
- TX: Sen. Bryan Hughes (R)
- UT: (SB 142 sponsors TBD)

### Federal Bills

| Bill | Status | Next Step |
|------|--------|-----------|
| **KIDS Act (H.R. 7757)** | Passed House committee 28-24 (party-line, Mar 6 2026) | Full House floor vote |
| **KOSA (S. 1748)** | In Senate committee (reintroduced 119th Congress) | Committee markup TBD |
| **COPPA 2.0 (S. 836)** | **Passed Senate unanimously** (Mar 5-6, 2026) | House action needed |

COPPA 2.0 is the furthest along federally. The KIDS Act incorporates a weakened House version of KOSA. Senate and House versions differ significantly.

---

## 5. Combined Coverage Matrix

For each target state, how many legislators (federal + state) can we reach by fax?

| State | Federal (w/ fax) | Federal (total) | State (w/ fax) | State (total) | Combined Reachable | Combined Total | **Coverage** |
|-------|-----------------|----------------|----------------|--------------|-------------------|---------------|-------------|
| CA | 24 | 53 | **120*** | 120 | **144** | 173 | **83%** |
| CO | 3 | 10 | 0 | 100 | 3 | 110 | 3% |
| IL | 10 | 19 | ~10† | 177 | ~20 | 196 | ~10% |
| LA | 1 | 8 | ~50† | 141 | ~51 | 149 | ~34% |
| NY | 9 | 28 | ~50† | 213 | ~59 | 241 | ~24% |
| TX | 16 | 40 | ~30† | 180 | ~46 | 220 | ~21% |
| UT | 2 | 6 | 0 | 104 | 2 | 110 | 2% |

\* California: 120/120 via algorithmic derivation
† Estimated from official site spot-checks; would require full scrape to confirm

---

## 6. Recommended Launch States

### Tier 1: Launch Ready

**California** — The obvious first target.
- 100% state legislator fax coverage (algorithmic)
- 45% federal delegation fax coverage
- AB 1043 is the primary statute we exist to oppose
- Effective date Jan 1 2027 creates urgency
- **Recommendation: Launch here first.**

### Tier 2: Strong Candidates

**New York** — Best existing fax data of any state.
- 18% state legislator fax in Open States (39/213), likely higher with scraping
- S8102A is the most aggressive bill (no self-declaration)
- Large delegation = high impact
- **Recommendation: Second launch state. Scrape nyassembly.gov for more fax numbers.**

**Illinois** — Active bill with near-term deadline.
- SB 3977 committee deadline Apr 24 — immediate urgency
- 53% federal fax coverage (best among target states)
- State fax sparse but some available via ilga.gov
- **Recommendation: Prioritize for federal-only fax campaign. State coverage needs scraping work.**

### Tier 3: Viable with Work

**Texas** — Enjoined statute creates unique angle.
- Some state fax numbers available on official site
- 40% federal delegation fax coverage
- Enjoined status means faxes can reference the constitutional victory
- **Recommendation: Needs official site scrape. Good narrative state.**

**Louisiana** — Enacted, effective soon, some fax data.
- HB 570 effective Jul 1 2026 — approaching fast
- Many House members have fax on official site
- Small federal delegation (8), only 1 with fax
- **Recommendation: Needs House site scrape. Federal coverage gap is a problem.**

### Tier 4: Not Ready

**Colorado** — Bill advancing but zero fax coverage.
- 0% state fax, 30% federal (3 of 10)
- Legislature does not publish fax numbers at all
- **Recommendation: Federal-only at best. Skip for launch.**

**Utah** — Enacted but zero fax coverage.
- 0% state fax, 33% federal (2 of 6)
- Legislature has moved entirely away from fax
- CCIA lawsuit may render moot before we could launch
- **Recommendation: Skip. The courts are handling it.**

---

## 7. Data Sources

| Source | URL | Format | License |
|--------|-----|--------|---------|
| unitedstates/congress-legislators | https://github.com/unitedstates/congress-legislators | YAML | Public domain |
| Open States / Plural Policy | https://open.pluralpolicy.com/data/ | CSV | Public domain (CC0) |
| CA Assembly member sites | https://www.assembly.ca.gov/assemblymembers | HTML (per-member) | Public record |
| CA Senate member sites | https://sd{NN}.senate.ca.gov | HTML (per-member) | Public record |
| NY Assembly | https://nyassembly.gov | HTML | Public record |
| IL General Assembly | https://ilga.gov | HTML | Public record |
| LA Legislature | https://house.louisiana.gov / https://senate.la.gov | HTML | Public record |
| TX Capitol | https://capitol.texas.gov | HTML | Public record |
| LegiScan | https://legiscan.com | JSON/CSV | Commercial (free tier) |
| KnowWho | https://kw1.knowwho.com/state-legislators-data-service/ | CSV | Commercial ($$$) |

---

## 8. Gaps and Next Steps

### Immediate (before launch)

1. **Build CA fax number dataset.** Algorithmically generate all 120 Capitol fax numbers for CA legislature. Verify a sample by calling/faxing.
2. **Scrape NY Assembly fax numbers.** Open States has 39; official site likely has more. Target 50%+ coverage.
3. **Design the federal fax gap strategy.** 56% of Congress has no fax number anywhere. Options:
   - Phone-to-fax services (eFax, etc.) — would the campaign send to phone numbers?
   - Focus on legislators who DO have fax (creates selection bias but maximizes deliverability)
   - Publicly document which members have abandoned fax (shame angle: "your representative doesn't even have a fax machine")

### Medium-term

4. **Scrape IL, LA, TX official legislature sites** for fax numbers not in Open States.
5. **Monitor CO SB 26-051** House progress — if it passes, CO becomes urgent regardless of fax coverage.
6. **Track TX Fifth Circuit ruling** — an unfavorable ruling changes the national landscape.
7. **Investigate KnowWho commercial data** — they claim all 7,552 state legislators with fax. Expensive but comprehensive.

### Data maintenance

8. **Open States CSVs update nightly** — set up periodic re-download.
9. **congress-legislators repo is community-maintained** — `git pull` periodically.
10. **Legislative status changes fast** — IL committee deadline Apr 24, LA effective Jul 1, UT PI hearing Apr/May.

---

## 9. Key Insight

The fax landscape is bifurcated. **California has perfect coverage** (algorithmic Capitol fax numbers for all 120 state legislators), while most other states have near-zero. This makes California the obvious and only viable launch state for state-level faxing.

For federal legislators, district office fax numbers provide ~44% coverage nationally. The "Fax Your Rep" tool should launch as **CA state + CA federal delegation**, then expand to NY and IL as scraping fills gaps.

The tagline writes itself: *"No age verification required to send a fax."*
