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

Ageless follows the Debian pattern: the version in the changelogs is the
one being worked *toward*, and git tags mark releases.
`tools/release.py` holds the rules; `tools/release.py version` prints what
the current checkout builds.

There are two version numbers:

- **The distro version.** It appears in `os-release` `VERSION`/`PRETTY_NAME`,
  the ISO file name and the installer. It is `AGELESS_VERSION` from
  `common/release.env`, plus the development suffix. `VERSION_ID` is always
  the plain `AGELESS_VERSION`, because the os-release spec doesn't allow `~`.
- **Debian package versions.** These say what each package is compatible
  with. Every Ageless-native package has exactly `AGELESS_VERSION`. Forks
  keep the upstream version plus `+ageless<N>` (mintmenu is
  `6.2.3+ageless1`). Development builds append the same suffix to both.

| Checkout | Builds | Example |
|---|---|---|
| Clean, on tag `v0.1.0` | the release | `0.1.0` |
| Clean, N commits past the last `v*` tag (or N commits in total, before the first tag) | `~N.g<sha>` | `0.1.0~31.gd4fb9c3` |
| Uncommitted changes | `~N.g<sha>.dirty<date>.<time>` | `0.1.0~31.gd4fb9c3.dirty20261008.153012` |

`~` sorts *before* everything, even the end of the string, so:

```
0.1.0~31.gd4fb9c3 < 0.1.0~31.gd4fb9c3.dirty… < 0.1.0~32.g… < 0.1.0 < 0.1.1~1.g… < 0.1.1
```

Each commit, and each dirty rebuild, is an upgrade over the last, and the
tagged release lands after all of its development builds. The mintmenu
fork works the same way: `6.2.3 (Mint) < 6.2.3+ageless1~N.g… < 6.2.3+ageless1`.

### Releasing

```bash
tools/release.py finalize               # changelogs: UNRELEASED -> timeless, dated now
git commit -am "Release 0.1.0"
git tag v0.1.0 && git push origin v0.1.0
tools/release.py next 0.1.1             # release.env + a new UNRELEASED entry in each changelog
git commit -am "Start 0.1.1"
```

- **On a `v*` tag**, CI first runs `tools/release.py check <tag>`, then
  builds with `--release`.
- **The check fails** if any of these hold:
  - the tag doesn't match `AGELESS_VERSION`;
  - any changelog is still `UNRELEASED`;
  - a native package's version isn't `AGELESS_VERSION`;
  - a fork changed since the previous tag without a new `+ageless<N>`.
- **`build.py` refuses a development build of a version that's already
  tagged.** It would sort *below* the release. So after tagging, run
  `next` before building again.
- **`./build.py --release`** insists on a release build: a clean checkout,
  on the tag, with the check passing. Without it, a clean checkout on a
  tag still builds the release.

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

### What's tested

- **Every CI run:** `tests/package-test.sh` installs the desktop packages
  from a signed archive on a clean trixie. It checks that switching stance
  with `ageless-flagrant on|off age-signal` flips `/etc/os-release` both
  ways, and that every time capsule resolves.
- **Upgrades:** given a directory of older `.debs`, the same script
  installs those first and tests `apt full-upgrade`. That check is run by
  hand today, and moves into CI once `v0.1.0` exists to upgrade from.
- **`tests/test_build.py`:**
  - runs the release cycle above in a scratch git repo;
  - checks that a fork changed without a bump fails the release check;
  - checks the version ordering with `dpkg --compare-versions`.

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
