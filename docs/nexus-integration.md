# Nexus integration

State of the Nexus side-channel used to mirror build artifacts off
GitHub Actions storage onto an internal Sonatype Nexus instance.

Last refresh: 2026-06-10.

## Why a Nexus channel at all

Two reasons the FlagOS publish pipeline uses Nexus in addition to
GitHub Pages + Releases:

1. **Retention floor.** GitHub Actions artifacts default to 7-day
   retention. Nexus hosted repositories keep packages indefinitely
   (subject to retention policy), so a build that produces useful
   artifacts is not lost if the next central publish run slips by
   more than a week.
2. **Internal access path.** Some downstream consumers live on
   networks that reach `resource.flagos.net` more reliably than they
   reach `*.github.io`. Nexus gives those consumers an APT / YUM
   endpoint with the same package set.

The Nexus channel is a mirror, not the source of truth. The
authoritative publish flow is still `publish.yml` →
`flagos-packaging` Pages + Releases.

## Service endpoint

- Base URL: `https://resource.flagos.net`
- Direct port (bypasses the ELB): `https://resource.flagos.net:2115`
- REST API: `GET /service/rest/v1/repositories` lists all hosted
  repositories (anonymous read works on the listing endpoint);
  `GET /service/rest/v1/search?repository=<name>` lists components.
- Browser UI: `https://resource.flagos.net/#browse/browse`.

## Hosted repository inventory

Two distinct classes of repositories exist on this Nexus instance:

- **FlagOS publish targets** — `flagos-apt-hosted`,
  `flagos-yum-hosted`, `flagos-pypi-hosted`. These are the targets
  for FlagOS-built `.deb` / `.rpm` / wheel artifacts.
- **Vendor SDK mirrors** — every other `flagos-<format>-<vendor>`
  repo. These hold vendor-shipped SDK packages (CUDA, MetaX maca,
  Iluvatar Corex, Ascend CANN, etc.). FlagOS does not publish into
  them; consumers add them as an upstream APT / PyPI source.

### APT (`format: apt`)

| Name | Type | Use |
|------|------|-----|
| `flagos-apt-hosted`   | hosted | **Publish target.** All FlagOS-built `.deb` go here |
| `flagos-apt-nvidia`   | hosted | Vendor SDK mirror placeholder (empty as of 2026-06-10) |
| `flagos-apt-mthreads` | hosted | Vendor SDK mirror placeholder (empty as of 2026-06-10) |

### YUM (`format: yum`)

| Name | Type | Use |
|------|------|-----|
| `flagos-yum-hosted` | hosted | **Publish target.** All FlagOS-built `.rpm` go here |

### PyPI (`format: pypi`)

| Name | Type | Use |
|------|------|-----|
| `pypi-internal`           | hosted | Generic internal Python packages |
| `pypi-proxy`              | proxy  | Proxies `mirrors.aliyun.com/pypi` |
| `flagos-pypi-hosted`      | hosted | **Publish target.** FlagOS wheels |
| `flagos-pypi-nvidia`      | hosted | Vendor SDK mirror (NVIDIA-side wheels) |
| `flagos-pypi-ascend`      | hosted | Vendor SDK mirror (Huawei Ascend / CANN wheels) |
| `flagos-pypi-metax`       | hosted | Vendor SDK mirror (MetaX maca wheels) |
| `flagos-pypi-mthreads`    | hosted | Vendor SDK mirror (Moore Threads wheels) |
| `flagos-pypi-iluvatar`    | hosted | Vendor SDK mirror (Iluvatar Corex; e.g. `accelerate 1.7.0+corex.4.4.0`, `deepspeed 0.16.4+corex.4.4.0`, `apex 0.1+corex.4.4.0` — 50 entries observed) |
| `flagos-pypi-hygon`       | hosted | Vendor SDK mirror (Hygon DCU wheels) |
| `flagos-pypi-kunlunxin`   | hosted | Vendor SDK mirror (Baidu Kunlun wheels) |
| `flagos-pypi-tsingmicro`  | hosted | Vendor SDK mirror (Tsingmicro wheels) |
| `flagos-pypi-enflame`     | hosted | Vendor SDK mirror (Enflame wheels) |

