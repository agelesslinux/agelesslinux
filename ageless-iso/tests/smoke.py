#!/usr/bin/env python3
"""tests/smoke.py — boot an Ageless Linux ISO in QEMU and check it comes up.

Two checks, both run by default:

  serial      Extract the live kernel + initrd from the ISO and boot them
              with console=ttyS0 against the ISO as a CD-ROM. Passes when the
              serial log shows systemd's "Welcome to Ageless Linux" banner
              (proof the squashfs, live-boot and our os-release all work) and
              then the display manager starting.
  firmware    Boot the ISO the way a user does, through its own bootloader
              (OVMF UEFI on amd64/arm64, SeaBIOS too on amd64), and save
              screenshots from the QEMU monitor. This exercises GRUB/isolinux
              on the medium; the PNGs are uploaded as CI artifacts for a human
              (or a later OCR step) to eyeball.

Netinst ISOs boot debian-installer rather than a live system, so for them
the serial check looks for d-i's banner instead.

Usage:
    tests/smoke.py out/ageless-timeless-0.1-amd64-live.iso [--arch amd64]
                   [--timeout 900] [--only serial|firmware] [--artifacts DIR]

Needs qemu-system-*, ovmf / qemu-efi-aarch64 and xorriso (all in the build
container). Uses KVM when /dev/kvm is available, TCG otherwise.
"""

from __future__ import annotations

import argparse
import os
import shutil
import socket
import subprocess
import sys
import tempfile
import time
from pathlib import Path

LIVE_MARKERS = ["Welcome to Ageless Linux", "Light Display Manager"]
NETINST_MARKERS = ["Ageless", "Debian GNU/Linux installer"]

FIRMWARE = {
    "amd64": ("/usr/share/OVMF/OVMF_CODE_4M.fd", "/usr/share/OVMF/OVMF_VARS_4M.fd"),
    "arm64": ("/usr/share/AAVMF/AAVMF_CODE.fd", "/usr/share/AAVMF/AAVMF_VARS.fd"),
}


def qemu_base(arch: str, memory: int) -> list[str]:
    kvm = os.access("/dev/kvm", os.R_OK | os.W_OK)
    if arch == "amd64":
        cmd = ["qemu-system-x86_64", "-machine", "q35" + (",accel=kvm" if kvm else ",accel=tcg")]
        cmd += ["-cpu", "host" if kvm else "max"]
    else:
        cmd = ["qemu-system-aarch64", "-machine", "virt" + (",accel=kvm" if kvm else ",accel=tcg")]
        cmd += ["-cpu", "host" if kvm else "cortex-a72"]
    cmd += ["-m", str(memory), "-smp", "2", "-nic", "user,model=virtio-net-pci"]
    if not kvm:
        print("note: /dev/kvm unavailable, using TCG emulation (slow)", flush=True)
    return cmd


def cdrom_args(arch: str, iso: Path) -> list[str]:
    if arch == "amd64":
        return ["-drive", f"file={iso},media=cdrom,readonly=on,if=ide"]
    return ["-drive", f"if=none,file={iso},id=cd,media=cdrom,readonly=on",
            "-device", "virtio-scsi-pci", "-device", "scsi-cd,drive=cd"]


def extract_boot_files(iso: Path, dest: Path) -> tuple[Path, Path, str]:
    """Pull kernel+initrd out of the ISO. Returns (kernel, initrd, cmdline)."""
    listing = subprocess.run(
        ["xorriso", "-indev", str(iso), "-find", "/", "-type", "f", "-name", "vmlinuz*"],
        capture_output=True, text=True, check=True,
    ).stdout.split()
    kernels = [k.strip("'") for k in listing if k.strip("'").startswith("/")]
    live = [k for k in kernels if k.startswith("/live/")]
    if live:
        kernel = live[0]
        initrd = kernel.replace("vmlinuz", "initrd.img")
        cmdline = "boot=live components console=ttyS0,115200 console=tty0"
    elif kernels:  # debian-installer layout: /install.amd/vmlinuz
        kernel = sorted(kernels)[0]
        initrd = str(Path(kernel).with_name("initrd.gz"))
        cmdline = "console=ttyS0,115200 priority=low"
    else:
        raise SystemExit(f"no kernel found in {iso}")
    for src in (kernel, initrd):
        subprocess.run(["xorriso", "-osirrox", "on", "-indev", str(iso),
                        "-extract", src, str(dest / Path(src).name)],
                       check=True, capture_output=True)
    return dest / Path(kernel).name, dest / Path(initrd).name, cmdline


def wait_for_markers(proc: subprocess.Popen, log: Path, markers: list[str], timeout: int) -> list[str]:
    """Stream the serial log until every marker is seen in order, or timeout."""
    found: list[str] = []
    deadline = time.monotonic() + timeout
    buf = ""
    with log.open("w", errors="replace") as fh:
        os.set_blocking(proc.stdout.fileno(), False)
        while time.monotonic() < deadline and len(found) < len(markers):
            chunk = proc.stdout.read(4096)
            if chunk:
                text = chunk.decode("utf-8", errors="replace")
                fh.write(text)
                fh.flush()
                buf += text
                while len(found) < len(markers) and markers[len(found)] in buf:
                    marker = markers[len(found)]
                    found.append(marker)
                    buf = buf[buf.index(marker) + len(marker):]
                    print(f"  [{time.monotonic() - deadline + timeout:6.0f}s] saw: {marker!r}", flush=True)
                buf = buf[-4096:]
            elif proc.poll() is not None:
                break
            else:
                time.sleep(0.2)
    return found


