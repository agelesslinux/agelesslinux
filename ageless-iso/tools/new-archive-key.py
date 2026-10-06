#!/usr/bin/env python3
"""Create the Ageless Linux archive signing key. Run once, on a machine you trust.

    tools/new-archive-key.py [--name "Ageless Linux Archive"] [--expire 3y]

Writes, in a fresh temporary GNUPGHOME (your own keyring is not touched):
  packages/ageless-keyring/keys/archive.asc   public key; commit this
  <tmpdir>/archive-secret.asc                 secret key; do NOT commit it

Then:
  1. Store archive-secret.asc as the GitHub Actions secret
     AGELESS_ARCHIVE_SIGNING_KEY (Settings -> Secrets and variables -> Actions).
  2. Keep an offline backup (e.g. on a USB stick in a drawer), then delete
     the temporary directory.
  3. Commit keys/archive.asc. CI then builds ageless-keyring and signs the archive.

The key has no passphrase, because CI has to use it unattended; GitHub's
secret store is what protects it. To rotate, make a new key, add its .asc
next to the old one, release, and remove the old one a release later.
"""

import argparse
import os
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PUBLIC = ROOT / "packages/ageless-keyring/keys/archive.asc"


def main(argv=None) -> int:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--name", default="Ageless Linux Archive Automatic Signing Key")
    p.add_argument("--email", default="archive@agelesslinux.org")
    p.add_argument("--expire", default="3y")
    p.add_argument("--force", action="store_true", help="overwrite an existing keys/archive.asc")
    args = p.parse_args(argv)
    if PUBLIC.exists() and not args.force:
        sys.exit(f"error: {PUBLIC} exists; pass --force to replace it")

    tmp = Path(tempfile.mkdtemp(prefix="ageless-archive-key-"))
    os.chmod(tmp, 0o700)
    env = dict(os.environ, GNUPGHOME=str(tmp))
    uid = f"{args.name} <{args.email}>"
    gpg = ["gpg", "--batch", "--pinentry-mode", "loopback", "--passphrase", ""]
    subprocess.run(gpg + ["--quick-generate-key", uid, "ed25519", "sign", args.expire], env=env, check=True)
    fpr = subprocess.run(["gpg", "--batch", "--with-colons", "--list-secret-keys"], env=env,
                         check=True, capture_output=True, text=True).stdout
    fpr = next(l.split(":")[9] for l in fpr.splitlines() if l.startswith("fpr:"))
    PUBLIC.write_bytes(subprocess.run(["gpg", "--armor", "--export", fpr], env=env,
                                      check=True, capture_output=True).stdout)
    secret = tmp / "archive-secret.asc"
    secret.write_bytes(subprocess.run(gpg + ["--armor", "--export-secret-keys", fpr], env=env,
                                      check=True, capture_output=True).stdout)
    os.chmod(secret, 0o600)
    print(f"""
Fingerprint: {fpr}
Public key:  {PUBLIC}   (commit this)
Secret key:  {secret}   (GitHub secret AGELESS_ARCHIVE_SIGNING_KEY + offline backup, then delete {tmp})
""")
    return 0


if __name__ == "__main__":
    sys.exit(main())