### Docker (`format: docker`)

| Name | Type |
|------|------|
| `flagos-docker-hosted` | hosted |
| `fortest`              | hosted |

### Raw (`format: raw`)

| Name | Type | Use |
|------|------|-----|
| `flagos-filestore` | hosted | Shared blob storage |

### Other formats present

Maven 2 (`maven-releases`, `maven-snapshots`, `maven-central` proxy,
`maven-public` group), NuGet (`nuget-hosted`, `nuget.org-proxy`,
`nuget-group`), Hugging Face proxy (`huggingface-proxy` → `hf-mirror.com`).
These are not part of the FlagOS packaging path.

## Current contents of publish-target repos (2026-06-10)

| Repo | Component | Version | Uploaded | Notes |
|------|-----------|---------|----------|-------|
| `flagos-apt-hosted` | `libtriton-jit`     | 0.1.0-1 | 2026-02-27 15:15, uploader `flagos`, IP 123.118.7.120 | Manual PUT (uploader IP is a Beijing China-Telecom address, not a GitHub-hosted runner) |
| `flagos-apt-hosted` | `libtriton-jit-dev` | 0.1.0-1 | 2026-02-27 15:16, uploader `flagos`, IP 123.118.7.120 | Manual PUT (same uploader, 60s later) |
| `flagos-yum-hosted` | `tree`              | 1.6.0-10.el7 | manual test artifact (not FlagOS) | Smoke-test upload |

No CI-driven artifact has reached either publish-target repo. See
"Upload workflow inventory" below.

## Upload workflow inventory

The upload runs as an `upload-nexus.yml` workflow inside each upstream
repo. It downloads artifacts from that repo's `build-deb.yml` /
`build-rpm.yml` runs and pushes them to Nexus via HTTP PUT.

State across the 13 upstream repos (template files live under
`templates/per-repo/` for the 11 that lack a workflow today):

| Repo | Workflow present | Branch | Secret naming | URL handling |
|------|------------------|--------|---------------|--------------|
| FlagCX        | yes | main                  | `REGISTRY_USERNAME` / `CONTAINER_REGISTRY` | URL hardcoded `https://resource.flagos.net/repository/flagos-apt-hosted`; `runs-on: h20` (self-hosted) |
| libtriton_jit | yes | main + pr/packaging   | `NEXUS_USERNAME` / `NEXUS_PASSWORD`        | URL via `NEXUS_APT_URL` / `NEXUS_YUM_URL` secrets |
| FlagAttention, FlagAudio, FlagBLAS, FlagDNN, FlagFFT, FlagGems, FlagQuantum, FlagScale, FlagSparse, FlagTensor, FlagTree | no | — | — | — |

Both existing workflows use the same trigger pattern:
`push: tags v*` + `workflow_dispatch`. They do not run on PR pushes —
only tagged releases reach Nexus.

### CI run history

Neither workflow has ever uploaded an artifact end-to-end:

**libtriton_jit** (4 runs total):

| Date | Trigger | Branch / tag | Conclusion |
|------|---------|--------------|------------|
| 2026-05-27 | push | v0.2.0-rc0.1 | success (silent no-op — see below) |
| 2026-05-26 | push | v0.2.0-rc0.1 | success (silent no-op) |
| 2026-03-23 | push | v0.1.0-cuda  | failure |
| 2026-02-24 | dispatch | master    | success (but Nexus contents stamped 2026-02-27 — predates CI by 3 days, almost certainly manual) |

The two May-27 / May-26 "successes" actually failed: run log
26499200640 shows `curl: (3) URL using bad/illegal format or missing
URL` repeated for every artifact attempt, and `Uploaded 0 deb
package(s)` / `Uploaded 0 rpm package(s)`. The workflow exited 0
because `upload_deb` is a bash function whose `return 1` inside an
`if` condition does not trigger `set -e`. The curl error 3 means
`${NEXUS_APT_URL}` and `${NEXUS_YUM_URL}` expand to empty strings —
**confirmed missing secrets**.

**FlagCX** (7 runs total, every one failed — log-verified failure
step and cause per run):

