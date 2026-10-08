#!/usr/bin/env python3
"""Ageless Linux versioning: the Debian pattern, driven by git tags.

common/release.env holds AGELESS_VERSION, the version being worked *toward*.
Every Ageless-native package (packages/*, except forks such as mintmenu,
whose versions carry +ageless<N>) has that same version at the top of its
debian/changelog, marked UNRELEASED while it is in development.

  build                          package version          distro version
  clean checkout on tag v0.1.0   0.1.0                    0.1.0
  14 commits past v0.0.9 (or     0.1.0~14.gabc1234        0.1.0~14.gabc1234
    since the first commit)
  same, uncommitted changes      0.1.0~14.gabc1234.dirty20261008.153012

"~" sorts before the empty string, so every development build of 0.1.0 is
older than the 0.1.0 release, and the release is the upgrade that lands
last. The release cycle:

  tools/release.py finalize      UNRELEASED -> timeless in every changelog
  git commit -am "Release 0.1.0" && git tag v0.1.0 && git push --tags
  tools/release.py next 0.1.1    release.env + new UNRELEASED changelog entries
  git commit -am "Start 0.1.1"

  tools/release.py check v0.1.0  what CI runs on a tag
  tools/release.py version       print the version this checkout builds
"""

import argparse
import email.utils
import re
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RELEASE_ENV = ROOT / "common/release.env"
PACKAGES = ROOT / "packages"
MAINTAINER = "Ageless Linux <archive@agelesslinux.org>"
HEADER = re.compile(r"^(?P<source>\S+) \((?P<version>[^)]+)\) (?P<dist>[^;]+);(?P<rest>.*)$")


class VersionError(Exception):
    pass


# ---------------------------------------------------------------- helpers

def git(*args: str, check: bool = True) -> str:
    res = subprocess.run(["git", "-C", str(ROOT), *args], capture_output=True, text=True)
    if check and res.returncode != 0:
        raise VersionError(f"git {' '.join(args)}: {res.stderr.strip()}")
    return res.stdout.strip() if res.returncode == 0 else ""


def base_version() -> str:
    for line in RELEASE_ENV.read_text().splitlines():
        m = re.match(r'\s*AGELESS_VERSION="?([^"\s]+)"?', line)
        if m:
            return m.group(1)
    raise VersionError(f"AGELESS_VERSION missing from {RELEASE_ENV}")


def changelog_head(changelog: Path) -> dict[str, str]:
    m = HEADER.match(changelog.read_text().splitlines()[0])
    if not m:
        raise VersionError(f"{changelog}: unparseable first line")
    return m.groupdict()


def changelogs() -> list[Path]:
    return sorted(PACKAGES.glob("*/debian/changelog"))


def is_fork(changelog: Path) -> bool:
    """Forks keep the upstream version plus +ageless<N>; the rest track AGELESS_VERSION."""
    return "+ageless" in changelog_head(changelog)["version"]


# ---------------------------------------------------------------- versions

@dataclass
class BuildVersion:
    base: str        # AGELESS_VERSION, e.g. 0.1.0
    suffix: str      # "" for a release, else ~14.gabc1234[.dirty...]
    commits: int     # commits since the last v* tag (or since the first commit)
    sha: str
    dirty: bool

    @property
    def release(self) -> bool:
        return self.suffix == ""

    @property
    def full(self) -> str:
        return self.base + self.suffix


def build_version(now: float | None = None) -> BuildVersion:
    base = base_version()
    sha = git("rev-parse", "--short=7", "HEAD", check=False) or "0000000"
    dirty = bool(git("status", "--porcelain", "--", ".", check=False))
    described = git("describe", "--tags", "--long", "--abbrev=7", "--match", "v[0-9]*", "HEAD", check=False)
    if described:
        tag, commits, _ = described.rsplit("-", 2)
        commits = int(commits)
    else:
        tag, commits = None, int(git("rev-list", "--count", "HEAD", check=False) or 0)

    at_release_tag = tag == f"v{base}" and commits == 0
    if at_release_tag and not dirty:
        return BuildVersion(base, "", 0, sha, False)
    if git("rev-parse", "-q", "--verify", f"refs/tags/v{base}", check=False):
        # Development builds of an already-released version would sort below it.
        raise VersionError(
            f"v{base} is already tagged, so a development build of {base} would be older than the "
            f"release. Start the next version first: tools/release.py next <version>")
    suffix = f"~{commits}.g{sha}"
    if dirty:
        stamp = time.strftime("%Y%m%d.%H%M%S", time.gmtime(time.time() if now is None else now))
        suffix += f".dirty{stamp}"
    return BuildVersion(base, suffix, commits, sha, dirty)


