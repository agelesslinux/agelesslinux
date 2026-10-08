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
        """Ageless-native packages carry exactly AGELESS_VERSION (forks: +ageless<N>)."""
        version = build.read_release_env()["AGELESS_VERSION"]
        for changelog in ROOT.glob("packages/*/debian/changelog"):
            first = changelog.read_text().splitlines()[0]
            pkg_version = re.search(r"\(([^)]+)\)", first).group(1)
            if "+ageless" in pkg_version:
                continue
            self.assertEqual(pkg_version, version, f"{changelog} does not track release {version}")

    def test_calamares_sources_final_suite_matches_codename(self):
        codename = build.read_release_env()["AGELESS_CODENAME"]
        helper = ROOT / "packages/calamares-settings-ageless/helpers/calamares-sources-final"
        self.assertIn(f'AGELESS_SUITE="{codename}"', helper.read_text())


class BuildPyTests(unittest.TestCase):
    def test_inner_script_per_variant(self):
        self.assertIn("variant-live/build-inner.sh", build.inner_script("live"))
        self.assertIn("variant-netinst/build-inner.sh", build.inner_script("netinst"))
        self.assertNotIn("variant-", build.inner_script("packages"))

    def test_rebuilds_run_before_package_index(self):
        script = build.inner_script("live")
        self.assertLess(script.index("tools/rebuild.py"), script.index("tools/build-packages.sh"))
        self.assertNotIn("tools/rebuild.py", build.inner_script("live", rebuilds=False))

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

    def test_dry_run_reports_version(self):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            build.main(["--variant", "packages", "--runtime", "docker", "--dry-run"])
        self.assertRegex(out.getvalue(), r"AGELESS_VERSION_SUFFIX=(~\d+\.g[0-9a-f]+(\.dirty[\d.]+)?)?'?\s")
        self.assertIn("tools/make-repo.py build", out.getvalue())

    def test_dry_run_packages_is_unprivileged(self):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            build.main(["--variant", "packages", "--runtime", "docker", "--dry-run"])
        run_line = [l for l in out.getvalue().splitlines() if " run " in l][0]
        self.assertNotIn("--privileged", run_line)



