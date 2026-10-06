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
| `mate-menu` | 22.04.2 | 22.04.2 | Ubuntu MATE's menu, a fork of mintmenu. **Our default for now.** |
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

## What the kickoff ISO ships

`ageless-desktop-mate` sets these defaults through a GSettings vendor
override, so users can change all of them:

- panel layout `ageless` (Mint-style bottom panel, `mate-menu`, launchers
  for terminal and files, window list, tray, clock), selectable in mate-tweak
- GTK/window theme `Arc-Dark` and icons `Mint-Y-Sand`. They are stand-ins
  until `mint-themes` is rebuilt: a dark theme with a gold accent, matching
  agelesslinux.org.
- LightDM + slick-greeter with the Ageless wallpaper and logo
- Noto fonts

## Rebuild plan (the next phase)

`upstream/rebuilds.toml` lists what we rebuild into the `timeless` archive,
and `tools/rebuild.py` builds each entry inside the build container:

1. **Mint pieces from their GitHub tags**: `mint-themes`, `mintmenu`, then
   the X-Apps. These are native Debian packages upstream (they ship
   `debian/`), so `dpkg-buildpackage` on a trixie chroot is the whole job.
   When `mintmenu` lands, swap the applet IID in
   `packages/ageless/desktop/ageless.layout` to
   `MintMenuAppletFactory::MintMenuApplet`.
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
belongs in a future `ageless-maker-udev` package.
