# Ageless Linux Distribution Roadmap

**Document version:** 0.2
**Last updated:** 2026-10-06
**Status:** Phase 0 implemented on the kickoff branch. See "Kickoff decisions"
directly below for where the implementation departs from the 0.1 draft.

This document describes how Ageless Linux graduates from "a bash conversion
script that runs on someone else's distro" to "a signed, bootable, installable
netinstall ISO that people download." It is written to be useful to other
distribution projects that want to fork Debian for their own reasons, not just
to document Ageless Linux's own plan. The civil-disobedience scaffolding is
incidental; the build pipeline is general.

Ageless Linux targets **amd64** and **arm64** as first-class architectures.
The Milk-V Duo S (RISC-V, SG2000) is the Ageless Device and has its own
firmware track — it is out of scope for this document.

## Kickoff decisions (2026-10-06)

The kickoff branch implements Phase 0 and most of the Phase 1 and Phase 3
plumbing. Where it departs from the 0.1 draft, this section wins.

| Topic | 0.1 draft | Kickoff decision | Why |
|---|---|---|---|
| Repo location (§9 Q1) | new `ageless-iso` repo | `ageless-iso/` subdirectory of `agelesslinux` | One place to start. It shares nothing with the conversion script at build time, so `git subtree split -P ageless-iso` can move it out later without losing history. |
| Live desktop (§9 Q2) | XFCE | **MATE**, Mint-flavoured | It is the project's chosen desktop. LMDE (Linux Mint Debian Edition) is the model: Debian base, Mint-style UX. |
| Entrypoint | `build.sh` | `build.py` (stdlib-only Python) | Easier to test and extend (`tests/test_build.py`). Still one command, and the host needs only Python and Podman or Docker. |
| Phase order | netinst first, then live | **both built from day one** | The live ISO is the product people will actually see. simple-cdd netinst stays the technical backbone. |
| Package decomposition (§4) | ~10 source packages | one `ageless` source package producing `ageless-os-release`, `ageless-compliance`, `ageless-refusal`, `ageless-agelessd`, `ageless-standard`, `ageless-flagrant`, `ageless-desktop-mate` and `ageless-maker`; plus `calamares-settings-ageless` | One version and one build per release. `ageless-userdb-neutralize` is folded into agelessd. Metapackages replace tasksel tasks: d-i's `pkgsel/include` and the live build's package lists choose the stance directly. |
| os-release | `ID=ageless`, base fields | also `VERSION_CODENAME=timeless` + `DEBIAN_CODENAME=trixie` (the LMDE convention), divert `/usr/lib/os-release` with `--no-rename` | base-files is Essential. Third-party installers that read the codename need the Debian one. No `/etc/lsb-release`, because trixie's `lsb_release` reads os-release. `/etc/issue` waits for a base-files fork, since diverting a conffile causes a conffile prompt. |
| Stance → os-release | static | `ageless-update-os-release` regenerates the compliance fields when `ageless-compliance` or `ageless-refusal` is installed or removed | Switching modes is just `apt install ageless-refusal`. |
| Snapshot pinning | always | pinned in `common/release.env`; tag builds use it, day-to-day CI uses deb.debian.org | snapshot.debian.org rate-limits and is slow. The pin is what makes release ISOs reproducible. |
| Netinst medium | netinst: packages from the network | simple-cdd `--dvd` (~700 MB): the Ageless, Mint and MATE-core packages are on the medium | debian-cd fills a CD-type image at 640 MB and silently drops what doesn't fit. Without an Ageless archive, the desktop can't come from the network. Revisit when `apt.agelesslinux.org` is live. |
| Container runtime | rootful Podman | Podman **or** Docker (auto-detected) | GitHub runners ship Docker. |

### Phase 0 status

- [x] `ageless-iso/` skeleton (in this repo)
- [x] `containers/Containerfile.build` (trixie + live-build, simple-cdd, debian-cd, mmdebstrap, xorriso, qemu, OVMF)
- [x] `common/release.env` pins `DEBIAN_SNAPSHOT=20261001T000000Z`
- [x] `build.py` builds for real (not a stub): `--variant live|netinst|packages`, `--arch`, `--flagrant`, `--snapshot`, `--dry-run`
- [x] `docs/fork-this-for-your-distro.md` outline
- [x] Packages: `ageless` (8 binaries) and `calamares-settings-ageless`
- [x] CI: `.github/workflows/ageless-iso.yml` (lint → debs → {live, netinst} × {amd64, arm64} → QEMU smoke → draft release on `v*` tags)

---

## 1. Goals