| Date | Tag | Failed step | Cause |
|------|-----|-------------|-------|
| 2026-06-01 | v0.13.0-rc2.post1 | Set up job | runner cannot download the action tarball from `codeload.github.com` — 100 s HttpClient timeout × 3 retries |
| 2026-05-31 | v0.13.0-rc2.post1 | Download build artifacts | "no downloadable artifacts found (expired)" |
| 2026-05-25 | v0.13.0-rc0.1     | Set up job | same codeload timeout |
| 2026-05-13 | v0.12.0           | Set up job | same codeload timeout |
| 2026-03-26 | v0.11.0           | Download build artifacts | "no downloadable artifacts found (expired)" |
| 2026-03-09 | v0.10.0           | Set up job | same codeload timeout (`api.github.com` tarball) |
| 2026-02-03 | v0.9.0            | Set up job | same codeload timeout (`api.github.com` tarball) |

Three failure layers, in the order they bite:

1. **Self-hosted runner cannot reach GitHub reliably** (5 of 7 runs).
   The workflow runs on the `h20` self-hosted runner, which sits on a
   network where downloads from `codeload.github.com` /
   `api.github.com` time out. The job dies in *Set up job* while
   fetching the `dawidd6/action-download-artifact` action itself,
   before any step executes.
2. **Artifact expiry** (the other 2 runs). When the runner did get
   through setup, `build-deb.yml` had no successful run with live
   artifacts inside the 7-day retention window. FlagCX's
   `build-deb.yml` last succeeded 2026-03-03 (a dependabot PR);
   main-branch builds have not produced artifacts since.
3. **Latent, never yet reached: secret and URL wiring.** The upload
   step references `REGISTRY_USERNAME` / `CONTAINER_REGISTRY`
   (container-registry credentials, not Nexus ones) and hardcodes the
   APT URL. Whether those secrets hold valid Nexus credentials is
   unverified because no run has ever reached this step. Fixing
   layers 1–2 alone would likely expose this as the next failure.

The layer-1 finding is also the strongest argument against running
Nexus uploads on internal self-hosted runners in general: the same
unstable-GitHub-access problem that motivated building packages on
GitHub-hosted runners applies equally to the upload path.

## Decision (2026-06-10/11, maintainer feedback)

Maintainers chose a refined per-repo shape — "one workflow, one
secret" — that removes Option A's main drawbacks:

1. **One org-level secret** — `NEXUS_TOKEN`, a `user:token` pair
   passed straight to `curl -u`. Configured once on the `flagos-ai`
   org, shared to the component repos. Repository URLs are not
   secret and are hardcoded in the workflow.
2. **Reusable workflow in `flagos-ai/build-infra`** — the upload
   logic lives once at
   `build-infra/.github/workflows/upload-nexus.yml`; component repos
   carry only a ~25-line caller referencing it with
   `secrets: inherit`. A template revision is one PR to build-infra,
   not 13.
3. **Upload commands follow the Sonatype per-format convention**
   (maintainer-supplied reference command):
   - apt hosted: `curl -u $NEXUS_TOKEN -H 'Content-Type:
     multipart/form-data' --data-binary "@pkg.deb" <apt-url>/` —
     POST to the repository ROOT; Nexus derives the `pool/` path
     from the deb control fields. (The earlier standalone workflows'
     PUT-to-filename approach is not the apt-format method.)
   - yum hosted: `curl -u $NEXUS_TOKEN --upload-file pkg.rpm
     <yum-url>/<filename>` — PUT at an explicit path.
4. **An optional SSL step** — `NEXUS_CA_CERT` installs an internal
   CA into the runner trust store when set; a no-op while the
   endpoint stays on the publicly-signed `resource.flagos.net:443`.

Templates: `templates/build-infra/upload-nexus.yml` (reusable) and
`templates/upload-nexus-caller.yml` (identical caller for every
component repo). See `templates/README.md` for the rollout order.

The original option analysis is kept below for the record.

## Option analysis (resolved — kept for the record)

### Option A — each upstream repo runs its own upload-nexus.yml

