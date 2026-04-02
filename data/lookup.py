#!/usr/bin/env python3
"""Address-to-legislator lookup pipeline.

Given a US street address, returns congressional and state legislative
district identifiers, then resolves those to legislator contact info
using local data from congress-legislators (federal) and Open States (state).

Uses the Census Bureau geocoder (free, no API key required).
"""

import csv
import json
import os
import urllib.parse
import urllib.request
from pathlib import Path

import yaml

DATA_DIR = Path(__file__).parent
FEDERAL_LEGISLATORS = DATA_DIR / "federal" / "legislators-current.yaml"
FEDERAL_DISTRICT_OFFICES = DATA_DIR / "federal" / "legislators-district-offices.yaml"
OPENSTATES_DIR = DATA_DIR / "openstates"

CENSUS_GEOCODER_URL = (
    "https://geocoding.geo.census.gov/geocoder/geographies/onelineaddress"
)

# FIPS state code -> state abbreviation
FIPS_TO_STATE = {
    "01": "AL", "02": "AK", "04": "AZ", "05": "AR", "06": "CA",
    "08": "CO", "09": "CT", "10": "DE", "11": "DC", "12": "FL",
    "13": "GA", "15": "HI", "16": "ID", "17": "IL", "18": "IN",
    "19": "IA", "20": "KS", "21": "KY", "22": "LA", "23": "ME",
    "24": "MD", "25": "MA", "26": "MI", "27": "MN", "28": "MS",
    "29": "MO", "30": "MT", "31": "NE", "32": "NV", "33": "NH",
    "34": "NJ", "35": "NM", "36": "NY", "37": "NC", "38": "ND",
    "39": "OH", "40": "OK", "41": "OR", "42": "PA", "44": "RI",
    "45": "SC", "46": "SD", "47": "TN", "48": "TX", "49": "UT",
    "50": "VT", "51": "VA", "53": "WA", "54": "WV", "55": "WI",
    "56": "WY", "60": "AS", "66": "GU", "69": "MP", "72": "PR",
    "78": "VI",
}


class LookupError(Exception):
    """Raised when address geocoding or district lookup fails."""


# ---------------------------------------------------------------------------
# Census geocoder: address -> districts
# ---------------------------------------------------------------------------

def geocode_address(address: str) -> dict:
    """Geocode a US street address to congressional and state legislative districts.

    Returns dict with keys:
        matched_address, state_fips, state_abbr,
        congressional_district, state_senate_district, state_assembly_district
    """
    params = urllib.parse.urlencode({
        "address": address,
        "benchmark": "Public_AR_Current",
        "vintage": "Current_Current",
        "layers": "all",
        "format": "json",
    })
    url = f"{CENSUS_GEOCODER_URL}?{params}"

    req = urllib.request.Request(url, headers={"User-Agent": "agelesslinux/0.1"})
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = json.loads(resp.read())
    except Exception as exc:
        raise LookupError(f"Census geocoder request failed: {exc}") from exc

    matches = data.get("result", {}).get("addressMatches", [])
    if not matches:
        raise LookupError(
            f"Address not found by Census geocoder: {address!r}"
        )

    match = matches[0]
    geos = match.get("geographies", {})

    # Extract state FIPS from the States layer
    state_fips = None
    for entry in geos.get("States", []):
        state_fips = entry.get("GEOID") or entry.get("STATE")
        break

    if not state_fips:
        raise LookupError("Could not determine state from geocoder response")

    state_abbr = FIPS_TO_STATE.get(state_fips)
    if not state_abbr:
        raise LookupError(f"Unknown state FIPS code: {state_fips}")

    # Congressional district
    cd = None
    for key in geos:
        if "Congressional" in key:
            for entry in geos[key]:
                raw = entry.get("BASENAME", "")
                # BASENAME is like "11" or "Delegate District (at Large)"
                if raw.isdigit():
                    cd = int(raw)
                elif "at Large" in raw or "at-large" in raw.lower():
                    cd = 0  # at-large
                break
            break

    # State legislative districts
    upper = None
    lower = None
    for key in geos:
        if "Legislative" in key and "Upper" in key:
            for entry in geos[key]:
                raw = entry.get("BASENAME", "")
                if raw.isdigit():
                    upper = int(raw)
                break
        elif "Legislative" in key and "Lower" in key:
            for entry in geos[key]:
                raw = entry.get("BASENAME", "")
                if raw.isdigit():
                    lower = int(raw)
                break

    return {
        "matched_address": match.get("matchedAddress", address),
        "state_fips": state_fips,
        "state_abbr": state_abbr,
        "congressional_district": cd,
        "state_senate_district": upper,
        "state_assembly_district": lower,
    }


