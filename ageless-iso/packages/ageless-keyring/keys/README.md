# Archive signing keys

`ageless-keyring` is built from every `*.asc` public key in this directory.
Until one exists, `tools/build-packages.sh` skips the package and installed
systems get no Ageless apt source.

Make the key with `tools/new-archive-key.py` (see `docs/upgrades.md`). Only
the **public** key belongs here. The secret key goes in the
`AGELESS_ARCHIVE_SIGNING_KEY` GitHub Actions secret and an offline backup.