def serial_check(iso: Path, arch: str, timeout: int, artifacts: Path, netinst: bool) -> bool:
    print(f"== serial check ({arch})", flush=True)
    with tempfile.TemporaryDirectory() as tmp:
        kernel, initrd, cmdline = extract_boot_files(iso, Path(tmp))
        cmd = qemu_base(arch, 3072) + cdrom_args(arch, iso)
        if arch == "arm64":
            cmdline = cmdline.replace("ttyS0", "ttyAMA0")
        cmd += ["-kernel", str(kernel), "-initrd", str(initrd), "-append", cmdline,
                "-display", "none", "-serial", "stdio", "-monitor", "none"]
        markers = NETINST_MARKERS[1:] if netinst else LIVE_MARKERS
        proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL)
        try:
            found = wait_for_markers(proc, artifacts / "serial.log", markers, timeout)
        finally:
            proc.kill()
            proc.wait()
    ok = len(found) == len(markers)
    print(f"   {'PASS' if ok else 'FAIL'}: {len(found)}/{len(markers)} markers "
          f"(log: {artifacts / 'serial.log'})", flush=True)
    return ok


def monitor_command(sock_path: Path, command: str) -> None:
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
        s.connect(str(sock_path))
        s.recv(4096)  # greeting
        s.sendall(command.encode() + b"\n")
        time.sleep(0.5)


def firmware_check(iso: Path, arch: str, mode: str, timeout: int, artifacts: Path) -> bool:
    """Boot through the ISO's own bootloader and take screenshots."""
    print(f"== firmware check ({arch}, {mode})", flush=True)
    with tempfile.TemporaryDirectory() as tmp:
        tmpdir = Path(tmp)
        mon = tmpdir / "monitor.sock"
        cmd = qemu_base(arch, 3072) + cdrom_args(arch, iso)
        if mode == "uefi":
            code, vars_template = FIRMWARE[arch]
            if not Path(code).exists():
                print(f"   SKIP: firmware {code} not installed", flush=True)
                return True
            vars_copy = tmpdir / "vars.fd"
            shutil.copy(vars_template, vars_copy)
            cmd += ["-drive", f"if=pflash,format=raw,readonly=on,file={code}",
                    "-drive", f"if=pflash,format=raw,file={vars_copy}"]
        if arch == "arm64":
            cmd += ["-device", "ramfb", "-device", "qemu-xhci", "-device", "usb-kbd"]
        if arch == "amd64":
            cmd += ["-vga", "std"]
        cmd += ["-boot", "d", "-display", "none",
                "-monitor", f"unix:{mon},server,nowait", "-serial", "null"]
        proc = subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        shots = []
        try:
            for i, delay in enumerate((20, timeout // 3, timeout // 3), start=1):
                time.sleep(delay)
                if proc.poll() is not None:
                    print(f"   FAIL: QEMU exited early: {proc.stderr.read().decode()[-500:]}", flush=True)
                    return False
                shot = artifacts / f"{mode}-{i}.ppm"
                monitor_command(mon, f"screendump {shot}")
                shots.append(shot)
        finally:
            proc.kill()
            proc.wait()
    # A blank screen dump is all one colour; anything drawn means the
    # bootloader (and later the desktop) put pixels up.
    drawn = [s for s in shots if s.exists() and len(set(s.read_bytes()[-200000:])) > 4]
    print(f"   {'PASS' if drawn else 'FAIL'}: {len(drawn)}/{len(shots)} non-blank screenshots in {artifacts}",
          flush=True)
    return bool(drawn)


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("iso", type=Path)
    p.add_argument("--arch", choices=("amd64", "arm64"), default="amd64")
    p.add_argument("--timeout", type=int, default=900, help="seconds per check (default 900; TCG is slow)")
    p.add_argument("--only", choices=("serial", "firmware"))
    p.add_argument("--artifacts", type=Path, default=Path("smoke-artifacts"))
    args = p.parse_args()

    iso = args.iso.resolve()
    if not iso.is_file():
        return f"no such ISO: {iso}"
    args.artifacts.mkdir(parents=True, exist_ok=True)
    artifacts = args.artifacts.resolve()
    netinst = "netinst" in iso.name

    results = {}
    if args.only in (None, "serial"):
        results["serial"] = serial_check(iso, args.arch, args.timeout, artifacts, netinst)
    if args.only in (None, "firmware"):
        results["uefi"] = firmware_check(iso, args.arch, "uefi", min(args.timeout, 300), artifacts)
        if args.arch == "amd64":
            results["bios"] = firmware_check(iso, args.arch, "bios", min(args.timeout, 300), artifacts)

    print("== summary: " + ", ".join(f"{k}={'ok' if v else 'FAILED'}" for k, v in results.items()))
    return 0 if all(results.values()) else 1


if __name__ == "__main__":
    sys.exit(main())
