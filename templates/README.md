# Workflow templates

Drop-in GitHub Actions workflow files for the FlagOS Nexus upload
path, structured per maintainer guidance: the upload logic lives
once in `flagos-ai/build-infra` as a reusable workflow; component
repos carry only a thin caller; secrets are org-level.

## Files

```
templates/
├── build-infra/
│   └── upload-nexus.yml        reusable workflow → PR into flagos-ai/build-infra
├── upload-nexus-caller.yml     thin caller → identical copy into every component repo
└── README.md
```

## Architecture

One workflow, one secret:

```
flagos-ai org secret (one configuration)
  NEXUS_TOKEN ("user:token" for curl -u)
  NEXUS_CA_CERT (optional, internal CA PEM)
        │  secrets: inherit
        ▼
component repo .github/workflows/upload-nexus.yml   ← caller, ~25 lines
  on: push tags v*  +  workflow_dispatch
        │  uses: flagos-ai/build-infra/.github/workflows/upload-nexus.yml@main
        ▼
build-infra upload-nexus.yml                        ← all logic, one copy
  1. install internal CA into trust store (if NEXUS_CA_CERT set)
  2. download build-deb.yml / build-rpm.yml artifacts (caller's repo)
  3. upload (Sonatype per-format commands; URLs hardcoded, not secret)
     deb: POST --data-binary to <apt-repo-url>/   (root, trailing slash)
     rpm: PUT --upload-file to <yum-repo-url>/<filename>
  4. fail-loud: artifacts found but zero uploaded → exit 1
```

The deb and rpm upload commands differ on purpose — Nexus apt hosted
repos ingest packages POSTed to the repository root (the pool/ path
is derived from the deb's control fields), while yum hosted repos
take a PUT at an explicit filename path.

Reusable workflows run in the caller's repository context, so the
artifact download automatically targets the calling repo — the same
caller file works for all 13 component repos with no edits.

## Rollout order

1. **build-infra**: PR `templates/build-infra/upload-nexus.yml` into
   `flagos-ai/build-infra` at `.github/workflows/upload-nexus.yml`.
2. **Org secret**: admin sets `NEXUS_TOKEN` (`user:token`) at org
   level, scoped to the component repos + build-infra. Optionally
   `NEXUS_CA_CERT` if the endpoint moves off a publicly-signed
   certificate (no-op while it stays on `resource.flagos.net:443`).
3. **Pilot**: drop `upload-nexus-caller.yml` into one repo
   (libtriton_jit suggested — replaces its existing standalone
   workflow), dispatch manually, verify packages land in Nexus with
   CI-matching timestamps.
4. **Rollout**: same caller file into the remaining repos.
   - FlagCX: replaces the existing broken workflow (wrong secret
     names, hardcoded URL, self-hosted runner).
   - FlagFFT: defer until its `build-deb.yml` / `build-rpm.yml` land
     upstream — with the fail-loud check, installing the caller
     before builds exist would always fail.

## Validating a pilot run

```sh
gh workflow run upload-nexus.yml --repo flagos-ai/<repo>
gh run watch --repo flagos-ai/<repo>
```

| Outcome | Meaning |
|---------|---------|
| Exit 0, "Uploaded N of N" for deb and rpm | Token and permissions wired correctly |
| `NEXUS_TOKEN secret is empty or unset` | Org secret missing, or the repo is not in the secret's repo list |
| `N file(s) discovered but none uploaded` + curl 401 | Token invalid, or the account lacks write permission on the target hosted repo |
| curl SSL certificate errors | Endpoint uses an internal CA — set `NEXUS_CA_CERT` |
| Exit 0, "Uploaded 0 of 0" | The build workflows produced no artifacts in the 7-day window. Not a Nexus problem |

## Why the fail-loud check exists

The previous standalone workflow on `flagos-ai/libtriton_jit:main`
reported SUCCESS on runs that uploaded nothing (missing URL secrets;
`curl: (3)`; bash `set -e` does not trap a function's `return 1`
used in an `if` condition). The reusable workflow tallies
found-vs-uploaded counts and exits 1 whenever artifacts were found
but none uploaded, and aborts upfront when a URL secret is empty.
