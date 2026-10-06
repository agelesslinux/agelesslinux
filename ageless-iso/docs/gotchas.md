# Gotchas: what broke while building a Debian 13 spin

Each of these cost a build cycle on the kickoff branch (2026-10-06). They
apply to any trixie derivative built with live-build or simple-cdd, not only
Ageless Linux. Every entry names the fix in this tree.

## live-build (1:20250505+deb13u1)

**live-build replaces `/etc/os-release`.** `bootstrap_debootstrap` swaps the
`/etc/os-release` → `../usr/lib/os-release` symlink for a static copy of
Debian's file, held in place by a *local* dpkg diversion, so it can append
`IMAGE_ID`/`BUILD_ID`. Diverting `/usr/lib/os-release` in your identity
package then has no visible effect, and Calamares clones the static Debian
copy onto every installed system.
→ `variant-live/config/hooks/normal/0050-ageless-os-release.hook.chroot`
removes the local diversion, restores the symlink and keeps `BUILD_ID`.
`0100-ageless-identity.hook.chroot` fails the build if the identity is wrong.

**Don't put `contrib` in `--archive-areas` with `--firmware-chroot true`.**
live-build installs *every* firmware package from the enabled areas. That
includes contrib's `firmware-b43-installer`, whose postinst downloads
firmware and fails in the chroot. Debian's own live images use
`main non-free-firmware`.

**`*.list.binary` files are resolved one file at a time.** Each file is a
single `apt-get --download-only` transaction, so `grub-pc` and
`grub-efi-amd64` (which conflict) must be in **separate** files.
→ `variant-live/arch/amd64/package-lists/installer{,-bios}.list.binary`.

**Calamares needs a pool on the ISO.** Its `bootloader-config` helper
`apt-get install`s `grub-efi` or `grub-pc` *from the live medium*. A live ISO
without a pool installs fine and then can't boot.

**The boot splash says "Debian GNU/Linux".** `binary_bootloader_splash`
hardcodes `_PROJECT`. Ship `config/bootloaders/splash.svg` (640×480; the
`@VERSION@`-style placeholders still work).

**Calamares pulls in ~70 KF6/Qt packages.** That's fine on the live medium,
but they stay on the installed system unless removed.
→ `calamares-settings-ageless` removes `calamares` in `packages.conf` and
runs an `ageless-autoremove` job.

## simple-cdd 0.6.9 / debian-cd 3.2.2

**amd64 builds 404 on the i386 installer.** simple-cdd always mirrors
`installer-i386` images for amd64 (32-bit UEFI support). Trixie no longer
ships an i386 installer.
→ `variant-netinst/build-inner.sh` runs a patched copy of
`build-simple-cdd` and exports `DISABLE_UEFI_32=1` for debian-cd. The script
errors out once the upstream code changes, so the hack can't outlive the bug.

**debian-cd needs `tasksel-data` in the local mirror** (it reads the task
definitions from it). List `tasksel` and `tasksel-data` in the profile.

**A CD-type image silently drops packages.** debian-cd fills a CD to about
640 MB and leaves out whatever doesn't fit, including profile packages. The
only sign is `ERROR: missing required packages from profile` at the very
end. That includes the `simple-cdd-profiles` udeb, without which the
profile never applies. Use `--dvd` when the profile drags in a desktop. The
DVD-type image only holds what the profile needs (~700 MB for us).

**The ISO lands in `images/`**, not `tmp/images/`.

## Build container

- `syslinux-utils`, `isolinux` and `grub-pc-bin` don't exist on arm64.
  Install them per architecture.
- QEMU from `qemu-system-*` with `--no-install-recommends` has no iPXE ROMs.
  Give virtio NICs `romfile=` (empty) or install `ipxe-qemu`.
- Docker Hub rate-limits anonymous pulls. `build.py --base-image
  mirror.gcr.io/library/debian:trixie-slim` sidesteps it.

## Smoke testing

- systemd colours its console output: `Welcome to \e[0m\e[1mAgeless Linux…`.
  Strip ANSI escapes before matching markers.
- Neither live-build's GRUB nor its isolinux menu has a timeout, so a
  firmware boot sits at the menu forever. Use direct kernel boot
  (`-kernel/-initrd` extracted from the ISO) to test the system, and
  firmware boot only to screenshot the bootloader.

## Packaging

**Conffiles survive `apt remove`.** Files a package installs under `/etc`
are conffiles, and dpkg keeps them until the package is *purged*. Our stance
packages (`ageless-compliance`, `ageless-refusal`) conflict, so switching
stance removes one, but its `/etc/ageless/REFUSAL` stayed and the system
still looked flagrant. Marker files that must come and go with a package
belong in `/usr/share`, with symlinks into `/etc` (symlinks are not
conffiles). The old conffiles get dropped with `rm_conffile` in
`debian/*.maintscript`.

**`dpkg-buildpackage` checks Build-Depends.** A forked upstream package
(mintmenu needs `dh-python`) fails in a build image that only had what our
own packages needed. `tools/build-packages.sh` installs missing build
dependencies when it runs as root.

## Upstream Mint packages

- `mintmenu` stopped tagging at 5.9.0, a Python 2 release; current releases
  live on `master`. Pin a commit.
- `mint-themes` depends on `mint-x-icons`, which isn't in Debian. Rebuild it
  too.
- Mint-Y-Dark-* GTK themes have no `metacity-1` directory. Pair them with the
  light-variant marco theme (`Mint-Y-Sand`), which has dark titlebars.
- mintmenu 6.2.3 draws its search and "All applications" buttons with
  `xsi-*` icons from `xapp-symbolic-icons`, which Debian lacks; without it
  they render as broken-image placeholders. It is undeclared upstream. Rebuild
  it and add the dependency.