Thirteen standard workflow files (already generated under
`templates/per-repo/`), each triggered by that repo's tag pushes.

Drawbacks:

1. **Credential spread.** The Nexus secrets must be visible to
   Actions in all 13 repos (either 13 repo-level copies or one
   org-level secret shared to all of them). Anyone who can modify a
   workflow in any of those repos can read the credential; a leak
   investigation has to cover 13 repos.
2. **Configuration and rotation cost.** Secret changes touch 13
   places (org-level scoping reduces this to one, but requires an
   org admin).
3. **Maintenance cost.** Every template revision means 13 PRs. The
   silent-failure bug found this week is a live example: the two
   existing on-repo copies each broke in their own way and stayed
   broken for three months.
4. Consumes review bandwidth in every upstream repo for a CI file
   unrelated to that repo's code.

Benefit: uploads happen at tag time (no latency), and a failure is
visible in the repo that owns the artifact.

### Option B — flagos-packaging pushes centrally (recommended)

Add one Nexus-upload workflow to this repo. It reuses the existing
collect matrix (`components/*.yml`) and the same cross-repo
`dawidd6/action-download-artifact` path that `publish.yml` already
uses — downloading artifacts from public repos needs only
`GITHUB_TOKEN`, so upstream repos need zero configuration.

Benefits:

1. Nexus credentials exist in exactly one repo; rotation, audit and
   revocation are single-point.
2. No changes and no secrets needed in any upstream repo.
3. One copy of the upload logic; a fix lands once.
4. Matches the established architecture (ADR-001: build upstream,
   publish central) — Nexus becomes a second storage backend next to
   Pages/Releases, not a new pipeline.

Drawbacks:

1. Not tag-immediate: the central repo runs on a weekly cron +
   manual dispatch. Mitigable later with `repository_dispatch`
   pings from upstream (already anticipated in ADR-001).
2. Bound by the 7-day artifact retention window — same constraint
   `publish.yml` already manages with its weekly cron.

The FlagCX run history above is also evidence for B: five of seven
failures were the internal self-hosted runner failing to reach
GitHub at all. The upload step itself needs nothing internal — just
outbound HTTPS to `resource.flagos.net` — so it runs strictly more
reliably from GitHub-hosted runners.

## Workflow convention (applies to either option)

Use the libtriton_jit shape as the template
(source at `templates/upload-nexus.yml.in`, generated per-repo
files at `templates/per-repo/<Repo>-upload-nexus.yml`):

- Trigger: `push: tags v*` + `workflow_dispatch` (with an optional
  `run_id` input to upload an older successful build run).
- Runner: `ubuntu-latest` — no self-hosted dependency.
- Secrets, all four set at the repo or org level:
  - `NEXUS_USERNAME`
  - `NEXUS_PASSWORD`
  - `NEXUS_APT_URL`  — e.g. `https://resource.flagos.net/repository/flagos-apt-hosted`
  - `NEXUS_YUM_URL`  — e.g. `https://resource.flagos.net/repository/flagos-yum-hosted`
- Artifact download: `dawidd6/action-download-artifact@v12` (or
  newer), pulling from `build-deb.yml` and `build-rpm.yml` in the
  same repo. No `name:` filter — accept whatever the build emits.
- Upload: `curl -f -u "${NEXUS_USERNAME}:${NEXUS_PASSWORD}"
  --upload-file "$pkg" "${NEXUS_*_URL}/${filename}"`.
- **Fail-loud invariant** (already implemented in the template, to
  prevent the silent-success bug above): each upload step aborts if
  its URL secret is empty, and a final check exits non-zero whenever
  artifacts were discovered but zero were uploaded.

FlagCX's on-repo workflow needs to be replaced with the standard
template, not patched in place — the secret names, URL handling, and
runner choice all need to change. (Moot if Option B is chosen; the
on-repo workflows are then retired instead.)

## Verification status

