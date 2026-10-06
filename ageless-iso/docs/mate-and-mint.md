# MATE on Debian, the Mint way

Research notes for "rebuild MATE for Debian". Package versions were checked
against the Debian archive on 2026-10-06 (`apt-cache policy` in a trixie
container with forky and sid added).

## The goal

Linux Mint's MATE edition is the reference desktop: one bottom panel, a menu
button on the left, Mint-Y theming, slick-greeter, the X-Apps, and Mint's
tools. Mint builds it on **Ubuntu**. LMDE (Linux Mint Debian Edition) builds
on Debian, but only ships **Cinnamon**. Ageless Linux is in effect "LMDE with
MATE".

## What Debian trixie already has

| Component | trixie (13) | forky (14, testing) | Notes |
|---|---|---|---|
| `mate-desktop` | 1.26.2 | **1.28.2** | Upstream MATE 1.28 has been out since 2024. Debian stable is a release behind. |
| `mate-panel` | 1.27.1 | 1.27.1 | |
| `caja` / `marco` | 1.26.4 / 1.26.2 | 1.26.4 / 1.26.2 | Forky has not moved to 1.28 for these either. |
| `mate-menu` | 22.04.2 | 22.04.2 | Ubuntu MATE's menu, a fork of mintmenu. We use the real mintmenu instead (below). |
| `mate-tweak` | 22.10.0 | 22.10.0 | Panel layout switcher, which reads `/usr/share/mate-panel/layouts/*.layout`. |
| `slick-greeter` | 2.0.9 | 2.2.7 | Mint's LightDM greeter. |
| `lightdm-settings` | yes | yes | |
| `xapp` / `libxapp1` / `python3-xapp` | 2.8.8 | | Mint's cross-desktop library. |
| `mint-y-icons` | 1.8.3 | 1.9.2 | Includes the `Mint-Y-Sand` accent we use. |
| `mintstick` | 1.6.3 | | USB image writer. |
| `timeshift`, `blueman`, `arc-theme` | yes | | |

## What only Mint's archive has

These are **not** in Debian, but LMDE 7's archive (`packages.linuxmint.com`,
suite `gigi`, based on trixie) carries them, which shows they build on Debian:

- `mint-themes` (the Mint-Y **GTK** theme; Debian only has the icons)
- `mintmenu` (the real Mint menu; depends only on Debian packages such as
  `python3-xapp` and `gir1.2-matepanelapplet-4.0`)
- `mint-l-theme`, `mint-x-icons`
- `mintupdate`, `mintinstall`, `mintsources`, `mintdesktop`
- X-Apps: `xed`, `xviewer`, `xreader`, `pix`; also `warpinator`, `sticky`,
  `webapp-manager`, `hypnotix`
- `live-installer` (LMDE's installer; we use Calamares instead)

Only **`mintdrivers`** is tied to Ubuntu: it hard-depends on
`ubuntu-drivers-common`. `mintupdate` needs Mint-only helpers (`mint-common`,
`mint-mirrors`, `aptkit`), which are Mint-specific but not Ubuntu-specific.

## Rebuilt Mint packages (working now)

`upstream/rebuilds.toml` lists what we rebuild, and `tools/rebuild.py` builds
each entry inside the build container. `build.py` runs it before every
package/ISO build and caches the results in `out/debs/`. These are verified
to build on trixie and to install together on a clean trixie system:

| Package | Source | Notes |
|---|---|---|
| `mint-x-icons` 1.7.9 | tag `1.7.9` | Runtime dependency of mint-themes |
| `mint-themes` 2.4.2 | tag `2.4.2` | Provides **Mint-Y-Dark-Sand** (GTK) and **Mint-Y-Sand** (marco/metacity titlebars) |
| `xapp-symbolic-icons` 1.1.0 | tag `1.1.0` ([xapp-project](https://github.com/xapp-project/xapp-symbolic-icons)) | The `xsi-*` icons mintmenu 6.2.3 uses |

`mintmenu` used to be rebuilt the same way. It is now **forked in-tree** at
`packages/mintmenu` (6.2.3 → `6.2.3+ageless1`); see [mintmenu.md](mintmenu.md).

## What the ISO ships

`ageless-desktop-mate` sets these defaults through a GSettings vendor
override, so users can change all of them:

- panel layout `ageless`: Mint-style bottom panel with **mintmenu**,
  launchers for terminal and files, window list, tray and clock. It is
  selectable in mate-tweak.
- GTK theme `Mint-Y-Dark-Sand`, marco theme `Mint-Y-Sand`, icons
  `Mint-Y-Sand`. That gives a dark theme with a sand/gold accent, matching
  agelesslinux.org.
- LightDM + slick-greeter with the Ageless wallpaper and logo
- Noto fonts

`build.py --no-rebuilds` skips the rebuild step, but the desktop package
depends on mintmenu and mint-themes, so that is only useful for
`--variant packages`.

## Rebuild plan (next)

1. **More Mint**: the X-Apps (`xed`, `xviewer`, `xreader`, `pix`),
   `mintupdate` + `mint-common`, `mintinstall` (the Software Manager, a
   starting point for an "ageless store"), `warpinator`.
2. **MATE 1.28 backports from forky**: `mate-desktop` first, then the rest
   of the stack as forky gets it. Backport with a `~ageless0.1` version
   suffix so a later Debian release supersedes it cleanly.
3. **`slick-greeter` 2.2.x from forky** for the newer greeter.

The ordering matters. Everything in step 1 is new to Debian, so it carries no
risk to the base system. Step 2 replaces Debian packages, so it needs the
`timeless-proposed` staging suite from the roadmap (§9 Q4) before it goes to
users.

## Maker software (also next)

`ageless-maker` is a metapackage. All of these are in trixie main: `arduino`,
`avrdude`, `dfu-util`, `esptool`, `python3-serial`, `picocom`, `minicom`,
`gtkterm`, `thonny`, `kicad` 9.0, `freecad` 1.0, `openscad`, `prusa-slicer`,
`inkscape`, `pulseview`, `sigrok-cli`. It is published to the archive but
kept off the live ISO, because KiCad and FreeCAD alone would push the ISO past
GitHub's 2 GiB release-asset limit.

Not in Debian, so candidates for the rebuild track or Flatpak: `arduino-cli`,
`platformio`, `mu-editor`. "Device integration" (udev rules for common dev
boards and serial adapters, group setup so `dialout` works on first boot)
is the `ageless-device` package (udev `uaccess` rules for RP2040/RP2350
boards, the `ageless-device` CLI); see [ageless-device.md](ageless-device.md).
Other boards' rules (ESP32 serial adapters, STM32 DFU) can join it.
