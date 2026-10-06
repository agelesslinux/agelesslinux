#!/usr/bin/env python3
"""tests/smoke.py — boot an Ageless Linux ISO in QEMU and check it comes up.

Two checks, both run by default:

  serial      Extract the live kernel + initrd from the ISO and boot them
              with console=ttyS0 against the ISO as a CD-ROM. Passes when the
              serial log shows systemd's "Welcome to Ageless Linux" banner
              (proof the squashfs, live-boot and our os-release all work) and
              then the display manager starting. It then waits for autologin
              and saves desktop.png, a picture of the live desktop.
  firmware    Boot the ISO the way a user does, through its own bootloader
              (OVMF UEFI on amd64/arm64, SeaBIOS too on amd64), and save
              screenshots from the QEMU monitor. This exercises GRUB/isolinux
              on the medium; the PNGs are uploaded as CI artifacts for a human
              (or a later OCR step) to eyeball.

Netinst ISOs boot debian-installer rather than a live system, so for them
the serial check looks for d-i's main menu instead.

Usage:
    tests/smoke.py out/ageless-timeless-0.1-amd64-live.iso [--arch amd64]
                   [--timeout 900] [--only serial|firmware] [--artifacts DIR]

Needs qemu-system-*, ovmf / qemu-efi-aarch64 and xorriso (all in the build
container). Uses KVM when /dev/kvm is available, TCG otherwise.
"""

from __future__ import annotations

import argparse
import os
import re
import shutil
import socket
import subprocess
import sys
import tempfile
import time
import zlib
from pathlib import Path

# systemd colours its console output; markers are matched with escapes stripped.
ANSI = re.compile(r"\x1b\[[0-9;?]*[A-Za-z]|\x1b[()][A-Za-z0-9]")

LIVE_MARKERS = ["Welcome to Ageless Linux", "Light Display Manager"]
# d-i's newt title. Stock d-i brands itself "Debian"; the rootskel-gtk theme
# udeb (roadmap Phase 2) is where an Ageless title would come from.
NETINST_MARKERS = ["Debian installer main menu"]

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
    # romfile= : no PXE option ROM needed (and ipxe-qemu isn't installed).
    cmd += ["-m", str(memory), "-smp", "2",
            "-netdev", "user,id=net0", "-device", "virtio-net-pci,netdev=net0,romfile="]
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
                buf = ANSI.sub("", buf + text)
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


def serial_check(iso: Path, arch: str, timeout: int, artifacts: Path, netinst: bool,
                 desktop_wait: int) -> bool:
    print(f"== serial check ({arch})", flush=True)
    with tempfile.TemporaryDirectory() as tmp:
        mon = Path(tmp) / "monitor.sock"
        kernel, initrd, cmdline = extract_boot_files(iso, Path(tmp))
        cmd = qemu_base(arch, 3072) + cdrom_args(arch, iso)
        if arch == "arm64":
            cmdline = cmdline.replace("ttyS0", "ttyAMA0")
        if arch == "amd64":
            cmd += ["-vga", "std"]
        else:
            cmd += ["-device", "ramfb"]
        cmd += ["-kernel", str(kernel), "-initrd", str(initrd), "-append", cmdline,
                "-display", "none", "-serial", "stdio", "-monitor", f"unix:{mon},server,nowait"]
        markers = NETINST_MARKERS if netinst else LIVE_MARKERS
        proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL)
        try:
            found = wait_for_markers(proc, artifacts / "serial.log", markers, timeout)
            if len(found) == len(markers) and desktop_wait > 0 and proc.poll() is None:
                # The display manager is up; give autologin time to draw the
                # desktop, then keep a picture of it for humans to review.
                time.sleep(desktop_wait)
                shot = artifacts / "desktop.ppm"
                monitor_command(mon, f"screendump {shot}")
                time.sleep(2)
                if shot.exists():
                    print(f"   desktop screenshot: {ppm_to_png(shot)}", flush=True)
        finally:
            proc.kill()
            proc.wait()
    ok = len(found) == len(markers)
    if not ok and proc.returncode not in (None, -9):
        tail = (artifacts / "serial.log").read_text(errors="replace")[-800:]
        print(f"   QEMU exited with status {proc.returncode}:\n{tail}", flush=True)
    print(f"   {'PASS' if ok else 'FAIL'}: {len(found)}/{len(markers)} markers "
          f"(log: {artifacts / 'serial.log'})", flush=True)
    return ok


def ppm_to_png(ppm: Path) -> Path:
    """Convert QEMU's binary P6 screendump to PNG with the stdlib only."""
    data = ppm.read_bytes()
    fields, pos = [], 0
    while len(fields) < 4:  # magic, width, height, maxval (skipping comments)
        while data[pos:pos + 1].isspace():
            pos += 1
        if data[pos:pos + 1] == b"#":
            pos = data.index(b"\n", pos) + 1
            continue
        end = pos
        while not data[end:end + 1].isspace():
            end += 1
        fields.append(data[pos:end])
        pos = end
    pixels = data[pos + 1:]
    width, height = int(fields[1]), int(fields[2])
    stride = width * 3
    raw = b"".join(b"\0" + pixels[y * stride:(y + 1) * stride] for y in range(height))

    def chunk(kind: bytes, body: bytes) -> bytes:
        return (len(body).to_bytes(4, "big") + kind + body
                + zlib.crc32(kind + body).to_bytes(4, "big"))

    png = ppm.with_suffix(".png")
    png.write_bytes(b"\x89PNG\r\n\x1a\n"
                    + chunk(b"IHDR", width.to_bytes(4, "big") + height.to_bytes(4, "big") + bytes([8, 2, 0, 0, 0]))
                    + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))
    ppm.unlink()
    return png


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
    drawn = [s for s in shots if s.exists() and len(set(s.read_bytes()[64:])) > 4]
    for shot in shots:
        if shot.exists():
            ppm_to_png(shot)
    print(f"   {'PASS' if drawn else 'FAIL'}: {len(drawn)}/{len(shots)} non-blank screenshots in {artifacts}",
          flush=True)
    return bool(drawn)


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("iso", type=Path)
    p.add_argument("--arch", choices=("amd64", "arm64"), default="amd64")
    p.add_argument("--timeout", type=int, default=900, help="seconds per check (default 900; TCG is slow)")
    p.add_argument("--only", choices=("serial", "firmware"))
    p.add_argument("--desktop-wait", type=int, default=120,
                   help="seconds to wait after the display manager starts before the desktop "
                        "screenshot (0 to skip)")
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
        results["serial"] = serial_check(iso, args.arch, args.timeout, artifacts, netinst,
                                         0 if netinst else args.desktop_wait)
    if args.only in (None, "firmware"):
        results["uefi"] = firmware_check(iso, args.arch, "uefi", min(args.timeout, 300), artifacts)
        if args.arch == "amd64":
            results["bios"] = firmware_check(iso, args.arch, "bios", min(args.timeout, 300), artifacts)

    print("== summary: " + ", ".join(f"{k}={'ok' if v else 'FAILED'}" for k, v in results.items()))
    return 0 if all(results.values()) else 1


if __name__ == "__main__":
    sys.exit(main())