1. **Hold a custom netinstall ISO.** A contributor runs one command on a
   vanilla Linux host and, twenty minutes later, has a bootable
   `ageless-timeless-amd64-netinst.iso` that boots under QEMU, runs
   Debian-installer with Ageless branding, preseeds through partitioning,
   fetches packages from a Debian mirror plus `apt.agelesslinux.org`, and
   reboots into a system whose `/etc/os-release` says `ID=ageless`.

2. **Two ISOs, two audiences.**
   - A **netinstall ISO** for technical users who know what d-i is. This is
     the project's technical backbone.
   - A **live ISO with an attended Calamares installer** for journalists,
     STEM-fair visitors, and the "hand this to a kid" demo path. This is
     the project's media surface.

3. **Reproducible.** Given the same git commit and the same Debian snapshot,
   any contributor — or any adversary trying to prove the ISO does what we
   say it does — can produce a byte-identical ISO. This matters for a civil
   disobedience project whose legal value depends on the inability of any
   third party to quietly substitute a compliant fork.

4. **Containerized and CI-driven.** The whole pipeline runs in rootless or
   rootful Podman, on a stock Debian host, on GitHub Actions. No "works on
   my machine." Contributors should not need to install `live-build` or
   `simple-cdd` on their host.

5. **Pavable by others.** Another distro that wants to fork Debian for
   unrelated reasons (systemd-free, FSF-endorsed, minimal, jurisdiction-
   excluding, etc.) should be able to fork `ageless-iso/`, change the
   branding and the package set, and produce their own ISO without learning
   the internals of d-i, live-build, Calamares, reprepro, or xorriso. This
   goal is why the pipeline is public.

## 2. Non-goals

- **We do not fork debian-installer.** Maintaining a d-i fork is roughly one
  senior-developer-week per Debian point release, indefinitely, plus a
  security-response obligation on partman-crypto and netcfg. This project
  cannot take that on and does not need to.
- **We do not ship Secure Boot.** Debian's signed shim is signed by Microsoft
  via the installer team's submission; derivatives cannot inherit that trust
  without their own Microsoft UEFI CA review, which is impractical for a
  small project. We document "disable Secure Boot to install" on the download
  page. Kali, Qubes, and Tails all do this. It is on-brand for civil
  disobedience.
- **We do not unify the Raspberry Pi image with the arm64 UEFI ISO.** The Pi
  has no UEFI; Debian handles it with a separate `raspi.debian.net` SD-card
  image pipeline built by `vmdb2`. If we ever ship an Ageless Pi image, it
  will be a separate deliverable. The arm64 netinstall ISO targets SBSA-class
  arm64 hardware (Ampere, Graviton, Apple Silicon VMs, arm64 laptops with
  EDK2 firmware).
- **We do not mirror Debian.** Netinstalls pull from `deb.debian.org`;
  Ageless packages come from `apt.agelesslinux.org`. Mirroring is a
  possibility for a later phase if jurisdictional blocking becomes real.
- **We do not build for RISC-V or armhf in this pipeline.** Ageless Device
  firmware is a separate track. armhf is a dying architecture upstream.

## 3. The fundamental architectural choices

Four decisions drive everything else. Each was reached via the research
dispatch summarized in §11 and is justified against the rejected alternatives.

### 3.1 Stock d-i + simple-cdd + preseed + `rootskel-gtk` overlay

**Decision:** Use an unmodified upstream debian-installer for the netinstall
ISO. Drive it with `simple-cdd`, which wraps `debian-cd` and assembles a
netinstall ISO from a preseed file, a package list, and a profile tree.
Brand the installer GUI by shipping a single custom udeb that overrides
`rootskel-gtk` themes — approximately 1–2 KLOC of Qt/CSS and PNGs, not a
fork of the whole installer-team repo.

**Rejected alternatives:**

- **Fork d-i wholesale.** Would require forking ~250 tags of upstream history
  and rebasing custom udebs on every Debian point release. Only Devuan does
  this, and only because they must rip systemd dependencies out of netcfg
  and partman. We have no such structural conflict with Debian.
- **Calamares for netinstall.** Calamares is a Qt GUI wizard with no
  unattended mode, no answer-file, no kickstart equivalent, and its
  `unpackfs` module assumes a live squashfs to clone. Its `netinstall`
  module is a package-group picker that runs *after* `unpackfs`, not an
  alternative to it. Calamares is the wrong tool for a d-i-style netinstall
  by architecture, not by polish.
