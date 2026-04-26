# Release process

`publish.yml` is the only path that produces a published release.

## Triggers

- **Scheduled**: every Sunday 18:00 UTC. Tags as `v<YYYY.MM.DD>`.
- **Manual**: `gh workflow run publish.yml` (optionally with
  `release_tag=<custom>`).

## Required secrets

Set under repository Settings → Secrets and variables → Actions:

- `GPG_PRIVATE_KEY` — armored secret key (output of
  `gpg --armor --export-secret-keys <KEY_ID>`)
- `GPG_PASSPHRASE` — the key's passphrase, if any

The corresponding **public** key is exported by `publish.yml` itself
into `config/gpg-key.pub` and pushed to gh-pages as `pubkey.gpg`.

## Required Pages settings

Repository Settings → Pages → Source: **Deploy from a branch**, branch
**`gh-pages`**, folder **`/`**.

## What the run does

1. **collect** — reads every `components/*.yml`, emits a build matrix.
2. **download** — for each (component, format) pair, downloads the
   latest successful artifact from the upstream's Actions run.
3. **publish** — sign all artifacts, build APT + YUM indexes (with
   Filename / location URLs pointed at the GitHub Release this run
   creates), upload binaries to that Release, push metadata to
   gh-pages.

The whole flow is one workflow with three jobs. Releases and Pages
are atomic at the job level: if either upload fails, the metadata on
gh-pages is older than the release URLs (safe — apt just keeps using
the prior version's metadata until next run).

## Recovering from a partial publish

- If the **Release** uploaded successfully but **Pages** failed, just
  re-run the `Push metadata to gh-pages` step — it's idempotent.
- If the **Release** failed mid-upload, re-run with the same tag.
  `publish-release.sh` uses `gh release upload --clobber` so retries
  overwrite cleanly.
- If you need to roll back, delete the bad release tag — apt/dnf will
  fall back to the previous metadata snapshot once gh-pages is also
  reverted (`git revert` on the gh-pages commit).

## Adding a new upstream component

See `components/README.md`. No publish-side code change needed.
