# ADR-001: Where the package build runs

## Context

The FlagOS stack has many components (FlagCX, FlagScale, FlagTree,
FlagGems, libtriton-jit, …) that all need DEB and RPM packages. We
need to decide where the actual `dpkg-buildpackage` / `rpmbuild`
invocations run:

- **A. Build in each upstream repo's CI**, central repo only
  collects/signs/publishes the resulting artifacts
- **B. Build in the central repo's CI**, central repo clones each
  upstream and runs every build itself

This question recurs in design conversations, so capturing the
trade-offs once.

## Decision

**Build in the upstream repos. Central repo (`flagos-packaging`) only
collects, signs, indexes, and publishes.**

Concretely:

```
upstream repo (e.g. FlagOS/FlagCX)
  packaging/                                       ← packaging configs live here
  .github/workflows/build-deb.yml                  ← runs dpkg-buildpackage
  .github/workflows/build-rpm.yml                  ← runs rpmbuild
    │ actions/upload-artifact
    ↓
  GitHub Actions artifact storage (7-day default)
    │ dawidd6/action-download-artifact (cross-repo with GH_TOKEN)
    ↓
flagos-packaging
  scripts/sign-packages.sh
  scripts/build-apt-repo.sh / build-yum-repo.sh
  scripts/publish-release.sh / publish-pages.sh
  .github/workflows/publish.yml                    ← orchestrates the above
```

The central repo never runs `dpkg-buildpackage` or `rpmbuild`. It
never clones upstream source. Its build inputs are *finished
artifacts*, not source code.

## Trade-offs

| Dimension | Build upstream (chosen) | Build central |
|-----------|-------------------------|----------------|
| Build environment | Already in each upstream's Dockerfile | Must replicate per-component Dockerfiles in central |
| Per-component CI feedback | Visible on the upstream PR that introduced the change | Hidden behind a separate central CI run |
| Failure attribution | "FlagCX's build-deb.yml is red" — clear owner | "Central repo failed building FlagCX" — diffuse |
| Runner pressure | Spread across N upstream CIs | Concentrated on central runner (FlagTree alone is 36 min) |
| Workflow duplication | None | One copy per component, plus drift risk |
| Cross-repo dependencies | Central reads artifacts via `GH_TOKEN` | Central writes source via clone/submodule |
| Distro-officialness | Mirrors how Debian/Fedora actually do it (each source pkg owns its packaging) | Diverges from distro convention |

The central-build option has no winning column. The only situation it
makes sense is if upstream repos are private and the central repo is
the only one allowed to publish CI logs — not our case.

## Consequence: artifact transfer

The chosen design needs an artifact channel from upstream CI to
central CI. Options:

| Channel | Retention | Ops cost | Cross-repo auth |
|---------|-----------|----------|------------------|
| **GitHub Actions artifact** (current) | 7 days | 0 | `GH_TOKEN` cross-repo read |
| Upstream repo's GitHub Releases | Forever | upstream creates a release per build | None (public read) |
| Central repo's Releases as staging | Forever | upstream needs PAT to write | Needs PAT |
| External object store (S3 / Nexus / OSS) | Forever | external infra | Vendor secrets |

Current choice: **GitHub Actions artifact** with the central repo
running on a weekly cron + `workflow_dispatch` so the artifact never
expires before the next consumer run. If the 7-day window proves
fragile we switch to upstream Releases (one extra `gh release upload`
step per upstream build) — minimal migration.

There is precedent for this: FlagCX already has an `upload-nexus.yml`
workflow that pulls artifacts from `build-deb.yml` and pushes to a
Nexus repo. Same shape as our `publish.yml`, different storage backend.

## Trigger model

The central `publish.yml` runs:

1. **`schedule`** — `0 18 * * 0` (Sunday 18:00 UTC), guarantees the
   7-day-artifact window doesn't lapse
2. **`workflow_dispatch`** — manual, with optional `release_tag`
   override
3. (future) **`repository_dispatch`** — when an upstream merges a
   packaging PR, it can `gh api repos/.../dispatches` to wake the
   central repo immediately, removing the up-to-7-day publishing
   latency

Initial deployment uses 1 + 2; 3 is opt-in per upstream as needed.

## Why this matters

Future "should we move build into central?" conversations should
default-no unless one of these flips:

- Upstream repos go private and central is the only public publisher
- We bring on a component whose upstream lacks any CI infrastructure
- Build environments need a shared cache (LLVM tarballs, NVIDIA
  toolkits) larger than what GitHub Actions artifacts can carry
- A specific compliance requirement forces single-pipeline build
  audit

Until then: **build in upstream, publish in central.**