class ReleaseCycleTests(unittest.TestCase):
    """tools/release.py in a scratch git repo: dev builds, release, next version."""

    def setUp(self):
        import shutil, subprocess, tempfile
        self.sp = subprocess
        self.tmp = Path(tempfile.mkdtemp())
        (self.tmp / "tools").mkdir()
        shutil.copy(ROOT / "tools/release.py", self.tmp / "tools/release.py")
        (self.tmp / "common").mkdir()
        (self.tmp / "common/release.env").write_text('AGELESS_VERSION="0.1.0"\nAGELESS_CODENAME="timeless"\n')
        for name, version in (("ageless", "0.1.0"), ("mintmenu", "6.2.3+ageless1")):
            d = self.tmp / "packages" / name / "debian"
            d.mkdir(parents=True)
            (d / "changelog").write_text(
                f"{name} ({version}) UNRELEASED; urgency=medium\n\n  * x\n\n"
                f" -- A <a@b>  Thu, 08 Oct 2026 12:00:00 +0000\n")
        self.git("init", "-q")
        self.git("add", ".")
        self.git("commit", "-qm", "one")

    def git(self, *args):
        env = dict(__import__("os").environ, GIT_AUTHOR_NAME="t", GIT_AUTHOR_EMAIL="t@t",
                   GIT_COMMITTER_NAME="t", GIT_COMMITTER_EMAIL="t@t")
        return self.sp.run(["git", "-C", str(self.tmp), *args], check=True, env=env,
                           capture_output=True, text=True).stdout.strip()

    def release(self, *args):
        return self.sp.run([sys.executable, str(self.tmp / "tools/release.py"), *args],
                           capture_output=True, text=True)

    def test_cycle(self):
        dev = self.release("version")
        self.assertRegex(dev.stdout.strip(), r"^0\.1\.0~1\.g[0-9a-f]{7}$")
        # Unfinalized changelogs block the tag.
        self.git("tag", "v0.1.0")
        self.assertNotEqual(self.release("check", "v0.1.0").returncode, 0)
        self.git("tag", "-d", "v0.1.0")
        self.assertEqual(self.release("finalize").returncode, 0)
        self.git("commit", "-qam", "Release 0.1.0")
        self.git("tag", "v0.1.0")
        self.assertEqual(self.release("check", "v0.1.0").returncode, 0, self.release("check", "v0.1.0").stderr)
        self.assertEqual(self.release("version").stdout.strip(), "0.1.0")
        # Past the tag without starting 0.1.1: refused, it would sort below the release.
        (self.tmp / "packages/ageless/x").write_text("x")
        self.git("add", ".")
        self.git("commit", "-qm", "work")
        self.assertIn("already tagged", self.release("version").stderr)
        self.assertEqual(self.release("next", "0.1.1").returncode, 0)
        self.git("commit", "-qam", "Start 0.1.1")
        self.assertRegex(self.release("version").stdout.strip(), r"^0\.1\.1~2\.g[0-9a-f]{7}$")
        head = (self.tmp / "packages/ageless/debian/changelog").read_text().splitlines()[0]
        self.assertEqual(head, "ageless (0.1.1) UNRELEASED; urgency=medium")
        fork = (self.tmp / "packages/mintmenu/debian/changelog").read_text().splitlines()[0]
        self.assertIn("(6.2.3+ageless1) timeless", fork)
        # Dirty trees get a timestamp that sorts after the clean build of the same commit.
        (self.tmp / "common/scratch").write_text("x")
        self.assertRegex(self.release("version").stdout.strip(), r"^0\.1\.1~2\.g[0-9a-f]{7}\.dirty\d{8}\.\d{6}$")

    def test_fork_changed_without_bump_blocks_release(self):
        self.release("finalize")
        self.git("commit", "-qam", "Release 0.1.0")
        self.git("tag", "v0.1.0")
        self.release("next", "0.1.1")
        (self.tmp / "packages/mintmenu/menu.py").write_text("changed")
        self.git("add", ".")
        self.git("commit", "-qam", "menu work")
        self.release("finalize")
        self.git("commit", "-qam", "Release 0.1.1")
        self.git("tag", "v0.1.1")
        check = self.release("check", "v0.1.1")
        self.assertNotEqual(check.returncode, 0)
        self.assertIn("bump the +ageless<N>", check.stderr)

    @unittest.skipUnless(__import__("shutil").which("dpkg"), "needs dpkg")
    def test_debian_ordering(self):
        def lt(a, b):
            return self.sp.run(["dpkg", "--compare-versions", a, "lt", b]).returncode == 0
        chain = ["0.1.0~1.gaaaaaaa", "0.1.0~14.g0000000", "0.1.0~14.g0000000.dirty20261008.120000",
                 "0.1.0~15.gfffffff", "0.1.0", "0.1.1~1.g1234567", "0.1.1"]
        for a, b in zip(chain, chain[1:]):
            self.assertTrue(lt(a, b), f"{a} should sort before {b}")
        self.assertTrue(lt("6.2.3", "6.2.3+ageless1~3.gabc1234"))  # replaces Mint's mintmenu
        self.assertTrue(lt("6.2.3+ageless1~3.gabc1234", "6.2.3+ageless1"))


def control_packages(source: str) -> set[str]:
    text = (ROOT / "packages" / source / "debian/control").read_text()
    return set(re.findall(r"^Package: (\S+)", text, re.M))


class LawCatalogTests(unittest.TestCase):
    def setUp(self):
        import tomllib
        with open(ROOT / "packages/ageless/sysinfo/laws.toml", "rb") as f:
            self.laws = tomllib.load(f)["law"]
        sys.path.insert(0, str(ROOT / "packages/ageless/sysinfo"))
        import ageless_sysinfo
        self.mod = ageless_sysinfo

    def test_entries_are_complete_and_dated(self):
        ids = set()
        for law in self.laws:
            for key in ("id", "title", "jurisdiction", "status", "checked", "asks",
                        "summary", "capability", "sources", "flagrant", "flagrant_text"):
                self.assertTrue(law.get(key) is not None, f"{law.get('id')}: missing {key}")
            self.assertRegex(law["checked"], r"^\d{4}-\d{2}-\d{2}$")
            self.assertTrue(law["sources"] and all(u.startswith("https://") for u in law["sources"]))
            self.assertNotIn(law["id"], ids)
            ids.add(law["id"])

    def test_flagrant_packages_exist(self):
        ours = control_packages("ageless")
        for law in self.laws:
            for key in ("flagrant", "flagrant_off"):
                if law.get(key):
                    self.assertIn(law[key], ours, f"{law['id']}: {key} {law[key]} not in packages/ageless")

    def test_loader_and_commands(self):
        laws = {l.id: l for l in self.mod.load_laws(ROOT / "packages/ageless/sysinfo/laws.toml")}
        self.assertEqual(laws["vpn"].command(True)[-2:], ["install", "ageless-flagrant-vpn"])
        self.assertEqual(laws["vpn"].command(False)[-2:], ["remove", "ageless-flagrant-vpn"])
        # Conflicting stances: switching off installs the other one.
        self.assertEqual(laws["age-signal"].command(False)[-2:], ["install", "ageless-standard"])
        self.assertFalse(laws["app-store"].switchable)


