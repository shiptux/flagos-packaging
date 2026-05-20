## Summary

Adds Debian (`.deb`) and RPM packaging configuration under
`packaging/debian/` and `packaging/rpm/` so this component can be
distributed alongside the rest of the FlagOS stack via standard
`apt install` / `dnf install` flows.

Produced binary: **python3-flagsparse** (≈72 KB .deb, ≈256 KB .rpm).

## What changed

- `packaging/debian/{control,rules,changelog,copyright,source/format}` — Debian source-format-3.0-native packaging.
- `packaging/rpm/specs/flagsparse\.spec` — RPM spec using `pyproject-rpm-macros`.
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

## Distribution

This artifact is consumed by a central FlagOS publish repo
(sandbox at https://github.com/shiptux/flagos-packaging; the
production endpoint remains the FlagOS Nexus mirror at
`resource.flagos.net`). Companion design notes in the sandbox
repo cover multi-distro strategy
(`docs/multi-distro-strategy-notes.md`) and a per-distro
compatibility matrix (`docs/compatibility-status.md`).

## Known limitations

- Pure-Python noarch package. No runtime vendor deps.
- Triton is auto-detected as a Python-level dep via `${python3:Depends}` and pulled at install time on systems that have `python3-triton` (default-archive on Debian trixie / Ubuntu 24.04+; vendor repo elsewhere).

## Out of scope (separate plans)

- Multi-Python-ABI build matrix (cp312 / cp313 / cp314) — captured
  as a known issue, not blocking this PR.
- C++ extension split (relevant for FlagGems / FlagTree only) —
  Phase 2 work, separate PR if/when needed.
