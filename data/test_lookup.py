#!/usr/bin/env python3
"""End-to-end tests for the address-to-legislator lookup pipeline.

These tests hit the live Census geocoder API — they require network access
and may be slow (~2-5s per geocode call).
"""

import pytest

from lookup import (
    LookupError,
    geocode_address,
    lookup_federal_legislators,
    lookup_legislators,
    lookup_state_legislators,
)


# ---------------------------------------------------------------------------
# Geocoder
# ---------------------------------------------------------------------------

class TestGeocodeAddress:
    def test_sf_address(self):
        """425 Market St, San Francisco resolves to CD-11, SD-11, AD-17."""
        result = geocode_address("425 Market St, San Francisco, CA 94105")
        assert result["state_abbr"] == "CA"
        assert result["congressional_district"] == 11
        assert result["state_senate_district"] == 11
        assert result["state_assembly_district"] == 17
        assert "SAN FRANCISCO" in result["matched_address"]

    def test_la_address(self):
        """100 W 1st St, Los Angeles resolves to CD-34, SD-26, AD-54."""
        result = geocode_address("100 W 1st St, Los Angeles, CA 90012")
        assert result["state_abbr"] == "CA"
        assert result["congressional_district"] == 34
        assert result["state_senate_district"] == 26
        assert result["state_assembly_district"] == 54

    def test_invalid_address_raises(self):
        with pytest.raises(LookupError, match="Address not found"):
            geocode_address("not a real address at all")


# ---------------------------------------------------------------------------
# Federal legislator lookup (offline — uses local YAML data)
# ---------------------------------------------------------------------------

class TestFederalLookup:
    def test_ca_senators(self):
        """CA should have exactly 2 senators."""
        results = lookup_federal_legislators("CA", None)
        senators = [r for r in results if r["office"] == "U.S. Senator"]
        assert len(senators) == 2
        for s in senators:
            assert s["level"] == "federal"
            assert s["district"] == "CA"

    def test_ca_11_representative(self):
        """CA-11 should return exactly one representative."""
        results = lookup_federal_legislators("CA", 11)
        reps = [r for r in results if r["office"] == "U.S. Representative"]
        assert len(reps) == 1
        assert reps[0]["district"] == "CA-11"

    def test_fax_numbers_are_lists_or_none(self):
        """Fax field should be a list of strings or None."""
        results = lookup_federal_legislators("CA", 11)
        for r in results:
            if r["fax"] is not None:
                assert isinstance(r["fax"], list)
                assert all(isinstance(f, str) for f in r["fax"])


# ---------------------------------------------------------------------------
# State legislator lookup (offline — uses local CSV data)
# ---------------------------------------------------------------------------

class TestStateLookup:
    def test_ca_sd11_ad17(self):
        """CA SD-11 + AD-17 should return one senator and one assembly member."""
        results = lookup_state_legislators("CA", 11, 17)
        offices = {r["office"] for r in results}
        assert "State Senator" in offices
        assert "State Representative" in offices
        assert all(r["level"] == "state" for r in results)

    def test_ca_algorithmic_fax(self):
        """CA state legislators should have algorithmic fax numbers."""
        results = lookup_state_legislators("CA", 11, 17)
        for r in results:
            assert r["fax"] is not None, f"{r['name']} missing fax"
            # CA algorithmic faxes follow known patterns
            for fax in r["fax"]:
                assert fax.startswith("(916)")

    def test_missing_state_returns_empty(self):
        """A state with no Open States CSV should return empty list."""
        results = lookup_state_legislators("WY", 1, 1)
        assert results == []


# ---------------------------------------------------------------------------
# Full pipeline (requires network)
# ---------------------------------------------------------------------------

class TestFullPipeline:
    def test_sf_end_to_end(self):
        """Full pipeline for 425 Market St, San Francisco."""
        result = lookup_legislators("425 Market St, San Francisco, CA 94105")

        assert "SAN FRANCISCO" in result["address"]
        assert result["districts"]["state"] == "CA"
        assert result["districts"]["congressional"] == 11

        # Should have 2 senators + 1 rep + 1 state senator + 1 assembly member = 5
        assert len(result["legislators"]) == 5

        levels = {r["level"] for r in result["legislators"]}
        assert levels == {"federal", "state"}

        # At least some legislators should have fax numbers
        fax_count = sum(1 for r in result["legislators"] if r["fax"])
        assert fax_count >= 3, "Expected at least 3 legislators with fax numbers"

    def test_invalid_address_end_to_end(self):
        with pytest.raises(LookupError):
            lookup_legislators("xyzzy nowhere fake address 99999")