# ---------------------------------------------------------------- commands

def check(tag: str) -> list[str]:
    """Problems that block releasing `tag` (empty list = releasable)."""
    problems = []
    base = base_version()
    if tag != f"v{base}":
        problems.append(f"tag {tag} does not match AGELESS_VERSION={base} (expected v{base})")
    previous = git("describe", "--tags", "--abbrev=0", "--match", "v[0-9]*", f"{tag}^", check=False) \
        if git("rev-parse", "-q", "--verify", f"{tag}^", check=False) else ""
    for cl in changelogs():
        head = changelog_head(cl)
        name = cl.parent.parent.name
        if head["dist"].strip() == "UNRELEASED":
            problems.append(f"{name}: changelog is still UNRELEASED (run tools/release.py finalize)")
        if not is_fork(cl) and head["version"] != base:
            problems.append(f"{name}: version {head['version']} != AGELESS_VERSION {base}")
        if previous and is_fork(cl):
            rel = cl.relative_to(git("rev-parse", "--show-toplevel"))
            changed = subprocess.run(["git", "-C", str(ROOT), "diff", "--quiet", previous, tag, "--",
                                      str(cl.parent.parent)]).returncode != 0
            old = git("show", f"{previous}:{rel}", check=False).splitlines()[:1]
            if changed and old and HEADER.match(old[0]) and HEADER.match(old[0])["version"] == head["version"]:
                problems.append(f"{name}: changed since {previous} but still version {head['version']}; "
                                f"bump the +ageless<N> number")
    return problems


def rewrite_head(cl: Path, version: str | None = None, dist: str | None = None) -> None:
    lines = cl.read_text().splitlines(keepends=True)
    m = HEADER.match(lines[0].rstrip("\n"))
    lines[0] = (f"{m['source']} ({version or m['version']}) {dist or m['dist']};{m['rest']}\n")
    cl.write_text("".join(lines))


def finalize() -> int:
    stamp = email.utils.formatdate(usegmt=False, localtime=False).replace("-0000", "+0000")
    codename = re.search(r'AGELESS_CODENAME="?(\w+)', RELEASE_ENV.read_text()).group(1)
    for cl in changelogs():
        if changelog_head(cl)["dist"].strip() != "UNRELEASED":
            continue
        rewrite_head(cl, dist=codename)
        text = cl.read_text()
        # Trailer of the first entry: " -- Name <mail>  Date"
        text = re.sub(r"^( -- .+?>  ).*$", lambda m: m.group(1) + stamp, text, count=1, flags=re.M)
        cl.write_text(text)
        print(f"{cl.parent.parent.name}: {changelog_head(cl)['version']} -> {codename}")
    return 0


def next_version(version: str) -> int:
    if not re.fullmatch(r"\d+(\.\d+)*", version):
        raise VersionError(f"{version!r} is not a plain version like 0.1.1")
    text = RELEASE_ENV.read_text()
    RELEASE_ENV.write_text(re.sub(r'(AGELESS_VERSION=)"?[^"\s]+"?', rf'\1"{version}"', text, count=1))
    stamp = email.utils.formatdate(usegmt=False).replace("-0000", "+0000")
    for cl in changelogs():
        if is_fork(cl):
            continue
        source = changelog_head(cl)["source"]
        entry = (f"{source} ({version}) UNRELEASED; urgency=medium\n\n"
                 f"  * Development of {version}.\n\n -- {MAINTAINER}  {stamp}\n\n")
        cl.write_text(entry + cl.read_text())
        print(f"{source}: {version} UNRELEASED")
    print(f"common/release.env: AGELESS_VERSION={version}")
    return 0


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0],
                                formatter_class=argparse.RawDescriptionHelpFormatter,
                                epilog="\n".join(__doc__.splitlines()[1:]))
    sub = p.add_subparsers(dest="cmd", required=True)
    sub.add_parser("version", help="print the version this checkout builds")
    c = sub.add_parser("check", help="verify a tag is releasable (CI)")
    c.add_argument("tag")
    sub.add_parser("finalize", help="mark UNRELEASED changelogs as released")
    n = sub.add_parser("next", help="start the next version")
    n.add_argument("version")
    args = p.parse_args(argv)
    try:
        if args.cmd == "version":
            print(build_version().full)
            return 0
        if args.cmd == "check":
            problems = check(args.tag)
            for problem in problems:
                print(f"error: {problem}", file=sys.stderr)
            if not problems:
                print(f"{args.tag}: releasable")
            return 1 if problems else 0
        if args.cmd == "finalize":
            return finalize()
        return next_version(args.version)
    except VersionError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
