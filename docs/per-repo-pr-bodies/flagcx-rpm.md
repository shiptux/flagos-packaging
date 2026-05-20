## Summary

Adds Debian (`.deb`) and RPM packaging configuration under
`packaging/debian/` and `packaging/rpm/` so this component can be
distributed alongside the rest of the FlagOS stack via standard
`apt install` / `dnf install` flows.

Produced binary: **libflagcx-{nvidia,metax,ascend} + -devel** (≈n/a .deb, ≈≈600 KB each .rpm).

## What changed

- `packaging/debian/{control,rules,changelog,copyright,source/format}` — Debian source-format-3.0-native packaging.
- `packaging/rpm/specs/libflagcx-{nvidia,metax,ascend} + -devel\.spec` — RPM spec using `pyproject-rpm-macros`.
- `packaging/{debian,rpm}/helpers/` — single-command containerized build:
  `bash packaging/debian/build-helpers/build-<slug>.sh` produces the
  .deb without host build-deps; same shape for RPM.

No source code changes outside `packaging/`.

## How it was tested

Local container build produces the noarch .deb and .rpm above.
End-to-end install in clean `ubuntu:24.04` and `debian:trixie`
containers from a local signed APT repo passes `apt install` +
`importlib.util.find_spec(<module>)` smoke check.

The `dh_auto_test` override uses `importlib.util.find_spec`
rather than `import`, so the build-time smoke test validates
install layout (right path, importable from the dist-packages dir)
without triggering runtime imports of torch / triton / etc. — those
are user-install-time concerns, not packaging concerns.

Note: this PR is the RPM-only sibling of #393 (Ascend DEB) and
supersedes the stale rebase target #394 still has.

## Distribution

This artifact is consumed by a central FlagOS publish repo
(sandbox at https://github.com/shiptux/flagos-packaging; the
production endpoint remains the FlagOS Nexus mirror at
`resource.flagos.net`). Companion design notes in the sandbox
repo cover multi-distro strategy
(`docs/multi-distro-strategy-notes.md`) and a per-distro
compatibility matrix (`docs/compatibility-status.md`).

## Known limitations

- Pair to existing PR #394; this is the freshly rebased branch
  off current main (the original `pr/rpm-packaging` was 78
  commits / 304 files behind main and unreviewable).
- Three backends × {runtime, -devel} = 6 RPMs per release.
- Builds in backend-specific docker images (one per vendor SDK)
  identically to the DEB build flow on PR #393.

## Out of scope (separate plans)

- Multi-Python-ABI build matrix (cp312 / cp313 / cp314) — captured
  as a known issue, not blocking this PR.
- C++ extension split (relevant for FlagGems / FlagTree only) —
  Phase 2 work, separate PR if/when needed.