# ---------------------------------------------------------------------------
# Federal legislator lookup
# ---------------------------------------------------------------------------

_federal_cache = {}


def _load_federal_data():
    if "legislators" not in _federal_cache:
        with open(FEDERAL_LEGISLATORS) as f:
            _federal_cache["legislators"] = yaml.safe_load(f)
    if "offices" not in _federal_cache:
        with open(FEDERAL_DISTRICT_OFFICES) as f:
            _federal_cache["offices"] = yaml.safe_load(f)
    return _federal_cache["legislators"], _federal_cache["offices"]


def _find_district_faxes(bioguide: str, offices_data: list) -> list[str]:
    """Return list of fax numbers from district offices for a given bioguide ID."""
    for leg in offices_data:
        if leg["id"]["bioguide"] == bioguide:
            faxes = []
            for office in leg.get("offices", []):
                if office.get("fax"):
                    faxes.append(office["fax"])
            return faxes
    return []


def lookup_federal_legislators(state_abbr: str, congressional_district: int | None) -> list[dict]:
    """Look up federal legislators for a state and congressional district.

    Returns both senators (by state) and the representative (by district).
    """
    legislators_data, offices_data = _load_federal_data()
    results = []

    for leg in legislators_data:
        terms = leg.get("terms", [])
        if not terms:
            continue
        current = terms[-1]

        if current.get("state") != state_abbr:
            continue

        # Senators match by state only; reps match by district
        if current["type"] == "sen":
            pass  # include
        elif current["type"] == "rep":
            if congressional_district is None:
                continue
            if current.get("district") != congressional_district:
                continue
        else:
            continue

        bioguide = leg["id"]["bioguide"]
        dc_fax = current.get("fax")
        district_faxes = _find_district_faxes(bioguide, offices_data)

        # Collect all fax numbers, DC first
        all_faxes = []
        if dc_fax:
            all_faxes.append(dc_fax)
        all_faxes.extend(district_faxes)

        name = leg["name"].get("official_full") or f"{leg['name']['first']} {leg['name']['last']}"

        office_type = "U.S. Senator" if current["type"] == "sen" else "U.S. Representative"
        district_label = (
            f"{state_abbr}"
            if current["type"] == "sen"
            else f"{state_abbr}-{congressional_district:02d}"
        )

        results.append({
            "name": name,
            "office": office_type,
            "party": current.get("party", "Unknown"),
            "district": district_label,
            "fax": all_faxes if all_faxes else None,
            "phone": current.get("phone"),
            "bioguide": bioguide,
            "level": "federal",
        })

    return results


# ---------------------------------------------------------------------------
# State legislator lookup
# ---------------------------------------------------------------------------

_state_cache = {}


def _load_state_data(state_abbr: str) -> list[dict]:
    """Load Open States CSV for a state. Returns list of row dicts."""
    key = state_abbr.lower()
    if key not in _state_cache:
        csv_path = OPENSTATES_DIR / f"{key}.csv"
        if not csv_path.exists():
            _state_cache[key] = []
            return []
        with open(csv_path, newline="", encoding="utf-8") as f:
            _state_cache[key] = list(csv.DictReader(f))
    return _state_cache[key]


