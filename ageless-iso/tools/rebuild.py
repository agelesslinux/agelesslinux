#!/usr/bin/env python3
"""tools/rebuild.py — rebuild upstream packages listed in upstream/rebuilds.toml.

Runs inside the build container (or any Debian trixie root shell):

    tools/rebuild.py --out /out/rebuilds                 # every enabled entry
    tools/rebuild.py --out /out/rebuilds mint-themes     # just one
    tools/rebuild.py --list

From the host, through build.py's container:
    docker run --rm -v $PWD:/src:ro -v $PWD/out:/out localhost/ageless-build:trixie \\
        python3 /src/tools/rebuild.py --out /out/rebuilds mint-themes
"""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
import tempfile
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "upstream" / "rebuilds.toml"
SUFFIX = "~ageless0.1"


def sh(cmd: list[str], cwd: Path | None = None) -> None:
    print("+ " + " ".join(cmd), flush=True)
    subprocess.run(cmd, cwd=cwd, check=True)


def install_build_deps(srcdir: Path) -> None:
    sh(["apt-get", "update", "-qq"])
    sh(["apt-get", "build-dep", "-y", "--no-install-recommends", "./"], cwd=srcdir)


def build_git(entry: dict, work: Path) -> Path:
    srcdir = work / entry["name"]
    sh(["git", "clone", "--depth", "50", "--branch", entry["ref"], entry["url"], str(srcdir)])
    if "commit" in entry:
        sh(["git", "checkout", "--quiet", entry["commit"]], cwd=srcdir)
    return srcdir


def build_backport(entry: dict, work: Path) -> Path:
    suite = entry["from_suite"]
    sources = Path(f"/etc/apt/sources.list.d/ageless-rebuild-{suite}.sources")
    sources.write_text(f"Types: deb-src\nURIs: http://deb.debian.org/debian\nSuites: {suite}\n"
                       "Components: main\nSigned-By: /usr/share/keyrings/debian-archive-keyring.gpg\n")
    sh(["apt-get", "update", "-qq"])
    sh(["apt-get", "source", "--only-source", f"{entry['name']}/{suite}"], cwd=work)
    srcdir = next(p for p in work.iterdir() if p.is_dir() and p.name.startswith(entry["name"] + "-"))
    sh(["dch", "--local", SUFFIX, "--distribution", "timeless", "--force-distribution",
        f"Rebuild for Ageless Linux (Debian trixie) from {suite}."], cwd=srcdir)
    return srcdir


def rebuild(entry: dict, out: Path) -> None:
    with tempfile.TemporaryDirectory() as tmp:
        work = Path(tmp)
        srcdir = (build_git if entry["kind"] == "git" else build_backport)(entry, work)
        install_build_deps(srcdir)
        sh(["dpkg-buildpackage", "-b", "-us", "-uc"], cwd=srcdir)
        out.mkdir(parents=True, exist_ok=True)
        for deb in srcdir.parent.glob("*.deb"):
            shutil.move(deb, out / deb.name)
            print(f"I: {out / deb.name}")


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("names", nargs="*", help="entries to build (default: all enabled)")
    p.add_argument("--out", type=Path, default=Path("/out/rebuilds"))
    p.add_argument("--list", action="store_true")
    p.add_argument("--skip-existing", action="store_true",
                   help="skip entries that already have a <name>_*.deb in --out (build cache)")
    args = p.parse_args()

    entries = tomllib.loads(MANIFEST.read_text())["package"]
    if args.list:
        for e in entries:
            state = "enabled" if e.get("enabled", True) else "planned"
            print(f"{e['name']:16} {e['kind']:9} {state:8} {e.get('why', '')}")
        return 0

    chosen = [e for e in entries if (e["name"] in args.names if args.names else e.get("enabled", True))]
    missing = set(args.names) - {e["name"] for e in entries}
    if missing:
        return f"not in {MANIFEST.name}: {', '.join(sorted(missing))}"
    for entry in chosen:
        if args.skip_existing and list(args.out.glob(f"{entry['name']}_*.deb")):
            print(f"== {entry['name']}: cached in {args.out}, skipping", flush=True)
            continue
        print(f"== {entry['name']} ({entry['kind']})", flush=True)
        rebuild(entry, args.out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
