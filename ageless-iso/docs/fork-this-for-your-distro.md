# Fork this for your distro (outline)

> Phase 0 outline. Each step becomes a full section in Phase 5.

Any project that wants "Debian, plus our identity and package choices, as an
installable ISO" can start from `ageless-iso/`. You never touch d-i,
live-build internals, simple-cdd, or xorriso directly.

1. **Copy the tree.** Run `git subtree split -P ageless-iso` (or just copy
   the directory) into your repo.
2. **Name your release** in `common/release.env`: name, version, codename,
   Debian suite, snapshot pin.
3. **Replace the identity package.** In `packages/ageless/`, rename the
   source and binaries. `os-release/os-release.in` is the only file most
   forks need to change. Drop the compliance/refusal/agelessd binaries if your
   reason for forking is something else.
4. **Rebrand Calamares.** In `packages/calamares-settings-ageless/`, rename
   it, then edit `templates/branding.desc.in`, `artwork/*.svg`,
   `calamares/branding/*/show.qml` and the `AGELESS_*` lines in
   `helpers/calamares-sources-final`.
5. **Pick your desktop.** Edit `variant-live/config/package-lists/desktop.list.chroot`
   and `variant-netinst/profiles/ageless.preseed` (`tasksel/first`).
6. **Pick your defaults.** Put a GSettings override, a panel layout and a
   wallpaper in your desktop package (see `packages/ageless/desktop/`).
7. **Build.** Run `./build.py --variant live` and then
   `tests/smoke.py out/*.iso`.
8. **Ship.** Push a `v*` tag. CI builds against the snapshot pin and drafts
   a GitHub Release. Keep each ISO under 2 GiB.

Topics for the full version: replacing the smoke-test markers, adding a
variant (`variant-<name>/build-inner.sh` plus a branch in `build.py`), arm64
caveats, signing.
