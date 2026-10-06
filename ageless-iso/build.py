#!/usr/bin/env python3
"""build.py — the one entrypoint for building Ageless Linux.

Builds the ageless-* Debian packages and, from them, a bootable ISO inside
the pinned build container (containers/Containerfile.build). The host needs
only Python 3 and Podman or Docker.

    ./build.py --variant live --arch amd64
    ./build.py --variant live --flagrant --output /tmp/isos
    ./build.py --variant netinst
    ./build.py --variant packages            # just the .debs + Packages index
    ./build.py --variant live --dry-run      # print what would run

Stdlib only, on purpose: forks of this repo should not need a virtualenv.
"""

from __future__ import annotations

import argparse
import os
import platform
import shlex
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
RELEASE_ENV = ROOT / "common" / "release.env"
CONTAINERFILE = ROOT / "containers" / "Containerfile.build"
IMAGE = "localhost/ageless-build:trixie"
VARIANTS = ("live", "netinst", "packages")
ARCHES = ("amd64", "arm64")


def read_release_env(path: Path = RELEASE_ENV) -> dict[str, str]:
    """Parse the KEY="value" lines of release.env (no shell evaluation)."""
    env: dict[str, str] = {}
    for raw in path.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        env[key.strip()] = shlex.split(value)[0] if value.strip() else ""
    return env


def host_arch() -> str:
    machine = platform.machine().lower()
    return {"x86_64": "amd64", "amd64": "amd64", "aarch64": "arm64", "arm64": "arm64"}.get(machine, machine)


def source_date_epoch() -> str:
    """Commit timestamp for reproducible output; falls back to now outside git."""
    if "SOURCE_DATE_EPOCH" in os.environ:
        return os.environ["SOURCE_DATE_EPOCH"]
    try:
        out = subprocess.run(
            ["git", "-C", str(ROOT), "log", "-1", "--format=%ct"],
            check=True, capture_output=True, text=True,
        )
        return out.stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        import time
        return str(int(time.time()))


def pick_runtime(requested: str) -> str:
    if requested != "auto":
        return requested
    for candidate in ("podman", "docker"):
        if shutil.which(candidate):
            return candidate
    sys.exit("error: neither podman nor docker found; install one or pass --runtime none on a Debian host")


def run(cmd: list[str], dry_run: bool) -> None:
    print("+ " + shlex.join(cmd), flush=True)
    if not dry_run:
        subprocess.run(cmd, check=True)


def inner_script(variant: str, rebuilds: bool = True) -> str:
    """The shell run inside the container: build packages, then the variant."""
    steps = ["set -euo pipefail"]
    if rebuilds:
        # Mint packages Debian lacks (upstream/rebuilds.toml), cached across runs.
        steps.append("python3 tools/rebuild.py --skip-existing --out /out/debs")
    # Our own packages; this also writes the Packages index over the whole dir.
    steps.append("tools/build-packages.sh /out/debs")
    if variant == "live":
        steps.append("variant-live/build-inner.sh")
    elif variant == "netinst":
        steps.append("variant-netinst/build-inner.sh")
    return " && ".join(steps)


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    release = read_release_env()
    p = argparse.ArgumentParser(description="Build Ageless Linux packages and ISOs.")
    p.add_argument("--variant", choices=VARIANTS, default="live")
    p.add_argument("--arch", choices=ARCHES, default=host_arch() if host_arch() in ARCHES else "amd64")
    p.add_argument("--flagrant", action="store_true",
                   help="ship ageless-refusal (flagrant mode) instead of ageless-compliance")
    p.add_argument("--output", type=Path, default=ROOT / "out", help="output directory (default: ./out)")
    p.add_argument("--snapshot", default=release.get("DEBIAN_SNAPSHOT", "none"),
                   help="snapshot.debian.org timestamp, or 'none' for deb.debian.org "
                        "(default: the pin in common/release.env)")
    p.add_argument("--runtime", choices=("auto", "podman", "docker", "none"), default="auto",
                   help="container runtime; 'none' runs directly on a Debian trixie host as root")
    p.add_argument("--base-image", default=None,
                   help="override the Containerfile base image (e.g. a registry mirror)")
    p.add_argument("--rebuild-image", action="store_true", help="rebuild the build container first")
    p.add_argument("--no-rebuilds", action="store_true",
                   help="skip the upstream Mint rebuilds (upstream/rebuilds.toml); the desktop then "
                        "lacks mintmenu and mint-themes")
    p.add_argument("--dry-run", action="store_true", help="print the commands instead of running them")
    args = p.parse_args(argv)
    if args.arch != host_arch() and args.variant != "packages":
        print(f"warning: building {args.arch} on a {host_arch()} host needs qemu-user-static/binfmt "
              "and is 4-8x slower; CI uses native runners instead", file=sys.stderr)
    return args


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    release = read_release_env()
    output = args.output.resolve()
    if not args.dry_run:
        output.mkdir(parents=True, exist_ok=True)

    env = {
        "ARCH": args.arch,
        "STANCE": "flagrant" if args.flagrant else "standard",
        "SNAPSHOT": args.snapshot,
        "SOURCE_DATE_EPOCH": source_date_epoch(),
        "DEBS_DIR": "/out/debs",
        "WORK_DIR": f"/build/{args.variant}-{args.arch}",
        "OUT_DIR": "/out",
    }
    print(f"Ageless Linux {release['AGELESS_VERSION']} ({release['AGELESS_CODENAME']}) on Debian "
          f"{release['DEBIAN_SUITE']}: variant={args.variant} arch={args.arch} stance={env['STANCE']} "
          f"snapshot={args.snapshot} -> {output}")

    runtime = pick_runtime(args.runtime)
    script = inner_script(args.variant, rebuilds=not args.no_rebuilds)

    if runtime == "none":
        # Direct mode: map container paths onto the host.
        env.update(DEBS_DIR=str(output / "debs"), OUT_DIR=str(output),
                   WORK_DIR=str(output / "work" / f"{args.variant}-{args.arch}"))
        script = script.replace("/out/debs", str(output / "debs"))
        cmd = ["env", *[f"{k}={v}" for k, v in env.items()], "bash", "-c", f"cd {shlex.quote(str(ROOT))} && {script}"]
        run(cmd, args.dry_run)
        return 0

    needs_image = args.rebuild_image or args.dry_run or subprocess.run(
        [runtime, "image", "inspect", IMAGE], capture_output=True).returncode != 0
    if needs_image:
        build = [runtime, "build", "-t", IMAGE, "-f", str(CONTAINERFILE)]
        if args.base_image:
            build += ["--build-arg", f"BASE_IMAGE={args.base_image}"]
        run(build + [str(CONTAINERFILE.parent)], args.dry_run)

    cmd = [runtime, "run", "--rm"]
    if args.variant != "packages":
        # live-build and simple-cdd mount /proc, /sys and loop devices in a chroot.
        cmd.append("--privileged")
    cmd += ["-v", f"{ROOT}:/src:ro", "-v", f"{output}:/out"]
    for key, value in env.items():
        cmd += ["-e", f"{key}={value}"]
    # Work on a copy so build artefacts never land in the read-only checkout.
    cmd += [IMAGE, "bash", "-c", f"cp -a /src /build-src && cd /build-src && {script}"]
    run(cmd, args.dry_run)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except subprocess.CalledProcessError as exc:
        sys.exit(f"error: command failed with exit status {exc.returncode}")
