#!/usr/bin/env python3
"""Turn a directory of .debs into a Debian archive that apt can upgrade from.

    make-repo.py build <debs-dir> <repo-dir>      dists/ + pool/, unsigned
    make-repo.py sign <repo-dir> --key <keyid>    write InRelease + Release.gpg
    make-repo.py serve <debs-dir> [--port 8642]   development: serve a flat repo

`build` needs apt-ftparchive (apt-utils) and dpkg-deb; `sign` needs gpg with
the archive key imported; `serve` needs only Python. The layout is the
standard one, so an installed system uses:

    Types: deb
    URIs: <AGELESS_ARCHIVE_URL>
    Suites: <AGELESS_CODENAME>
    Components: main
    Signed-By: /usr/share/keyrings/ageless-archive-keyring.gpg

See docs/upgrades.md.
"""

import argparse
import functools
import http.server
import shlex
import shutil
import socket
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ARCHES = ("amd64", "arm64")


def release_env() -> dict[str, str]:
    env = {}
    for line in (ROOT / "common/release.env").read_text().splitlines():
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            key, value = line.split("=", 1)
            env[key.strip()] = shlex.split(value)[0] if value.strip() else ""
    return env


def deb_field(deb: Path, field: str) -> str:
    return subprocess.run(["dpkg-deb", "-f", str(deb), field], check=True,
                          capture_output=True, text=True).stdout.strip()


def pool_path(deb: Path) -> Path:
    source = deb_field(deb, "Source").split(" ")[0] or deb_field(deb, "Package")
    prefix = source[:4] if source.startswith("lib") else source[0]
    return Path("pool/main") / prefix / source / deb.name


def build(debs_dir: Path, repo: Path) -> int:
    env = release_env()
    suite = env["AGELESS_CODENAME"]
    debs = sorted(debs_dir.glob("*.deb"))
    if not debs:
        sys.exit(f"error: no .deb files in {debs_dir}")
    if repo.exists():
        shutil.rmtree(repo)
    for deb in debs:
        target = repo / pool_path(deb)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(deb, target)

    dist = repo / "dists" / suite
    for arch in ARCHES:
        binary = dist / "main" / f"binary-{arch}"
        binary.mkdir(parents=True)
        # Architecture: all packages appear in every binary-<arch> index.
        packages = subprocess.run(["apt-ftparchive", "--arch", arch, "packages", "pool"],
                                  cwd=repo, check=True, capture_output=True, text=True).stdout
        (binary / "Packages").write_text(packages)
        subprocess.run(["gzip", "-9nkf", "Packages"], cwd=binary, check=True)

    release = subprocess.run([
        "apt-ftparchive",
        "-o", f"APT::FTPArchive::Release::Origin={env['AGELESS_NAME']}",
        "-o", f"APT::FTPArchive::Release::Label={env['AGELESS_NAME']}",
        "-o", f"APT::FTPArchive::Release::Suite={suite}",
        "-o", f"APT::FTPArchive::Release::Codename={suite}",
        "-o", f"APT::FTPArchive::Release::Version={env['AGELESS_VERSION']}",
        "-o", f"APT::FTPArchive::Release::Architectures={' '.join(ARCHES)} all",
        "-o", "APT::FTPArchive::Release::Components=main",
        "-o", f"APT::FTPArchive::Release::Description={env['AGELESS_NAME']} "
              f"{env['AGELESS_VERSION']} on Debian {env['DEBIAN_SUITE']}",
        "release", ".",
    ], cwd=dist, check=True, capture_output=True, text=True).stdout
    (dist / "Release").write_text(release)
    print(f"I: {len(debs)} packages -> {repo} (suite {suite}, unsigned)")
    return 0


def sign(repo: Path, key: str) -> int:
    suite = release_env()["AGELESS_CODENAME"]
    dist = repo / "dists" / suite
    gpg = ["gpg", "--batch", "--yes", "--pinentry-mode", "loopback", "--local-user", key, "--digest-algo", "SHA512"]
    subprocess.run(gpg + ["--clearsign", "-o", "InRelease", "Release"], cwd=dist, check=True)
    subprocess.run(gpg + ["--armor", "--detach-sign", "-o", "Release.gpg", "Release"], cwd=dist, check=True)
    print(f"I: signed {dist}/InRelease with {key}")
    return 0


def lan_address() -> str:
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.connect(("192.0.2.1", 9))  # TEST-NET; no packet is sent
            return s.getsockname()[0]
    except OSError:
        return socket.gethostname()


def serve(debs_dir: Path, port: int) -> int:
    if not (debs_dir / "Packages").exists():
        sys.exit(f"error: {debs_dir}/Packages missing; run ./build.py --variant packages first")
    host = lan_address()
    print(f"""Serving {debs_dir} as a flat apt repository on port {port}.

On the Ageless Linux machine you are iterating on (once):

    echo 'deb [trusted=yes] http://{host}:{port}/ ./' | sudo tee /etc/apt/sources.list.d/ageless-dev.list

Then, after each ./build.py --variant packages here:

    sudo apt update && sudo apt full-upgrade

[trusted=yes] skips signature checks: use this only on a network you trust,
and remove the file when you are done. Ctrl-C stops the server.
""", flush=True)
    handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=str(debs_dir))
    with http.server.ThreadingHTTPServer(("", port), handler) as httpd:
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            pass
    return 0


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = p.add_subparsers(dest="cmd", required=True)
    b = sub.add_parser("build", help="build dists/ + pool/ from a directory of .debs")
    b.add_argument("debs", type=Path)
    b.add_argument("repo", type=Path)
    s = sub.add_parser("sign", help="sign dists/<suite>/Release")
    s.add_argument("repo", type=Path)
    s.add_argument("--key", required=True, help="gpg key id or fingerprint")
    v = sub.add_parser("serve", help="serve a flat development repo over HTTP")
    v.add_argument("debs", type=Path, nargs="?", default=ROOT / "out/debs")
    v.add_argument("--port", type=int, default=8642)
    args = p.parse_args(argv)
    if args.cmd == "build":
        return build(args.debs.resolve(), args.repo.resolve())
    if args.cmd == "sign":
        return sign(args.repo.resolve(), args.key)
    return serve(args.debs.resolve(), args.port)


if __name__ == "__main__":
    sys.exit(main())