class AgelessDeviceTests(unittest.TestCase):
    def setUp(self):
        import importlib.machinery, importlib.util, tempfile
        path = ROOT / "packages/ageless-device/bin/ageless-device"
        loader = importlib.machinery.SourceFileLoader("ageless_device", str(path))
        spec = importlib.util.spec_from_loader("ageless_device", loader)
        self.dev = importlib.util.module_from_spec(spec)
        loader.exec_module(self.dev)
        self.tmp = Path(tempfile.mkdtemp())

    def fake(self, name, vid, pid, serial, tty=None):
        d = self.tmp / name
        d.mkdir()
        (d / "idVendor").write_text(vid + "\n")
        (d / "idProduct").write_text(pid + "\n")
        (d / "serial").write_text(serial + "\n")
        (d / "product").write_text("Board\n")
        if tty:
            (d / f"{name}:1.0" / "tty" / tty).mkdir(parents=True)

    def test_find_boards_by_mode(self):
        self.fake("1-1", "2e8a", "0005", "E66038B713", tty="ttyACM0")
        self.fake("1-2", "2e8a", "000f", "ABC")
        self.fake("1-3", "046d", "c52b", "mouse")
        boards = {b.serial: b for b in self.dev.find_boards(self.tmp)}
        self.assertEqual(set(boards), {"E66038B713", "ABC"})
        self.assertEqual(boards["E66038B713"].mode, "micropython")
        self.assertEqual(boards["E66038B713"].ttys, ["ttyACM0"])
        self.assertEqual(boards["ABC"].mode, "bootsel-rp2350")
        self.assertIsNone(boards["ABC"].port)

    def test_udev_rules_cover_every_mode(self):
        rules = (ROOT / "packages/ageless-device/udev/70-ageless-device.rules").read_text()
        for pid in self.dev.MODES:
            self.assertIn(pid, rules)


class MintmenuForkTests(unittest.TestCase):
    def test_desktop_depends_on_fork_version(self):
        changelog = (ROOT / "packages/mintmenu/debian/changelog").read_text().splitlines()[0]
        fork_version = re.search(r"\(([^)]+)\)", changelog).group(1)
        control = (ROOT / "packages/ageless/debian/control").read_text()
        # The trailing ~ lets development builds (6.2.3+ageless1~N.g...) satisfy it.
        self.assertIn(f"mintmenu (>= {fork_version}~)", control)

    def test_no_mint_only_commands_without_fallback(self):
        base = ROOT / "packages/mintmenu/usr/lib/linuxmint/mintMenu/plugins"
        easy = (base / "easybuttons.py").read_text()
        self.assertIn("apt-helper.py", easy)
        apps = (base / "applications.py").read_text()
        self.assertIn("apt-helper.py", apps)
        self.assertNotIn("self.search_mint_users)", apps)


class SmokeMarkerTests(unittest.TestCase):
    def test_markers_match_through_systemd_colour_codes(self):
        sys.path.insert(0, str(ROOT / "tests"))
        import smoke
        line = "\x1b[0;1;39mWelcome to \x1b[0m\x1b[1mAgeless Linux 0.1 (Timeless)\x1b[0m\x1b[0;1;39m!\x1b[0m"
        self.assertIn(smoke.LIVE_MARKERS[0], smoke.ANSI.sub("", line))


if __name__ == "__main__":
    unittest.main()
