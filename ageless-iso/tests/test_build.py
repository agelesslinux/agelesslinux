"""Fast checks that run without containers: python3 -m unittest discover -s tests"""

import contextlib
import io
import re
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

import build  # noqa: E402


class ReleaseEnvTests(unittest.TestCase):
    def test_required_keys(self):
        env = build.read_release_env()
        for key in ("AGELESS_NAME", "AGELESS_VERSION", "AGELESS_CODENAME", "DEBIAN_SUITE",
                    "DEBIAN_VERSION", "DEBIAN_SNAPSHOT"):
            self.assertIn(key, env)
        self.assertEqual(env["AGELESS_NAME"], "Ageless Linux")

    def test_snapshot_format(self):
        snap = build.read_release_env()["DEBIAN_SNAPSHOT"]
        self.assertTrue(snap == "none" or re.fullmatch(r"\d{8}T\d{6}Z", snap), snap)

    def test_package_versions_track_release(self):
        """Every native package's changelog version starts with AGELESS_VERSION."""
        version = build.read_release_env()["AGELESS_VERSION"]
        for changelog in ROOT.glob("packages/*/debian/changelog"):
            first = changelog.read_text().splitlines()[0]
            pkg_version = re.search(r"\(([^)]+)\)", first).group(1)
            self.assertTrue(pkg_version.startswith(version + "."),
                            f"{changelog}: {pkg_version} does not track release {version}")

    def test_calamares_sources_final_suite_matches_codename(self):
        codename = build.read_release_env()["AGELESS_CODENAME"]
        helper = ROOT / "packages/calamares-settings-ageless/helpers/calamares-sources-final"
        self.assertIn(f'AGELESS_SUITE="{codename}"', helper.read_text())


class BuildPyTests(unittest.TestCase):
    def test_inner_script_per_variant(self):
        self.assertIn("variant-live/build-inner.sh", build.inner_script("live"))
        self.assertIn("variant-netinst/build-inner.sh", build.inner_script("netinst"))
        self.assertNotIn("variant-", build.inner_script("packages"))

    def test_dry_run_live_is_privileged_and_passes_stance(self):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            rc = build.main(["--variant", "live", "--arch", "amd64", "--flagrant",
                             "--runtime", "docker", "--dry-run", "--snapshot", "none"])
        self.assertEqual(rc, 0)
        text = out.getvalue()
        self.assertIn("--privileged", text)
        self.assertIn("STANCE=flagrant", text)
        self.assertIn("SNAPSHOT=none", text)

    def test_dry_run_packages_is_unprivileged(self):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            build.main(["--variant", "packages", "--runtime", "docker", "--dry-run"])
        run_line = [l for l in out.getvalue().splitlines() if " run " in l][0]
        self.assertNotIn("--privileged", run_line)


if __name__ == "__main__":
    unittest.main()
