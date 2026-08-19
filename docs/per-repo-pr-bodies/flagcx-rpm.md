### PR Category

CICD

### PR Types

New Features

### PR Description

Adds RPM packaging support for FlagCX targeting RHEL / Rocky / OpenEuler
distributions, mirroring the existing Debian packaging path. Pair to
existing PR #393 (Ascend DEB) — this is the RPM-only sibling, freshly
rebased onto current `main` so the diff is reviewable.

**Background**: original PR #394 has been open since 2026-02-26 with
no review and the branch has drifted 78 commits / 304 files behind
upstream main, making the diff unreadable. This PR is a clean replay
of the same packaging work (3 commits / 5 files) onto current main.
#394 can be closed in favor of this one, or the branch on #394 can be
force-pushed to match this clean state — at the reviewer's preference.

**Produced binaries (built locally per backend):**

For each of `nvidia` / `metax` / `ascend`:

- `libflagcx-<backend>-0.8.0-1.x86_64.rpm` — runtime shared library
- `libflagcx-<backend>-devel-0.8.0-1.x86_64.rpm` — headers + .so symlink

6 binary RPMs per release (3 backends × {runtime, -devel}), one
backend-specific docker image per build.

**What changed (all under `packaging/rpm/`, no DEB or source changes):**

- `rpm/specs/flagcx.spec` — Parameterized spec using `%{backend}`
  macro to generate per-backend package names. Conditional sub-package
  declaration; SONAME + RPATH handling via `patchelf` for
  /usr/lib relocation.
- `rpm/dockerfiles/Dockerfile.rpm` — Unified Dockerfile with
  `BASE_IMAGE` + `BACKEND` build args. Three backends share one
  Dockerfile, picking distinct vendor SDK base images:
  - nvidia: rockylinux:8 + CUDA RPM repo
  - metax: rockylinux:8 + MACA SDK yum repo
  - ascend: openeuler:24.03 + Huawei CANN
- `rpm/build-flagcx-rpm.sh` — Parameterized entry point:
  `./packaging/rpm/build-flagcx-rpm.sh <backend>`.
- `.github/workflows/build-rpm.yml` — CI matrix building all three
  backends on push and PR. Mirrors `build-deb.yml` from #393.

**How it was tested:**

`bash packaging/rpm/build-flagcx-rpm.sh nvidia` produces
`libflagcx-nvidia` + `libflagcx-nvidia-devel` RPMs cleanly in a
rockylinux:8 container. Same flow for metax / ascend with their
respective base images.

Companion DEB packaging (PR #393) and central distribution pipeline
(https://github.com/shiptux/flagos-packaging) are unaffected by this
PR — they were validated separately and continue to work.
