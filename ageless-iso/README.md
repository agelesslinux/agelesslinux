# ageless-iso — build Ageless Linux

This directory turns Debian 13 "trixie" into **Ageless Linux 0.1 "Timeless"**,
an installable distribution: a MATE desktop in the Linux Mint style on a
Debian base (think LMDE with MATE). The ISOs carry the same refusal of
California AB 1043 age verification as `become-ageless.sh`.

One command builds everything inside a pinned container. The host needs
only Python 3 and Podman or Docker.

```bash
./build.py --variant live                 # live ISO: MATE desktop + Calamares installer
./build.py --variant netinst              # netinstall ISO: stock debian-installer + preseed
./build.py --variant live --flagrant      # flagrant mode (ageless-refusal)
./build.py --variant packages             # just the .debs, in out/debs/
./build.py --variant live --dry-run       # show the container commands
```

Output goes to `out/`: the ISO, its `.sha256`, the package manifest and the
build log. Boot-test it with:

```bash
docker run --rm --device /dev/kvm -v $PWD:/src:ro -v $PWD/out:/out localhost/ageless-build:trixie \
    python3 /src/tests/smoke.py /out/ageless-timeless-0.1-amd64-live.iso
```

## What gets built

| Product | Tool | Audience |
|---|---|---|
| `ageless-timeless-0.1-<arch>-live.iso` | live-build + Calamares | Everyone. It boots to an Ageless MATE desktop with "Install Ageless Linux" on it. |
| `ageless-timeless-0.1-<arch>-netinst.iso` | simple-cdd + stock d-i | People who know debian-installer. About 700 MB. Until `apt.agelesslinux.org` exists it is built as a DVD-type image, so the Ageless and Mint packages and the MATE core install offline. Everything else comes from the Debian mirror. |

Packages (in `packages/`, built by `tools/build-packages.sh`):

| Package | What it does |
|---|---|
| `ageless-os-release` | Diverts `/usr/lib/os-release`: `ID=ageless`, `ID_LIKE=debian`, `VERSION_CODENAME=timeless`, `DEBIAN_CODENAME=trixie` |
| `ageless-compliance` | Standard mode: `/etc/ageless/ab1043-compliance.txt` plus the nonfunctional age-verification API |
| `ageless-refusal` | Flagrant mode: the refusal statement and `/etc/ageless/REFUSAL`. Conflicts with `ageless-compliance`. |
| `ageless-agelessd` | 24-hour timer that neutralizes systemd userdb `birthDate`. Does nothing unless `systemd-userdbd` is installed. |
| `ageless-standard` / `ageless-flagrant` | Metapackages for the two stances |
| `ageless-desktop-mate` | Wallpaper, Mint-style panel layout, theme and font defaults, slick-greeter config |
| `ageless-maker` | Metapackage of maker tools (Arduino, KiCad, FreeCAD, slicers, serial terminals). In the archive, not on the ISO. |
| `calamares-settings-ageless` | Fork of `calamares-settings-debian` with Ageless branding |

## Layout

```
build.py                    one entrypoint (stdlib Python)
common/release.env          name, version, codename, Debian suite, snapshot pin
containers/Containerfile.build
packages/                   our Debian source packages
variant-live/               live-build config + build-inner.sh
variant-netinst/            simple-cdd profile + build-inner.sh
upstream/rebuilds.toml      Mint/MATE packages we rebuild (tools/rebuild.py)
tests/                      QEMU smoke test, unit tests
docs/                       roadmap, MATE/Mint research, fork guide
```

CI is `.github/workflows/ageless-iso.yml` at the repo root. It runs lint,
builds the .debs, builds the {live, netinst} × {amd64, arm64} ISOs, runs the
QEMU smoke test, and creates a draft release on `v*` tags.

## Known gaps

- **No Secure Boot**: disable it to boot the ISO (roadmap §2).
- **No signed archive yet.** `apt.agelesslinux.org` and `ageless-keyring`
  are Phase 1 work. Until then, installed systems take updates from Debian
  only. The Calamares `sources-final` step adds the Ageless archive
  automatically once the keyring package exists.
- The d-i image skips **32-bit UEFI** boot. simple-cdd 0.6.9 still expects
  i386 installer images, which trixie no longer ships; `variant-netinst/build-inner.sh`
  works around this and fails loudly once upstream fixes it.
- **arm64** builds in CI but is experimental. Debian itself publishes no
  arm64 live images.
- The boot menus (GRUB/isolinux) still use live-build's default look.
- `/etc/issue` still says Debian, until we fork base-files.

See [docs/ROADMAP.md](docs/ROADMAP.md) for the plan and
[docs/mate-and-mint.md](docs/mate-and-mint.md) for the desktop work.