- **Subiquity (Ubuntu's installer).** Go/Python, tightly coupled to
  cloud-init and snap, poorly documented for derivatives, and actively
  diverging from d-i rather than layering on it. Interesting but wrong.

**Why this choice unlocks everything else:** a preseed-driven d-i build runs
unprivileged in Podman with just `xorriso`, `cpio`, `gzip`, `isolinux`, and
`syslinux-utils`. No loop devices. No privileged container. No root. This
is the *only* installer path where the containerized CI story works without
`--privileged`.

### 3.2 live-build + Calamares for the attended live ISO

**Decision:** Build a second, independent ISO product using Debian's
`live-build` tool, with a forked `calamares-settings-debian` package renamed
`calamares-settings-ageless`. Ship it with an Ageless branding directory
(dark theme, gold accent, IBM Plex fonts matching the website) and a small
custom Python jobmodule `ageless-refusal` that installs the refusal notice
and the agelessd stub daemon into the target rootfs during the `exec:`
phase.

**Why a second ISO is worth the effort:** the netinstall is for people who
already know what "netinstall" means. Journalists writing about civil
disobedience need an ISO they can stick in a USB port, boot on a laptop at
the coffee shop, and click Install. The two audiences are disjoint. Shipping
both is the difference between a technical proof-of-concept and a
usable political artifact.

**Why not "just use Calamares for both":** see §3.1. Calamares cannot do
netinstall.

**Why not "just use d-i for both":** d-i is not a live system. It cannot
show the journalist what Ageless Linux looks like running before they commit
to installing it. The live ISO's value is that it boots into a working
Ageless desktop, and the installer is an optional step from within that
desktop.

### 3.3 Variant matrix on one tree (Kali's pattern)

**Decision:** Structure `ageless-iso/` as a `common/` directory containing
shared package lists, hooks, and includes, plus per-variant subdirectories
(`variant-netinst/`, `variant-live/`, later `variant-minimal/`,
`variant-desktop-xfce/`, etc.) that contain only the delta. One
`build.sh --variant netinst --arch amd64 [--flagrant]` entrypoint.

This is exactly how Kali and Parrot organize their `live-build-config`
repositories. Parrot proves the pattern forks cleanly. It scales to N ISO
flavors without N repos or N CI pipelines.

The netinstall variant uses simple-cdd under the hood. The live variant
uses live-build. The outer directory structure and the `build.sh` UX are
uniform across both; the variant subdirectory knows which inner tool to
invoke. Contributors never touch simple-cdd or live-build directly.

### 3.4 Reproducibility via pinned snapshot.debian.org + mmdebstrap
  
**Decision:** From day one, pin APT sources to a specific
`snapshot.debian.org` timestamp encoded in the repo (under `common/
APT_snapshots.d/`, copying Tails' pattern). Set `SOURCE_DATE_EPOCH` to the
commit timestamp. Sort everything that can be sorted. Zero everything that
can be zeroed. Publish `SHA256SUMS` and a `.buildinfo` artifact beside
every ISO.

For the netinstall pipeline, simple-cdd's reproducibility is imperfect;
that is a Phase-4 debt we pay down by migrating to a hand-assembled
`mmdebstrap → d-i udebs → xorriso` pipeline. For Phase 1 we accept that
the first ISOs will be *deterministic from the same source tree and
snapshot timestamp*, but not yet bit-identical across machines.

---

## 4. Package decomposition

Today, `become-ageless.sh` performs ~six discrete mutations to a running
system. Each of them becomes a Debian package in `apt.agelesslinux.org`.
The ISO's preseed just says "install `ageless-meta`" and all six land
correctly on first boot.

| Package                       | Owns                                                | Notes |
|-------------------------------|-----------------------------------------------------|-------|
| `ageless-keyring`             | `/usr/share/keyrings/ageless-archive-keyring.gpg`  | Must ship as a .deb and as a standalone downloadable file for users manually adding the repo. Modeled on `kali-archive-keyring`. |
| `ageless-os-release`          | `/etc/os-release`, `/etc/lsb-release`              | Diverts upstream `base-files`. Sets `ID=ageless`, `AGELESS_AB1043_COMPLIANCE`, `AGELESS_BASE_ID`. |
| `ageless-compliance`          | `/etc/ageless/ab1043-compliance.txt`, `age-verification-api.sh` | Standard mode (with the non-functional API stub as fig-leaf good-faith compliance). |
| `ageless-refusal`             | `/etc/ageless/REFUSAL`                              | Flagrant mode. Conflicts with `ageless-compliance`; the tasksel task chooses one. |
| `ageless-userdb-neutralize`   | adduser/useradd hook in `/etc/adduser.conf.d/`     | Ensures every new user's `/etc/userdb/$u.user` drop-in has `birthDate: "1970-01-01"`. Deals with systemd PR #40954. |
| `ageless-agelessd`            | `/etc/ageless/agelessd`, `agelessd.service`, `agelessd.timer` | The 24h enforcement daemon. Installed by default; can be removed without breaking the distro. |
| `task-ageless-standard`       | tasksel task file                                   | `Depends: ageless-os-release, ageless-compliance, ageless-userdb-neutralize, ageless-agelessd` |
| `task-ageless-flagrant`       | tasksel task file                                   | `Depends: ageless-os-release, ageless-refusal, ageless-userdb-neutralize, ageless-agelessd` |
| `ageless-meta`                | nothing; pure metapackage                           | `Depends: task-ageless-standard`. Default install target. |
| `ageless-installer-theme`     | udeb. Installs into `src/usr/share/graphics/` at higher priority than rootskel-gtk | Dark theme + gold accent for the d-i GUI. The *only* d-i source we fork. |
| `calamares-settings-ageless`  | `/etc/calamares/settings.conf`, `/usr/share/calamares/branding/ageless/`, `/usr/lib/calamares/modules/ageless-refusal/` | Fork of `calamares-settings-debian`. Ships only in the live ISO. |

`become-ageless.sh` itself remains the *conversion* path — for users who
already run Ubuntu, Fedora, or Arch and want to become Ageless Linux without
reinstalling. The native-install path (this document) and the conversion
path (`become-ageless.sh`) produce equivalent end states but via different
means.

## 5. APT repository (`apt.agelesslinux.org`)

### 5.1 Tool: reprepro

Chosen over aptly (overkill for 5–10 packages, snapshot model we don't need)
and bare `apt-ftparchive` (reinvents too much). Reprepro is in the Debian
archive, handles multi-arch and multi-component cleanly, and operates on a
simple file-based config in `conf/distributions`. Kali and PureOS both use
reprepro; it is the default for small derivatives.

### 5.2 Suite naming

Initial suite: **`timeless`** (matches the current `become-ageless.sh`
codename). A `timeless-proposed` staging suite gets added once we need
promotion gates. Future suites follow the same codename discipline — no
toy names, no alliterative animals, all reinforcing "ageless" / "timeless" /
"indeterminate" as rhetorical frames.

### 5.3 Signing discipline

- **Master key offline.** RSA 4096 or ed25519. Identity:
  `Ageless Linux Archive Key <archive@agelesslinux.org>`. Held on an
  air-gapped machine or in a safe. Not John's personal key.
- **Signing subkey on YubiKey 5.** Ed25519 subkey moved to the token via
  `gpg --card-edit` + `keytocard`. `gpg-agent` forwarding or a dedicated
  signing host handles `reprepro`'s `SignWith:` call.
- **Signing host ≠ build host.** Builds produce `.deb`s on the CI runner,
  push them to a dedicated signing box with the YubiKey, reprepro ingests
  and signs there, then the signing box rsyncs to the public mirror. The
  CI runner never sees a private key.
- **Publish the public key** at `https://apt.agelesslinux.org/archive-key.asc`
  and ship it in `ageless-keyring`. Users add the repo with `signed-by=`,
  never `apt-key add` (deprecated).

### 5.4 Layout

```
apt.agelesslinux.org/
├── archive-key.asc
├── dists/
│   └── timeless/
│       ├── Release, Release.gpg, InRelease
│       ├── main/
│       │   ├── binary-amd64/Packages{,.gz,.xz}
│       │   ├── binary-arm64/Packages{,.gz,.xz}
│       │   └── source/Sources{,.gz,.xz}
│       └── contrib/                       # future forked upstreams
└── pool/
    └── main/
        └── a/
            ├── ageless-keyring/
            ├── ageless-os-release/
            ├── ageless-compliance/
            ├── ageless-refusal/
            ├── ageless-userdb-neutralize/
            ├── ageless-agelessd/
            └── ageless-meta/
```

### 5.5 Hosting

Static files, hosted on either GitHub Pages (fine for Phase 1, 1 GB repo
cap is adequate for ~a dozen packages), or Cloudflare R2 with a custom
domain (Phase 3+, when we want egress-fee-free distribution at scale). No
dynamic server. Any HTTP host that can serve static files with correct
MIME types works.

## 6. Build pipeline

### 6.1 Container runtime

**Primary:** rootful Podman on a Debian `trixie` host. This is the only
rootful privilege we accept, and it applies to the *host-inside-the-
container* only, not to the contributor's host user account.

**Future (Phase 4):** migrate to rootless Podman once the mmdebstrap-based
pipeline is in place.

**Image:** a pinned `debian:trixie-slim` with the build dependencies baked
in (`simple-cdd`, `xorriso`, `live-build`, `mmdebstrap`, `reprepro`,
`qemu-user-static`, `binfmt-support`, `syslinux`, `grub-efi-amd64-bin`,
`grub-efi-arm64-bin`). Defined by `containers/Containerfile.build` in the
`ageless-iso` repo.

### 6.2 Cross-architecture strategy

**amd64 builds** run on stock `ubuntu-24.04` GitHub Actions runners inside
the build container. **arm64 builds** run on **native `ubuntu-24.04-arm`
runners** (GA since January 2025, free for public repos, ~2x cost of amd64
on paid plans). We use a CI matrix rather than `qemu-user-static`
emulation in CI because emulation is 4–8x slower and has known rough edges
(glibc `ldconfig` segfaults on arm64, slow perl maintainer scripts, Rust
atomic issues).

**For contributors without arm64 hardware**, a fallback
`qemu-user-static` + `binfmt_misc` path is documented and supported in
`build.sh`, but is not used in CI. Contributors who need to test their
arm64 changes locally can opt in to the slow path; the fast path requires
pushing to a branch and letting CI run.

### 6.3 Reproducibility plumbing

- `SOURCE_DATE_EPOCH` is set to the git commit timestamp at the start of
  every build: `export SOURCE_DATE_EPOCH=$(git log -1 --format=%ct)`
- APT sources pin to `snapshot.debian.org/archive/debian/YYYYMMDDTHHMMSSZ/`,
  timestamp recorded in `common/APT_snapshots.d/default`.
- `xorriso -as mkisofs` is called with `-volume_date all_file_dates =$SOURCE_DATE_EPOCH`
  and sorted input.
- Bootstrap tarballs (for the live-ISO path) are built with `mmdebstrap`,
  which honors SOURCE_DATE_EPOCH, sorts tar output, and zeroes mtimes.
- Every build publishes `SHA256SUMS`, `SHA512SUMS`, and a `.buildinfo`
  file alongside the ISO.
- The signing host signs the `SHA256SUMS` file; users verify the ISO via
  `gpg --verify SHA256SUMS.gpg && sha256sum -c SHA256SUMS`.

### 6.4 Smoke tests

Every ISO is boot-tested in QEMU in CI before artifact upload. Minimal
invocations, copied from the dual-arch research:

```bash
# amd64 UEFI — needs ovmf
qemu-system-x86_64 -machine q35,accel=kvm -cpu host -m 2048 \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE.fd \
  -drive if=pflash,format=raw,file=OVMF_VARS.fd \
  -cdrom "$ISO" -boot d -nographic -serial mon:stdio -net nic -net user

# amd64 BIOS legacy path
qemu-system-x86_64 -machine pc -m 2048 -cdrom "$ISO" \
  -boot d -nographic -serial mon:stdio

# arm64 UEFI — needs qemu-efi-aarch64
qemu-system-aarch64 -machine virt -cpu cortex-a72 -m 2048 \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/AAVMF/AAVMF_CODE.fd \
  -drive if=pflash,format=raw,file=AAVMF_VARS.fd \
  -drive if=none,file="$ISO",id=cd,media=cdrom \
  -device virtio-scsi-device -device scsi-cd,drive=cd \
  -nographic -serial mon:stdio -net nic -net user
```

CI asserts that the serial output contains a known marker string within
180 seconds (`"Ageless Linux installer main menu"` for the netinst variant;
`"Welcome to Ageless Linux"` for the live variant), then kills the VM.
Full preseed-through-to-installed-system tests run nightly rather than
per-commit — they take 10–20 minutes and would exhaust the per-commit
budget.

## 7. Repository layout

A new top-level repo, `agelesslinux/ageless-iso`, sibling to the existing
`agelesslinux/agelesslinux` (the conversion script) and
`agelesslinux/agelesslinux.org` (the website). The conversion-script repo
stays where it is; the ISO pipeline is a distinct codebase with different
dependencies, different CI, and different contribution patterns.

```
ageless-iso/
├── README.md
├── CONTRIBUTING.md
├── LICENSE                     # Unlicense
├── build.sh                    # one entrypoint: --variant, --arch, --flagrant
├── containers/
│   └── Containerfile.build     # pinned debian:trixie-slim + build deps
├── common/
│   ├── APT_snapshots.d/
│   │   └── default             # snapshot.debian.org timestamp
│   ├── package-lists/
│   │   ├── ageless.list.chroot
│   │   └── standard.list.chroot
│   ├── includes.chroot/        # /etc overlays, wallpapers, systemd units
│   ├── hooks/
│   │   └── normal/
│   │       └── 50-ageless-postinst.chroot
│   └── archives/
│       └── ageless.key.chroot  # ageless-keyring public key for the target
├── variant-netinst/
│   ├── profiles/               # simple-cdd profile tree
│   │   ├── ageless.conf
│   │   ├── ageless.packages
│   │   ├── ageless.preseed
│   │   ├── ageless.postinst
│   │   └── ageless.description
│   ├── localudebs/
│   │   └── ageless-installer-theme_*.udeb
│   └── build-inner.sh          # invokes build-simple-cdd
├── variant-live/
│   ├── config/                 # live-build config tree
│   │   ├── auto/{build,clean,config}
│   │   ├── package-lists/
│   │   │   └── calamares.list.chroot
│   │   ├── includes.chroot/
│   │   │   └── etc/calamares/  # overlay onto calamares-settings-ageless
│   │   └── hooks/
│   └── build-inner.sh          # invokes lb config && lb build
├── packages/                   # source trees for the ageless-* .debs
│   ├── ageless-keyring/
│   ├── ageless-os-release/
│   ├── ageless-compliance/
│   ├── ageless-refusal/
│   ├── ageless-userdb-neutralize/
│   ├── ageless-agelessd/
│   ├── ageless-meta/
│   ├── ageless-installer-theme/        # the udeb for d-i branding
│   └── calamares-settings-ageless/     # fork of calamares-settings-debian
├── repo/
│   ├── conf/
│   │   ├── distributions       # reprepro suite config
│   │   └── options
│   └── publish.sh              # rsync repo to signing host
├── tests/
│   ├── smoke-amd64.sh          # QEMU boot-and-grep
│   ├── smoke-arm64.sh
│   └── full-install-amd64.sh   # nightly: preseed all the way through
├── docs/
│   ├── fork-this-for-your-distro.md    # the road-paving doc
│   ├── branding.md
│   ├── preseed-anatomy.md
│   └── troubleshooting.md
└── .github/
    └── workflows/
        ├── build.yml           # matrix: {amd64, arm64} × {netinst, live}
        ├── smoke.yml           # QEMU boot tests
        └── publish.yml         # on tag: sign, rsync, publish
```

### 7.1 The `build.sh` contract

```
Usage: build.sh --variant <netinst|live> --arch <amd64|arm64> [--flagrant] [--output DIR]

Builds an Ageless Linux ISO inside the pinned build container.
Defaults to reading APT_snapshots.d/default for reproducibility.

Examples:
  ./build.sh --variant netinst --arch amd64
  ./build.sh --variant live --arch arm64 --flagrant
  ./build.sh --variant netinst --arch amd64 --output /tmp/isos
```

The outer `build.sh` sets up the container, mounts the repo read-write,
and invokes `variant-*/build-inner.sh` inside. Contributors on any Linux
host run the same command and get the same ISO. No host dependencies
beyond Podman.

## 8. Phase plan

Each phase has a hard exit criterion. No phase starts until the previous
phase's exit criterion is met.

### Phase 0 — Foundation (this PR)

- [x] Research dispatch (seven parallel threads — complete, see §11)
- [x] Architectural decisions documented (this roadmap)
- [ ] Create `ageless-iso/` repo skeleton
- [ ] `containers/Containerfile.build` runs and produces an idle container
      with all build deps installed
- [ ] `common/APT_snapshots.d/default` pinned to a specific date
- [ ] `build.sh` stub that accepts the documented flags and prints what it
      would do, without yet producing an ISO
- [ ] `docs/fork-this-for-your-distro.md` outline (not full content yet)

**Exit criterion:** the skeleton merges to `main`. No ISO yet.

### Phase 1 — First netinst ISO (weeks 1–3)

- [ ] Stand up `apt.agelesslinux.org` with reprepro, serving an empty
      `timeless` suite. Archive key published.
- [ ] Package `ageless-keyring` (self-referencing; chicken-and-egg solved
      by shipping it as a downloadable `.deb` on the website too)
- [ ] Package `ageless-os-release` with a `dpkg-divert` of `/etc/os-release`
      and `/etc/lsb-release` from `base-files`
- [ ] Package `ageless-compliance` (standard mode only, for Phase 1)
- [ ] Package `ageless-meta` (`Depends: ageless-os-release, ageless-compliance`)
- [ ] `variant-netinst/` simple-cdd profile wiring: preseed the minimum set
      (hostname, language, keyboard, root password hash from env var, user
      account, `tasksel/first=standard`, `pkgsel/include=ageless-meta`)
- [ ] `build.sh --variant netinst --arch amd64` produces a bootable ISO
- [ ] QEMU amd64 smoke test: boot, see the d-i main menu banner, timeout
      clean
- [ ] Manual full-install test on a contributor's laptop: preseed the whole
      way through, reboot, verify `/etc/os-release` says `ID=ageless`

**Exit criterion:** on a clean Podman host, `./build.sh --variant netinst
--arch amd64` produces an ISO that boots in QEMU to the d-i banner, and a
human has successfully preseeded it all the way through to a running
Ageless Linux system with no interaction beyond selecting the ISO at the
boot prompt. **This is the moment we hold the ISO.**

### Phase 2 — Architectural parity and full package set (weeks 4–6)

- [ ] Native arm64 build via `ubuntu-24.04-arm` GitHub Actions runner
- [ ] Package `ageless-userdb-neutralize`: adduser policy hook writing
      `/etc/userdb/$u.user` with `birthDate: "1970-01-01"` on every new user
- [ ] Package `ageless-agelessd` with the service + 24h timer
- [ ] Package `ageless-refusal` for flagrant mode
- [ ] `task-ageless-standard` and `task-ageless-flagrant` tasksel tasks
- [ ] `ageless-installer-theme` udeb: dark theme + gold accent PNGs for
      `rootskel-gtk`. This is the one piece of d-i we fork.
- [ ] CI matrix: `{amd64, arm64} × {netinst} × {standard, flagrant}` = 4 ISOs
- [ ] QEMU smoke tests green on both arches
- [ ] `SHA256SUMS` and `.buildinfo` published alongside every ISO

**Exit criterion:** `main` branch builds four ISOs automatically on every
push, smoke tests pass, and anonymous users can download and verify signed
ISOs from `apt.agelesslinux.org/isos/`.

### Phase 3 — Live ISO with Calamares (weeks 7–9)

- [ ] Fork `calamares-settings-debian` → `calamares-settings-ageless`
- [ ] Replace `calamares/branding/debian/` with `calamares/branding/ageless/`:
      dark theme, gold accent, IBM Plex fonts, slideshow matching the
      website's tone
- [ ] Write `/usr/lib/calamares/modules/ageless-refusal/` Python jobmodule
      that installs the refusal notice and agelessd into `$rootMountPoint`
      during the `exec:` phase
- [ ] `variant-live/` live-build configuration pulling in `calamares` +
      `calamares-settings-ageless` + a minimal XFCE desktop
- [ ] `build.sh --variant live --arch amd64` produces a bootable live ISO
      that runs a desktop and offers "Install Ageless Linux" as a desktop
      icon
- [ ] Install-from-live flow works end-to-end in QEMU

**Exit criterion:** a journalist with no Linux experience can download
`ageless-timeless-amd64-live.iso`, write it to a USB stick, boot from it,
see an Ageless desktop, and click "Install" to run the Calamares wizard.
This is the ISO that goes in the press kit.

### Phase 4 — Reproducibility hardening (weeks 10–12)

- [ ] Migrate the netinst path from simple-cdd (rootful, not quite
      reproducible) to `mmdebstrap + d-i udebs + xorriso` (rootless,
      bit-identical)
- [ ] Verify bit-identical builds across two different hosts given the
      same commit and snapshot
- [ ] Third-party reproducibility: invite an independent contributor to
      build and compare hashes, publish the result
- [ ] Migrate CI to rootless Podman

**Exit criterion:** a second independent build on different hardware
produces a SHA256-identical ISO. Publish this as the reproducibility
proof.

### Phase 5 — Road-paving (ongoing, starts in Phase 1)

- [ ] `docs/fork-this-for-your-distro.md`: step-by-step tutorial for
      forking `ageless-iso` into, say, "Systemd-free Debian," "Minimal
      Debian for journalists," or "Refuse-all-state-laws Debian"
- [ ] `docs/branding.md`: where all the strings, colors, logos, and QML
      slideshow frames live, and how to replace them without breaking
      anything
- [ ] `docs/preseed-anatomy.md`: annotated walkthrough of
      `variant-netinst/profiles/ageless.preseed`, one section per
      debconf question, explaining the choice
- [ ] Publish `ageless-iso` as a GitHub template repo so other distros
      can click "Use this template" and start from a known-good baseline

**Exit criterion:** at least one other distribution project forks
`ageless-iso` and produces their own ISO without needing to file issues
against us. This is the "we paved the road" success signal.

## 9. Open questions

These are decisions I did not make in this roadmap because they need your
input or further discussion.

1. **Repo location.** Does `ageless-iso/` live under
   `github.com/agelesslinux/ageless-iso` as a new repo, or inside the
   existing `agelesslinux` repo as a subdirectory? I lean toward a new
   repo — the dependency footprint, the CI configuration, and the
   contributor audience are all different from the conversion script.
2. **Desktop for the live ISO.** XFCE (light, fast, well-tested with
   Calamares, what Kali ships) vs. GNOME (heavier, better screenshots)
   vs. no desktop (pure terminal installer, cheapest to maintain). I
   lean XFCE for Phase 3; the journalist audience needs a desktop, and
   XFCE ships the cleanest demo at the lowest build cost.
3. **Snapshot cadence.** How often do we bump
   `common/APT_snapshots.d/default`? Monthly? On every Debian point
   release? On demand? Security-sensitive package updates would ideally
   roll faster than monthly, but "pinned snapshot" is the whole
   reproducibility story.
4. **Suite promotion.** Do we want a `timeless-proposed` staging suite
   from day one, or is that premature for a repo with ~10 packages?
5. **`become-ageless.sh`'s future.** With a native install path, is the
   conversion script still the flagship, or does it become a
   convenience tool for users who already run Ubuntu/Fedora/Arch? I
   think the latter, but the marketing implications are worth
   discussing before quietly demoting it.
6. **Codename discipline.** `timeless` is the current codename from
   `become-ageless.sh`. If we ship a second suite, we need the next
   codename now so we can plan around it. Candidates: `undated`,
   `ageless`, `indeterminate`, `birthless`, `uncarded`.

## 10. How other distros can use this

A distribution project that wants to fork Debian for reasons unrelated to
AB 1043 — for example, a hypothetical "systemd-free Debian focused on
journalist privacy" — can fork `ageless-iso` and, working through
`docs/fork-this-for-your-distro.md`, arrive at their own ISO by doing the
following:

1. Clone `ageless-iso` to a new repo (e.g. `journalistix`).
2. Replace `packages/ageless-*` with their own source packages (at minimum,
   an `os-release` package and a meta-package).
3. Replace branding assets in `variant-netinst/localudebs/` and
   `packages/calamares-settings-ageless/` with their own.
4. Update `common/package-lists/*.list.chroot` with their package choices.
5. Update `common/APT_snapshots.d/default` to the snapshot they want to
   pin against.
6. Run `./build.sh --variant netinst --arch amd64`.

That is the whole procedure. They never need to understand simple-cdd or
live-build directly. They never need to touch xorriso or mmdebstrap. They
never need to fork debian-installer. The road is paved.

The rhetorical value of this for Ageless Linux specifically is real: if
other distros start forking `ageless-iso` to do things Ageless Linux did
not invent, it proves that the civil-disobedience toolkit generalizes to
any jurisdictional or philosophical refusal. Every fork is evidence that
the political artifact works.

## 11. Research appendix

This roadmap is the synthesis of seven parallel research threads dispatched
on 2026-04-10, each answering one self-contained question. The key
primary sources each thread surfaced:

- **debian-installer internals and forking cost**
  - https://wiki.debian.org/DebianInstaller
  - https://wiki.debian.org/DebianInstaller/Build
  - https://d-i.debian.org/doc/internals/
  - https://salsa.debian.org/installer-team/debian-installer
  - https://salsa.debian.org/installer-team/rootskel-gtk
  - https://wiki.debian.org/DebianInstaller/Preseed/EditIso
- **Calamares unattended mode and netinstall viability**
  - https://calamares.io/docs/
  - https://github.com/calamares/calamares (specifically `src/calamares/main.cpp`, `src/modules/{unpackfs,netinstall,packages,dummypython,shellprocess}/`)
  - https://salsa.debian.org/debian-live/calamares-settings-debian
- **Debian ISO builder ecosystem**
  - https://live-team.pages.debian.net/live-manual/
  - https://salsa.debian.org/debian-cd-team/debian-cd
  - https://wiki.debian.org/Simple-CDD
  - https://manpages.debian.org/mmdebstrap
  - https://salsa.debian.org/debian/debos
- **Containerized reproducible builds**
  - https://wiki.debian.org/ReproducibleInstalls
  - https://manpages.debian.org/mmdebstrap
  - https://docs.github.com/en/actions/using-github-hosted-runners/about-github-hosted-runners/about-larger-runners (arm64 runners)
  - debuerreotype (Tianon Gravi) — reference for reproducible Debian tarballs
- **Dual-arch ISO boot chains**
  - https://wiki.debian.org/Arm64Port
  - https://wiki.debian.org/SecureBoot
  - Debian installer manual, arm64 chapter
  - https://raspi.debian.net/
- **Signed APT repository tooling**
  - https://wiki.debian.org/DebianRepository/Setup
  - https://salsa.debian.org/debian/reprepro
  - https://www.aptly.info/
  - https://manpages.debian.org/debmirror
  - `kali-archive-keyring` (the template everyone copies)
- **Derivative survey**
  - https://github.com/RPi-Distro/pi-gen (numbered-stage containerized build pattern)
  - https://gitlab.tails.boum.org/tails/tails (APT_snapshots.d reproducibility)
  - https://gitlab.com/kalilinux/build-scripts/live-build-config (variant matrix)
  - https://source.puri.sm/pureos/packages/pureos-image-recipes (debos YAML recipes)
  - https://git.devuan.org/devuan/installer-iso (per-variant Makefile fragments)

The three patterns all of these sources converge on, which shape §7 of
this roadmap, are: **variant matrix on one tree** (Kali/Parrot),
**APT snapshot pinning** (Tails), and **containerized one-command builds**
(pi-gen/PureOS). Any distro build system that has all three is easy to
contribute to; any that has none is a specialist-only artifact. Ageless
Linux's build system will have all three from day one.
