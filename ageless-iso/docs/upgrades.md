# In-place upgrades

An installed Ageless Linux system is Debian plus a few packages of ours:

| Source package | Binary packages |
|---|---|
| `ageless` | `ageless-os-release`, the stance packages, `ageless-agelessd`, `ageless-desktop-mate`, `ageless-system-info`, the `ageless-flagrant-*` time capsules, `ageless-maker` |
| `mintmenu` | our mintmenu fork ([mintmenu.md](mintmenu.md)) |
| `calamares-settings-ageless` | installer branding (live medium only; removed after install) |
| `ageless-device` | Ageless Device support |
| `ageless-keyring` | archive key + apt source (once the key exists) |
| Mint rebuilds | `mint-themes`, `mint-x-icons` (from `upstream/rebuilds.toml`) |

Debian's packages update from Debian's mirrors as usual. Ours update from
the Ageless archive. Either way it is `sudo apt update && sudo apt
full-upgrade`; you never need to reimage to get new desktop work.

## Versions

- **Releases** use the version in `debian/changelog`, e.g. `0.1.1`. Build
  them with `./build.py --release` (CI does this for `v*` tags).
- **Development builds** (the default) append
  `+git<YYYYMMDD>.<HHMMSS>.<commit>`:
  `0.1.1 < 0.1.1+git20261006.170943.5d9b692 < 0.1.1+git20261007.… < 0.1.2`.
  A clean checkout uses the commit time, so rebuilding a commit gives
  identical versions. A checkout with uncommitted changes uses the current
  time, so every local rebuild is an upgrade.

Bump the changelog (`0.1.1` → `0.1.2`) when you tag a release.

## The development loop (no signing key needed)

For iterating on the desktop from a build machine to a test laptop on the
same network.

On the **build machine**:

```bash
./build.py --variant packages            # out/debs/*.deb + Packages, out/repo/
python3 tools/make-repo.py serve         # http://<this machine>:8642/
```

On the **Ageless laptop**, once:

```bash
echo 'deb [trusted=yes] http://BUILDHOST:8642/ ./' | sudo tee /etc/apt/sources.list.d/ageless-dev.list
```

Then after each build:

```bash
sudo apt update && sudo apt full-upgrade
ageless-desktop-reset          # only if the panel layout or menu changed
```

`[trusted=yes]` turns off signature checks for that source. Use it on your
own network only, and delete `ageless-dev.list` when you're done.

`ageless-desktop-reset` exists because MATE copies the default panel layout
into each user's dconf on first login. An upgraded `ageless.layout` changes
the default, not your panel. `--all` also resets theme, fonts, wallpaper and
mintmenu settings.

### What an upgrade does (tested)

The upgrade path is tested in a clean trixie container:

1. Install the 0.1.0 packages from the first ISO, including Mint's
   `mintmenu 6.2.3`.
2. Sign the archive built from this tree with a throwaway key.
3. Run `apt full-upgrade`.

Every Ageless package moves to the development version. Mint's mintmenu is
replaced by the fork, and the new `ageless-system-info` comes in as a new
dependency. The 0.1.0 conffiles under `/etc/ageless/` are cleaned up by
`rm_conffile`, and switching stance with `ageless-flagrant on|off
age-signal` flips `/etc/os-release` both ways.

## The signed archive

`tools/make-repo.py build out/debs out/repo` writes a standard Debian
archive (`dists/timeless/main/binary-{amd64,arm64}/` + `pool/`).
`./build.py --variant packages` runs it for you. Installed systems use it
through `ageless-keyring`, which ships:

```
/usr/share/keyrings/ageless-archive-keyring.gpg
/etc/apt/sources.list.d/ageless.sources      (URIs: $AGELESS_ARCHIVE_URL, Suites: timeless)
```

`ageless-standard` and `ageless-flagrant` *recommend* `ageless-keyring`. So
the keyring lands on new installs as soon as it exists, and on existing
systems with their next `apt full-upgrade` from the dev repo above.

### One-time setup (John)

1. **Make the key** on a machine you trust:
   ```bash
   tools/new-archive-key.py
   ```
   This writes the public key to `packages/ageless-keyring/keys/archive.asc`
   and the secret key to a temporary directory it prints.
2. **Store the secret key.**
   - Add the contents of `archive-secret.asc` as the Actions secret
     `AGELESS_ARCHIVE_SIGNING_KEY` (Settings → Secrets and variables →
     Actions).
   - Keep an offline copy, then delete the temporary directory.
3. **Commit** `keys/archive.asc`.
4. **Turn on publishing.**
   - Settings → Pages → Source: **GitHub Actions**.
   - Add the repository variable `AGELESS_APT_PUBLISH=true` (Settings →
     Secrets and variables → Actions → Variables).
   - ⚠ This repository's Pages site becomes the apt archive. If
     agelesslinux.org is ever served from *this* repo's Pages, use a
     separate repo for the archive instead.
5. **Optional:** point `apt.agelesslinux.org` (CNAME) at the Pages site,
   set it as the custom domain, and change `AGELESS_ARCHIVE_URL` in
   `common/release.env`. Installed systems pick up the new URL with the
   next `ageless-keyring` upgrade, because the sources file is a conffile
   the package owns.

After that, every push to `main` publishes a signed development archive at
`AGELESS_ARCHIVE_URL` (default `https://agelesslinux.github.io/agelesslinux`).
Each published archive holds the newest build of each package only.

### Later

- `timeless-proposed`: a staging suite for packages that replace Debian's
  (the MATE 1.28 backports). Planned in the roadmap §9 Q4.
- Release vs. development suites: today, `main` pushes publish development
  versions to `timeless`. Once people other than us run Ageless, publish
  only tagged releases to `timeless` and development builds to
  `timeless-dev`.
