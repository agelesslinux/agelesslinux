"""Shared code for Ageless System Info and the ageless-flagrant command.

Reads the law catalog (laws.toml), works out which flagrant packages are
installed, and switches them on or off through apt.
"""

import os
import platform
import shutil
import subprocess
import tomllib
from dataclasses import dataclass, field
from pathlib import Path

CATALOG = Path(os.environ.get("AGELESS_LAWS", "/usr/share/ageless/laws.toml"))
APT_ENV = {"DEBIAN_FRONTEND": "noninteractive", "LC_ALL": "C.UTF-8",
           "PATH": "/usr/sbin:/usr/bin:/sbin:/bin"}


@dataclass
class Law:
    id: str
    title: str
    jurisdiction: str
    status: str
    checked: str
    asks: str
    summary: str
    capability: str
    flagrant: str = ""
    flagrant_off: str = ""
    flagrant_text: str = ""
    sources: list[str] = field(default_factory=list)

    @property
    def switchable(self) -> bool:
        return bool(self.flagrant)

    def enabled(self) -> bool:
        return bool(self.flagrant) and package_installed(self.flagrant)

    def command(self, on: bool) -> list[str]:
        """The apt-get command (run as root) that switches flagrant mode on or off."""
        if on:
            return ["apt-get", "-y", "-q", "install", self.flagrant]
        if self.flagrant_off:
            # Two conflicting stances: installing the other one removes this one.
            return ["apt-get", "-y", "-q", "install", self.flagrant_off]
        return ["apt-get", "-y", "-q", "remove", self.flagrant]


def load_laws(path: Path = CATALOG) -> list[Law]:
    with open(path, "rb") as f:
        data = tomllib.load(f)
    return [Law(**{k.replace("-", "_"): v for k, v in entry.items()}) for entry in data["law"]]


def package_installed(name: str) -> bool:
    res = subprocess.run(["dpkg-query", "-W", "-f", "${db:Status-Status}", name],
                         capture_output=True, text=True)
    return res.returncode == 0 and res.stdout.strip() == "installed"


def package_available(name: str) -> bool:
    res = subprocess.run(["apt-cache", "policy", name], capture_output=True, text=True,
                         env={"LC_ALL": "C", "PATH": APT_ENV["PATH"]})
    return "Candidate:" in res.stdout and "Candidate: (none)" not in res.stdout


def run_as_root(cmd: list[str]) -> subprocess.CompletedProcess:
    """Run an apt-get command as root: directly if we are root, else via pkexec."""
    if os.geteuid() != 0:
        cmd = ["pkexec", "/usr/bin/" + cmd[0], *cmd[1:]]
    return subprocess.run(cmd, capture_output=True, text=True, env=APT_ENV)


def os_release() -> dict[str, str]:
    fields = {}
    for path in ("/etc/os-release", "/usr/lib/os-release"):
        try:
            with open(path) as f:
                for line in f:
                    key, sep, value = line.strip().partition("=")
                    if sep:
                        fields[key] = value.strip('"')
            break
        except OSError:
            continue
    return fields


def stance() -> str:
    if os.path.exists("/etc/ageless/REFUSAL"):
        return "Flagrant (AB 1043 refusal)"
    if os.path.exists("/etc/ageless/ab1043-compliance.txt"):
        return "Standard"
    return "Not installed"


def _meminfo_gib() -> str:
    try:
        with open("/proc/meminfo") as f:
            kib = int(next(l for l in f if l.startswith("MemTotal:")).split()[1])
        return f"{kib / 1024 / 1024:.1f} GiB"
    except (OSError, StopIteration, ValueError):
        return "unknown"


def _cpu_model() -> str:
    try:
        with open("/proc/cpuinfo") as f:
            for line in f:
                if line.lower().startswith(("model name", "hardware", "cpu model")):
                    return line.split(":", 1)[1].strip()
    except OSError:
        pass
    return platform.processor() or platform.machine()


def system_facts() -> list[tuple[str, str]]:
    rel = os_release()
    total, _used, free = shutil.disk_usage("/")
    debian = rel.get("DEBIAN_CODENAME", "")
    return [
        ("Operating system", rel.get("PRETTY_NAME", "unknown")),
        ("Based on", f"Debian {debian}" if debian else rel.get("ID_LIKE", "")),
        ("Ageless mode", stance()),
        ("Kernel", platform.release()),
        ("Architecture", platform.machine()),
        ("Processor", _cpu_model()),
        ("Memory", _meminfo_gib()),
        ("Disk (/)", f"{free / 1e9:.0f} GB free of {total / 1e9:.0f} GB"),
        ("Desktop", os.environ.get("XDG_CURRENT_DESKTOP", "unknown")),
        ("Your age", "Not collected. Ageless Linux does not know it and will not ask."),
    ]