def _ca_algorithmic_fax(chamber: str, district: int) -> str:
    """Compute California Capitol fax number from chamber and district.

    Assembly: (916) 319-21XX where XX = zero-padded district (01-80)
    Senate:   (916) 651-49XX where XX = zero-padded district (01-40)
    """
    if chamber == "lower":
        return f"(916) 319-21{district:02d}"
    elif chamber == "upper":
        return f"(916) 651-49{district:02d}"
    return None


def lookup_state_legislators(
    state_abbr: str,
    upper_district: int | None,
    lower_district: int | None,
) -> list[dict]:
    """Look up state legislators for given senate and assembly districts."""
    rows = _load_state_data(state_abbr)
    results = []

    for row in rows:
        chamber = row.get("current_chamber", "")
        try:
            district_num = int(row.get("current_district", ""))
        except (ValueError, TypeError):
            continue

        matched = False
        if chamber == "upper" and upper_district is not None and district_num == upper_district:
            matched = True
        elif chamber == "lower" and lower_district is not None and district_num == lower_district:
            matched = True

        if not matched:
            continue

        # Collect fax numbers
        faxes = []
        for fax_field in ("capitol_fax", "district_fax"):
            val = row.get(fax_field, "").strip()
            if val:
                faxes.append(val)

        # Apply CA algorithmic fax if no fax data from Open States
        if not faxes and state_abbr == "CA":
            algo_fax = _ca_algorithmic_fax(chamber, district_num)
            if algo_fax:
                faxes.append(algo_fax)

        office_type = (
            "State Senator" if chamber == "upper" else "State Representative"
        )
        district_label = (
            f"{state_abbr} SD-{district_num:02d}"
            if chamber == "upper"
            else f"{state_abbr} AD-{district_num:02d}"
        )

        results.append({
            "name": row.get("name", "Unknown"),
            "office": office_type,
            "party": row.get("current_party", "Unknown"),
            "district": district_label,
            "fax": faxes if faxes else None,
            "phone": row.get("capitol_voice") or row.get("district_voice") or None,
            "email": row.get("email") or None,
            "level": "state",
        })

    return results


# ---------------------------------------------------------------------------
# Unified pipeline
# ---------------------------------------------------------------------------

def lookup_legislators(address: str) -> dict:
    """Full pipeline: address -> districts -> legislators.

    Returns dict with:
        address: matched address string
        districts: district identifiers from geocoder
        legislators: list of legislator records (federal + state)
    """
    geo = geocode_address(address)

    federal = lookup_federal_legislators(
        geo["state_abbr"],
        geo["congressional_district"],
    )
    state = lookup_state_legislators(
        geo["state_abbr"],
        geo["state_senate_district"],
        geo["state_assembly_district"],
    )

    return {
        "address": geo["matched_address"],
        "districts": {
            "state": geo["state_abbr"],
            "congressional": geo["congressional_district"],
            "state_senate": geo["state_senate_district"],
            "state_assembly": geo["state_assembly_district"],
        },
        "legislators": federal + state,
    }


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def _format_result(result: dict) -> str:
    lines = []
    lines.append(f"Address: {result['address']}")
    d = result["districts"]
    lines.append(
        f"Districts: CD-{d['congressional']:02d}, "
        f"SD-{d['state_senate']:02d}, "
        f"AD-{d['state_assembly']:02d} "
        f"({d['state']})"
    )
    lines.append("")

    for leg in result["legislators"]:
        fax_str = ", ".join(leg["fax"]) if leg["fax"] else "none on file"
        phone_str = leg.get("phone") or "none on file"
        lines.append(f"  {leg['name']}")
        lines.append(f"    {leg['office']} — {leg['district']} ({leg['party']})")
        lines.append(f"    Phone: {phone_str}")
        lines.append(f"    Fax:   {fax_str}")
        lines.append("")

    return "\n".join(lines)


if __name__ == "__main__":
    import sys

    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <address>")
        print(f"Example: {sys.argv[0]} '425 Market St, San Francisco, CA 94105'")
        sys.exit(1)

    address = " ".join(sys.argv[1:])
    try:
        result = lookup_legislators(address)
    except LookupError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        sys.exit(1)

    print(_format_result(result))
