## Summary

Adds a **reusable** `upload-nexus.yml` workflow that any FlagOS
component repo can call to mirror its `build-deb.yml` /
`build-rpm.yml` artifacts onto the Nexus instance at
`resource.flagos.net`.

Design follows the "one workflow, one secret" direction discussed
with maintainers:

- **One workflow**: the upload logic lives here in build-infra;
  component repos carry only a ~25-line caller:

  ```yaml
  jobs:
    upload:
      uses: flagos-ai/build-infra/.github/workflows/upload-nexus.yml@main
      with:
        run_id: ${{ github.event.inputs.run_id }}
      secrets: inherit
  ```

- **One secret**: `NEXUS_TOKEN` (`user:token`, passed to `curl -u`),
  configured once at the org level. Repository URLs are not secret
  and are hardcoded in this workflow's `env:`.

## Upload commands

Per-format Sonatype methods, matching the reference command provided
by maintainers:

- deb → `curl -u $NEXUS_TOKEN -H 'Content-Type: multipart/form-data'
  --data-binary "@pkg.deb" <apt-repo-url>/` (POST to repo root;
  Nexus derives the `pool/` path from the package metadata)
- rpm → `curl -u $NEXUS_TOKEN --upload-file pkg.rpm
  <yum-repo-url>/<filename>` (PUT at an explicit path)

## Why fail-loud

The existing standalone upload workflows reported SUCCESS on runs
that uploaded nothing (libtriton_jit runs on 2026-05-26/27: missing
URL configuration produced `curl: (3)` for every file, yet the job
exited 0). This workflow:

- aborts upfront if `NEXUS_TOKEN` is empty,
- tallies found-vs-uploaded per format and exits non-zero whenever
  artifacts were found but none uploaded.

## Also included

- Optional `NEXUS_CA_CERT` secret: when set, the PEM is installed
  into the runner trust store before upload (no-op while the
  endpoint serves a publicly-signed certificate).
- Runs on `ubuntu-latest`: the upload needs only outbound HTTPS to
  `resource.flagos.net`; GitHub-hosted runners avoid the
  GitHub-access timeouts seen on internal runners.

## Rollout plan (after this merges)

1. Org admin configures the `NEXUS_TOKEN` secret (scoped to the
   component repos + build-infra).
2. Pilot: libtriton_jit replaces its standalone `upload-nexus.yml`
   with the thin caller; manual dispatch verifies packages land in
   Nexus.
3. Same caller file rolls out to the other component repos (FlagCX's
   existing broken workflow gets replaced in the same move).

## Testing

- YAML validated; the upload script logic is shared with the
  standalone template it was derived from.
- End-to-end verification requires the org `NEXUS_TOKEN` secret, so
  it happens in the pilot step above.