| Item | Status | Evidence |
|------|--------|----------|
| `flagos-apt-hosted` accepts PUT from a valid account | confirmed | Two `libtriton-jit*` deb files exist, uploaded 2026-02-27 by account `flagos` |
| `NEXUS_USERNAME` / `NEXUS_PASSWORD` configured in libtriton_jit repo | likely yes | If they were missing, curl would have exited with `(67) Login denied` rather than `(3) URL missing`. The Username/Password expand to non-empty strings |
| `NEXUS_APT_URL` / `NEXUS_YUM_URL` configured | confirmed missing | `curl: (3) URL using bad/illegal format or missing URL` in libtriton_jit run 26499200640 |
| A scoped Nexus deployment account exists | unverified | The visible uploader is `flagos`, which looks like a generic admin account. A CI-only account with write-only role on the three publish targets has not been confirmed |
| Org-level vs repo-level secret scope decided | org-level | maintainer feedback 2026-06-10 |

### Pre-pilot harness test (2026-06-11, shiptux forks)

The reusable workflow was exercised end-to-end on `shiptux/`
forks (caller in `shiptux/libtriton_jit`, callee at
`shiptux/build-infra@ci/upload-nexus`) before any org secret exists.
Everything except the final authenticated write is verified:

| Check | Result |
|-------|--------|
| Cross-repo `workflow_call` + `secrets: inherit` resolve | pass |
| Artifact download targets the caller's repo (2 deb + 6 rpm found) | pass |
| `src.rpm` excluded from upload set (5 of 6 rpms attempted) | pass |
| Empty-token run | red in seconds with `NEXUS_TOKEN secret is empty or unset` |
| Wrong-token run | `curl: (22) … 401` on both URLs; tally `deb 0/2, rpm 0/5`; fail-loud step exits 1 |
| TLS to `resource.flagos.net` from GitHub-hosted runner | clean (no CA configuration needed) |
| **401 (not 404) from both repo URLs** | endpoint paths are correct; requests reach the auth layer |

Found and fixed during testing: `dawidd6/action-download-artifact`
pinned to a Node 20 release; bumped to v16. Note the v16 release
still warns about Node 20 — if it breaks when GitHub forces Node 24
(June 16, 2026), the fallback is replacing the action with
`gh run download` (the gh CLI is preinstalled on runners).

Known behavior: a *partial* upload (some files 401, at least one OK)
leaves the job green — the fail-loud check only fires when zero
files upload. Tighten to any-failure-reds if partial uploads turn
out to matter.

## Rollout plan

Per the decision above (reusable workflow + org secrets):

1. ~~PR the reusable workflow into build-infra~~ — **opened
   2026-06-11**: [build-infra#47](https://github.com/flagos-ai/build-infra/pull/47).
2. **Issue the CI token on Nexus.** A user-token (or a CI-only
   account's `user:token`) with write permission on
   `flagos-apt-hosted` / `flagos-yum-hosted` /
   `flagos-pypi-hosted`. Prefer a scoped CI identity over reusing
   an admin account. *(admin action, pending)*
3. **Configure the org-level secret** `NEXUS_TOKEN` (optionally
   `NEXUS_CA_CERT`), scoped to the component repos + build-infra.
   *(admin action, pending)*
4. ~~Pilot PR on libtriton_jit~~ — **opened as draft 2026-06-11**:
   [libtriton_jit#28](https://github.com/flagos-ai/libtriton_jit/pull/28)
   (replaces the standalone workflow with the thin caller; un-draft
   once #47 merges and the secret exists, then dispatch manually as
   the end-to-end pilot).
5. **Roll the caller into the remaining repos** (identical file, one
   PR each). FlagCX's existing broken workflow is replaced in the
   same move. FlagFFT waits until its build workflows land upstream.

## Relationship to `publish.yml`

`publish.yml` and `upload-nexus.yml` are independent. `publish.yml`
runs in this repo on a weekly cron + manual dispatch, pulls artifacts
from upstream Actions storage into GitHub Releases, and writes APT /
YUM metadata to `gh-pages`. `upload-nexus.yml` runs in each upstream
repo, only on tag pushes or manual dispatch, and writes to Nexus.

Both consume the same upstream `build-deb.yml` / `build-rpm.yml`
artifacts; neither depends on the other. If Nexus is unavailable,
GitHub Pages publishing continues. If GitHub Pages publishing fails,
Nexus mirrors are unaffected.
